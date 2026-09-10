import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/api/cliente_api.dart';
import 'package:potable/datos/api/mock_api.dart';
import 'package:potable/datos/estado_app.dart';
import 'package:potable/datos/local/base_datos.dart';
import 'package:potable/datos/repositorio_sqlite.dart';
import 'package:potable/dominio/modelos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late EstadoApp estado;

  Future<void> arrancar() async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    final repo = RepositorioSqlite(db, cliente: ClienteApi(MockApi()));
    await repo.sembrarSiEstaVacia();

    estado = EstadoApp(repo);
    await estado.iniciarSesion('operario@aguapura.gt', MockApi.claveDemo);
  }

  Future<void> capturar() async {
    await estado.registrarMuestra(
      puntoId: 1,
      valores: {1: 7.2, 3: 0.6},
      origenes: const {},
    );
  }

  setUp(arrancar);

  test('una muestra nueva programa el reintento', () async {
    expect(estado.proximoReintento, isNull);

    await capturar();

    expect(estado.pendientes, hasLength(1));
    expect(
      estado.proximoReintento,
      isNotNull,
      reason: 'con algo en la cola siempre debe haber un reintento en camino',
    );
  });

  test('un envio exitoso cancela el reintento', () async {
    await capturar();

    expect(await estado.sincronizar(), isNull);
    expect(estado.proximoReintento, isNotNull);

    final enviadas = await estado.sincronizar();
    expect(enviadas, 1);
    expect(estado.pendientes, isEmpty);
    expect(
      estado.proximoReintento,
      isNull,
      reason: 'sin cola no hay nada que reintentar',
    );
  });

  test('la espera crece con cada fallo', () async {
    await capturar();

    final esperas = <Duration>[];
    for (var i = 0; i < 3; i++) {
      final antes = DateTime.now();
      await estado.sincronizar();
      if (estado.proximoReintento != null) {
        esperas.add(estado.proximoReintento!.difference(antes));
      }
      if (estado.pendientes.isEmpty) await capturar();
    }

    expect(esperas, isNotEmpty);
    for (final e in esperas) {
      expect(e.inSeconds, greaterThan(0));
      expect(
        e.inMinutes,
        lessThanOrEqualTo(15),
        reason: 'la espera tiene tope, no crece sin limite',
      );
    }
  });

  test('cerrar sesion cancela el reintento pendiente', () async {
    await capturar();
    await estado.sincronizar();
    expect(estado.proximoReintento, isNotNull);

    await estado.cerrarSesion();
    expect(estado.proximoReintento, isNull);
  });

  test('no se lanzan dos sincronizaciones a la vez', () async {
    await capturar();

    final primera = estado.sincronizar();
    final segunda = estado.sincronizar();

    expect(
      await segunda,
      isNull,
      reason: 'la segunda debe descartarse mientras la primera corre',
    );
    await primera;
  });

  test('la muestra sobrevive a los fallos de envio', () async {
    await capturar();
    final id = estado.pendientes.first.id;

    await estado.sincronizar();

    expect(estado.pendientes, hasLength(1));
    expect(estado.pendientes.first.id, id);
    expect(
      estado.muestras.any((m) => m.id == id),
      isTrue,
      reason: 'un envio fallido nunca debe perder el dato local',
    );
  });

  test('sin sesion no se programa nada', () async {
    await capturar();
    await estado.cerrarSesion();

    expect(estado.autenticado, isFalse);
    expect(estado.proximoReintento, isNull);
  });

  test('la clasificacion de la muestra encolada se conserva', () async {
    await estado.registrarMuestra(
      puntoId: 1,
      valores: {3: 0.05},
      origenes: const {},
    );

    final encolada = estado.pendientes.first;
    expect(encolada.clasificacionGlobal, Clasificacion.incumplimiento);
    expect(encolada.sincronizada, isFalse);

    await estado.sincronizar();
    await estado.sincronizar();

    final enviada =
        estado.muestras.firstWhere((m) => m.id == encolada.id);
    expect(enviada.sincronizada, isTrue);
    expect(enviada.clasificacionGlobal, Clasificacion.incumplimiento);
  });
}
