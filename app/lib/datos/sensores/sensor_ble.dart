import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sensor_cliente.dart';

class SensorBle implements SensorCliente {
  SensorBle({
    this.esperaDeBusqueda = const Duration(seconds: 8),
    this.esperaDeLectura = const Duration(seconds: 15),
    this.reposo = const Duration(milliseconds: 2500),
  });

  // Tope duro del escaneo.
  final Duration esperaDeBusqueda;
  final Duration esperaDeLectura;

  // Un ESP32 se anuncia cada pocas decenas de milisegundos, asi que si en
  // este rato no aparecio nada nuevo, ya no va a aparecer. Corto ahi en vez
  // de esperar el tope: la diferencia se siente al usarlo.
  final Duration reposo;

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

    final hallado = await _buscar(identificador);
    final dispositivo = hallado.dispositivo;

    try {
      await dispositivo.connect(license: License.nonprofit);
      return await _pedirLectura(dispositivo, hallado.nombre);
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

  @override
  Future<List<EquipoCercano>> buscarCercanos() async {
    await _asegurarRadio();
    await _asegurarPermisos();

    final hallados = await _escanear();
    return [
      for (final h in hallados)
        EquipoCercano(identificador: h.nombre, intensidad: h.intensidad),
    ];
  }

  // Filtro por UUID de servicio, no por nombre: asi solo veo equipos de
  // Potable y no toda la cafetera bluetooth del vecindario.
  Future<List<_Hallazgo>> _escanear({String? hasta}) async {
    final porNombre = <String, _Hallazgo>{};
    final atajo = Completer<void>();
    Timer? silencio;

    void cortarSiSeCalma() {
      silencio?.cancel();
      silencio = Timer(reposo, () {
        if (!atajo.isCompleted) atajo.complete();
      });
    }

    final suscripcion = FlutterBluePlus.scanResults.listen((resultados) {
      var apareceAlgoNuevo = false;

      for (final r in resultados) {
        final nombre = r.advertisementData.advName;
        if (nombre.isEmpty) continue;

        apareceAlgoNuevo |= !porNombre.containsKey(nombre);
        porNombre[nombre] = _Hallazgo(nombre, r.rssi, r.device);

        if (nombre == hasta && !atajo.isCompleted) {
          atajo.complete();
          return;
        }
      }

      if (apareceAlgoNuevo) cortarSiSeCalma();
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [servicio],
        timeout: esperaDeBusqueda,
      );

      // Si ya aparecio el que buscaba no espero el resto del tiempo; si no,
      // dejo que el escaneo se agote para juntar todo lo que haya.
      await Future.any([
        atajo.future,
        FlutterBluePlus.isScanning.where((corriendo) => !corriendo).first,
      ]).timeout(esperaDeBusqueda + const Duration(seconds: 3));
    } on TimeoutException {
      // Me quedo con lo que alcance a ver.
    } finally {
      silencio?.cancel();
      await suscripcion.cancel();
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    }

    return porNombre.values.toList()
      ..sort((a, b) => b.intensidad.compareTo(a.intensidad));
  }

  Future<_Hallazgo> _buscar(String identificador) async {
    final hallados = await _escanear(hasta: identificador);

    for (final h in hallados) {
      if (h.nombre == identificador) return h;
    }

    if (hallados.isEmpty) {
      throw SensorNoDisponible(
        'No encontre ningun equipo de Potable cerca. Verifique que el '
        '$identificador este encendido y a menos de diez metros.',
      );
    }

    // El punto tiene registrado un equipo que no esta aqui, pero si hay otro
    // de Potable. Con un solo aparato portatil eso pasa todo el tiempo, asi
    // que lo uso y dejo dicho cual fue. Si hay varios no adivino.
    if (hallados.length == 1) return hallados.first;

    final nombres = hallados.map((h) => h.nombre).join(', ');
    throw SensorNoDisponible(
      'El punto tiene registrado $identificador, que no esta cerca, y hay '
      'varios equipos a la vista: $nombres. Acerquese al que va a usar o '
      'registrelo en el punto.',
    );
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

class _Hallazgo {
  const _Hallazgo(this.nombre, this.intensidad, this.dispositivo);

  final String nombre;
  final int intensidad;
  final BluetoothDevice dispositivo;
}
