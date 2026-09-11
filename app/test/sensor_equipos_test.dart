import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/api/cliente_api.dart';
import 'package:potable/datos/api/mock_api.dart';
import 'package:potable/datos/local/base_datos.dart';
import 'package:potable/datos/repositorio.dart';
import 'package:potable/datos/repositorio_sqlite.dart';
import 'package:potable/datos/sensores/sensor_cliente.dart';
import 'package:potable/dominio/modelos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Sensor de mentira que contesta con el nombre que yo le diga, para poder
// simular el caso del equipo portatil que no coincide con el registrado.
class _SensorDePrueba implements SensorCliente {
  _SensorDePrueba({required this.respondeComo, this.cercanos = const []});

  final String respondeComo;
  final List<EquipoCercano> cercanos;

  String? ultimoPedido;

  @override
  Future<List<EquipoCercano>> buscarCercanos() async => cercanos;

  @override
  Future<LecturaSensor> leer(String identificador) async {
    ultimoPedido = identificador;
    return LecturaSensor.desdeJson(
      jsonEncode({
        'equipo': respondeComo,
        'simulado': true,
        'valores': {
          'ph': 7.1,
          'turbidez': 0.7,
          'conductividad': 350,
          'temperatura': 22.5,
        },
      }),
    );
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<RepositorioSqlite> abrir(SensorCliente sensor) async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    final repo = RepositorioSqlite(
      db,
      cliente: ClienteApi(MockApi()),
      sensor: sensor,
    );
    await repo.sembrarSiEstaVacia();
    await repo.autenticar('admin@aguapura.gt', MockApi.claveDemo);
    return repo;
  }

  Future<int> puntoInstrumentado(RepositorioSqlite repo) async {
    final puntos = await repo.puntos();
    return puntos.firstWhere((p) => p.instrumentado).id;
  }

  Future<String> ultimaLecturaEnBitacora(RepositorioSqlite repo) async {
    final registros = await repo.auditoria();
    return registros
        .firstWhere((r) => r.accion == AccionAuditoria.lecturaSensor)
        .detalle;
  }

  test('la bitacora anota el equipo registrado cuando coincide', () async {
    final repo = await abrir(_SensorDePrueba(respondeComo: 'ESP32-POZO1'));
    final punto = await puntoInstrumentado(repo);

    final valores = await repo.leerSensores(punto);

    expect(valores, hasLength(4));
    final detalle = await ultimaLecturaEnBitacora(repo);
    expect(detalle, contains('ESP32-POZO1'));
    expect(
      detalle,
      isNot(contains('registrado')),
      reason: 'si es el mismo equipo no hace falta aclarar nada',
    );
  });

  test('si contesta otro equipo, la bitacora dice cual fue', () async {
    // El caso real: un solo ESP32 portatil que visita todos los puntos.
    final repo = await abrir(_SensorDePrueba(respondeComo: 'ESP32-PORTATIL'));
    final punto = await puntoInstrumentado(repo);

    await repo.leerSensores(punto);

    final detalle = await ultimaLecturaEnBitacora(repo);
    expect(
      detalle,
      contains('ESP32-PORTATIL'),
      reason: 'tiene que quedar quien tomo la medicion de verdad',
    );
    expect(
      detalle,
      contains('registrado'),
      reason: 'y que no era el que estaba registrado en el punto',
    );
  });

  test('la busqueda de cercanos llega hasta el sensor', () async {
    final repo = await abrir(
      _SensorDePrueba(
        respondeComo: 'ESP32-POZO1',
        cercanos: const [
          EquipoCercano(identificador: 'ESP32-POZO1', intensidad: -48),
          EquipoCercano(identificador: 'ESP32-LEJOS', intensidad: -95),
        ],
      ),
    );

    final equipos = await repo.buscarEquiposCercanos();

    expect(equipos, hasLength(2));
    expect(equipos.first.identificador, 'ESP32-POZO1');
    expect(equipos.first.muyLejos, isFalse);
    expect(
      equipos.last.muyLejos,
      isTrue,
      reason: 'a -95 dBm hay que avisar que se acerque',
    );
  });

  test('un punto sin instrumentar no intenta leer', () async {
    final sensor = _SensorDePrueba(respondeComo: 'ESP32-POZO1');
    final repo = await abrir(sensor);
    final puntos = await repo.puntos();
    final manual = puntos.firstWhere((p) => !p.instrumentado);

    await expectLater(
      repo.leerSensores(manual.id),
      throwsA(isA<ErrorSincronizacion>()),
    );
    expect(
      sensor.ultimoPedido,
      isNull,
      reason: 'ni siquiera debe encender el bluetooth',
    );
  });
}
