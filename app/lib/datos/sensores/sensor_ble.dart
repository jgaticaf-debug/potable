import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sensor_cliente.dart';

class SensorBle implements SensorCliente {
  SensorBle({
    this.esperaDeBusqueda = const Duration(seconds: 12),
    this.esperaDeLectura = const Duration(seconds: 15),
  });

  final Duration esperaDeBusqueda;
  final Duration esperaDeLectura;

  // Los mismos UUID que declara potable_sensor.ino. Si cambian alla, cambian
  // aca: no hay forma de descubrirlos solos.
  static final servicio = Guid('6f2a1000-8b41-4c8e-9d5a-1f7c3e0a9b21');
  static final caracteristicaLectura =
      Guid('6f2a1001-8b41-4c8e-9d5a-1f7c3e0a9b21');
  static final caracteristicaComando =
      Guid('6f2a1002-8b41-4c8e-9d5a-1f7c3e0a9b21');

  @override
  Future<LecturaSensor> leer(String identificador) async {
    await _asegurarRadio();
    await _asegurarPermisos();

    final dispositivo = await _buscar(identificador);

    try {
      await dispositivo.connect(license: License.nonprofit);
      return await _pedirLectura(dispositivo, identificador);
    } on FlutterBluePlusException catch (e) {
      throw SensorNoDisponible(
        'Fallo la comunicacion con $identificador: ${e.description ?? e.code}',
      );
    } on TimeoutException {
      throw SensorNoDisponible(
        'El equipo $identificador se conecto pero no respondio a tiempo. '
        'Revise que este encendido y dentro del agua.',
      );
    } finally {
      // Si no lo suelto, el ESP32 se queda creyendo que la central sigue ahi
      // y no vuelve a anunciarse para la siguiente lectura.
      await dispositivo.disconnect().catchError((_) {});
    }
  }

  Future<void> _asegurarRadio() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const SensorNoDisponible(
        'Este dispositivo no tiene Bluetooth de baja energia. Registre los '
        'valores de forma manual.',
      );
    }

    final estado = await FlutterBluePlus.adapterState.first;
    if (estado != BluetoothAdapterState.on) {
      throw const SensorNoDisponible(
        'El Bluetooth esta apagado. Enciendalo y vuelva a intentar.',
      );
    }
  }

  Future<void> _asegurarPermisos() async {
    // Solo Android. En iOS y macOS el sistema pide el permiso solo al empezar
    // a escanear, usando el texto del Info.plist; y pedir aqui la ubicacion
    // sin declararla alla cierra la app de golpe. En escritorio no existen.
    if (!Platform.isAndroid) return;

    // En Android 12 y arriba son estos dos; abajo, el escaneo BLE se pedia
    // como permiso de ubicacion. Pido los tres y me fijo en el resultado.
    final pedidos = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final concedido = pedidos.entries.any((e) => e.value.isGranted);
    if (concedido) return;

    final bloqueado =
        pedidos.values.any((e) => e.isPermanentlyDenied || e.isRestricted);

    throw SensorNoDisponible(
      bloqueado
          ? 'Los permisos de Bluetooth estan bloqueados. Habilitelos desde los '
              'ajustes del telefono para poder leer el equipo.'
          : 'Sin permiso de Bluetooth no puedo buscar el equipo.',
    );
  }

  Future<BluetoothDevice> _buscar(String identificador) async {
    final encontrado = Completer<BluetoothDevice>();

    final suscripcion = FlutterBluePlus.scanResults.listen((resultados) {
      for (final r in resultados) {
        final nombre = r.advertisementData.advName;
        if (nombre == identificador && !encontrado.isCompleted) {
          encontrado.complete(r.device);
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [servicio],
        timeout: esperaDeBusqueda,
      );
      return await encontrado.future.timeout(esperaDeBusqueda);
    } on TimeoutException {
      throw SensorNoDisponible(
        'No encontre el equipo $identificador. Verifique que este encendido y '
        'a menos de diez metros.',
      );
    } finally {
      await suscripcion.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  Future<LecturaSensor> _pedirLectura(
    BluetoothDevice d,
    String identificador,
  ) async {
    final servicios = await d.discoverServices();

    final nuestros = servicios.where((s) => s.uuid == servicio).toList();
    if (nuestros.isEmpty) {
      throw SensorNoDisponible(
        'El equipo $identificador no expone el servicio de Potable. Puede ser '
        'otro aparato con el mismo nombre.',
      );
    }
    final nuestro = nuestros.first;

    final lecturas = nuestro.characteristics
        .where((c) => c.uuid == caracteristicaLectura)
        .toList();
    final comandos = nuestro.characteristics
        .where((c) => c.uuid == caracteristicaComando)
        .toList();

    if (lecturas.isEmpty || comandos.isEmpty) {
      throw const SensorNoDisponible(
        'El equipo responde pero le falta alguna caracteristica. Puede tener '
        'una version vieja del firmware.',
      );
    }

    final lectura = lecturas.first;
    await lectura.setNotifyValue(true);

    // Me suscribo antes de pedir la lectura. Al reves se pierde la respuesta
    // si el equipo contesta mas rapido de lo que alcanzo a escuchar.
    final respuesta = lectura.onValueReceived
        .where((bytes) => bytes.isNotEmpty)
        .first
        .timeout(esperaDeLectura);

    await comandos.first.write(utf8.encode('leer'));

    final bytes = await respuesta;
    return _interpretar(bytes);
  }

  LecturaSensor _interpretar(List<int> bytes) {
    final texto = utf8.decode(bytes, allowMalformed: true).trim();
    try {
      return LecturaSensor.desdeJson(texto);
    } on FormatException {
      throw SensorNoDisponible(
        'El equipo respondio algo que no entiendo: "$texto".',
      );
    }
  }
}
