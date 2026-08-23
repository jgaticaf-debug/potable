import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/api/cliente_api.dart';
import 'package:potable/datos/api/mock_api.dart';
import 'package:potable/datos/local/base_datos.dart';
import 'package:potable/datos/repositorio_sqlite.dart';
import 'package:potable/dominio/modelos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late RepositorioSqlite repo;

  Future<RepositorioSqlite> abrirEnMemoria() async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    final r = RepositorioSqlite(db, cliente: ClienteApi(MockApi()));
    await r.sembrarSiEstaVacia();
    return r;
  }

  setUp(() async {
    repo = await abrirEnMemoria();
    await repo.autenticar('admin@aguapura.gt', MockApi.claveDemo);
  });

  test('la siembra deja el catalogo completo', () async {
    expect(await repo.parametros(), hasLength(7));
    expect(await repo.zonas(), hasLength(4));
    expect(await repo.puntos(), hasLength(7));
    expect((await repo.muestras()).length, greaterThan(50));
  });

  test('una muestra guardada se recupera con sus mediciones', () async {
    final antes = (await repo.muestras()).length;

    final guardada = await repo.guardarMuestra(
      Muestra(
        id: 0,
        puntoId: 1,
        usuarioId: 3,
        fechaHora: DateTime(2026, 8, 22, 9, 30),
        clasificacionGlobal: Clasificacion.incumplimiento,
        parametroLimitanteId: 3,
        observaciones: 'Prueba de persistencia',
        mediciones: const [
          Medicion(
            parametroId: 1,
            valor: 7.2,
            origen: ViaCaptura.sensor,
            clasificacion: Clasificacion.apto,
          ),
          Medicion(
            parametroId: 3,
            valor: 0.05,
            origen: ViaCaptura.manual,
            clasificacion: Clasificacion.incumplimiento,
          ),
        ],
      ),
    );

    expect(guardada.id, greaterThan(0));
    expect(guardada.sincronizada, isFalse);

    final todas = await repo.muestras();
    expect(todas, hasLength(antes + 1));

    final leida = todas.firstWhere((m) => m.id == guardada.id);
    expect(leida.mediciones, hasLength(2));
    expect(leida.medicionDe(3)!.valor, 0.05);
    expect(leida.observaciones, 'Prueba de persistencia');
    expect(leida.clasificacionGlobal, Clasificacion.incumplimiento);
  });

  test('una muestra fuera de norma genera su alerta', () async {
    final antes = (await repo.alertas()).length;

    await repo.guardarMuestra(
      Muestra(
        id: 0,
        puntoId: 1,
        usuarioId: 3,
        fechaHora: DateTime(2026, 8, 22, 10),
        clasificacionGlobal: Clasificacion.incumplimiento,
        parametroLimitanteId: 6,
        mediciones: const [
          Medicion(
            parametroId: 6,
            valor: 3,
            origen: ViaCaptura.manual,
            clasificacion: Clasificacion.incumplimiento,
          ),
        ],
      ),
    );

    expect((await repo.alertas()).length, antes + 1);
  });

  test('el CRUD de zonas persiste', () async {
    final creada = await repo.guardarZona(
      const Zona(id: 0, organizacionId: 1, nombre: 'Plantacion 9'),
    );
    expect(creada.id, greaterThan(0));
    expect((await repo.zonas()).any((z) => z.nombre == 'Plantacion 9'), isTrue);

    await repo.guardarZona(creada.copyCon(nombre: 'Plantacion 9 renombrada'));
    final renombrada =
        (await repo.zonas()).firstWhere((z) => z.id == creada.id);
    expect(renombrada.nombre, 'Plantacion 9 renombrada');

    await repo.eliminarZona(creada.id);
    expect((await repo.zonas()).any((z) => z.id == creada.id), isFalse);
  });

  test('la bitacora deja traza de quien hizo que', () async {
    await repo.guardarZona(
      const Zona(id: 0, organizacionId: 1, nombre: 'Plantacion auditada'),
    );

    final registros = await repo.auditoria();

    final login = registros.where(
      (r) => r.accion == AccionAuditoria.inicioSesion,
    );
    expect(login, isNotEmpty, reason: 'el inicio de sesion debe quedar');

    final alta = registros.firstWhere(
      (r) => r.accion == AccionAuditoria.altaZona,
    );
    expect(alta.usuarioNombre, 'Marco Chavarria');
    expect(alta.rol, 'Administrador');
    expect(alta.detalle, 'Plantacion auditada');
    expect(alta.entidadId, isNotNull);
  });

  test('la muestra registra la hora de toma y la de captura por separado',
      () async {
    final tomada = DateTime(2026, 8, 20, 6, 15);
    final guardada = await repo.guardarMuestra(
      Muestra(
        id: 0,
        puntoId: 1,
        usuarioId: 3,
        fechaHora: tomada,
        creadoEn: DateTime(2026, 8, 20, 11, 40),
        clasificacionGlobal: Clasificacion.apto,
        mediciones: const [
          Medicion(
            parametroId: 1,
            valor: 7.1,
            origen: ViaCaptura.manual,
            clasificacion: Clasificacion.apto,
          ),
        ],
      ),
    );

    final leida =
        (await repo.muestras()).firstWhere((m) => m.id == guardada.id);
    expect(leida.fechaHora, tomada);
    expect(leida.creadoEn, DateTime(2026, 8, 20, 11, 40));
    expect(leida.creadoEn.isAfter(leida.fechaHora), isTrue);
  });

  test('la sincronizacion marca las pendientes y deja traza', () async {
    await repo.guardarMuestra(
      Muestra(
        id: 0,
        puntoId: 1,
        usuarioId: 3,
        fechaHora: DateTime(2026, 8, 22, 12),
        clasificacionGlobal: Clasificacion.apto,
        mediciones: const [
          Medicion(
            parametroId: 1,
            valor: 7.0,
            origen: ViaCaptura.manual,
            clasificacion: Clasificacion.apto,
          ),
        ],
      ),
    );

    expect(
      (await repo.muestras()).where((m) => !m.sincronizada),
      isNotEmpty,
    );

    // El mock falla el primer intento a proposito.
    await expectLater(repo.sincronizar(), throwsA(isA<Exception>()));

    final enviadas = await repo.sincronizar();
    expect(enviadas, greaterThan(0));
    expect((await repo.muestras()).where((m) => !m.sincronizada), isEmpty);

    final traza = await repo.auditoria();
    expect(
      traza.any((r) => r.accion == AccionAuditoria.sincronizacion),
      isTrue,
    );
  });
}
