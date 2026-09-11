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
  late RepositorioSqlite repo;

  setUp(() async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    repo = RepositorioSqlite(db, cliente: ClienteApi(MockApi()));
    await repo.sembrarSiEstaVacia();

    estado = EstadoApp(repo);
    await estado.iniciarSesion('calidad@aguapura.gt', MockApi.claveDemo);
    await estado.cargarCatalogo(descargar: false);
  });

  Future<int> registrosDeAtencion() async {
    final bitacora = await repo.auditoria(limite: 500);
    return bitacora
        .where((r) => r.accion == AccionAuditoria.atencionAlerta)
        .length;
  }

  test('atender varias deja un registro por cada una', () async {
    final abiertas = estado.alertas.where((a) => !a.atendida).toList();
    expect(abiertas.length, greaterThan(1), reason: 'la semilla trae alertas');

    final antes = await registrosDeAtencion();
    final hechas = await estado.atenderAlertas([
      for (final a in abiertas) a.id,
    ]);

    expect(hechas, abiertas.length);
    expect(
      await registrosDeAtencion() - antes,
      abiertas.length,
      reason: 'la trazabilidad se pierde si queda un solo registro del lote',
    );
  });

  test('despues de atenderlas el contador queda en cero', () async {
    final ids = [
      for (final a in estado.alertas.where((a) => !a.atendida)) a.id,
    ];

    await estado.atenderAlertas(ids);

    expect(estado.alertasAbiertas, 0);
  });

  test('atender solo las de un tipo deja las demas abiertas', () async {
    final incumplen = estado.alertas
        .where((a) => !a.atendida && a.tipo == Clasificacion.incumplimiento.etiqueta)
        .toList();
    final enRiesgo = estado.alertas
        .where((a) => !a.atendida && a.tipo == Clasificacion.riesgo.etiqueta)
        .toList();

    if (incumplen.isEmpty || enRiesgo.isEmpty) {
      markTestSkipped('la semilla no trae los dos tipos abiertos');
      return;
    }

    await estado.atenderAlertas([for (final a in incumplen) a.id]);

    expect(estado.alertasAbiertas, enRiesgo.length);
  });

  test('una lista vacia no toca nada', () async {
    final antes = estado.alertasAbiertas;

    expect(await estado.atenderAlertas(const []), 0);
    expect(estado.alertasAbiertas, antes);
  });
}
