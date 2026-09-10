import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/local/base_datos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<void> esquemaV1(Database db, int version) async {
    final lote = db.batch();
    lote.execute('''
      CREATE TABLE organizaciones (
        id INTEGER PRIMARY KEY, nombre TEXT NOT NULL,
        nit TEXT NOT NULL, activa INTEGER NOT NULL DEFAULT 1)
    ''');
    lote.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        nombre TEXT NOT NULL, correo TEXT NOT NULL UNIQUE,
        rol TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1)
    ''');
    lote.execute('''
      CREATE TABLE zonas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        nombre TEXT NOT NULL, descripcion TEXT NOT NULL DEFAULT '',
        activa INTEGER NOT NULL DEFAULT 1)
    ''');
    lote.execute('''
      CREATE TABLE puntos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        zona_id INTEGER NOT NULL REFERENCES zonas(id),
        nombre TEXT NOT NULL, tipo TEXT NOT NULL,
        instrumentado INTEGER NOT NULL DEFAULT 0,
        latitud REAL, longitud REAL)
    ''');
    lote.execute('''
      CREATE TABLE dispositivos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        punto_id INTEGER NOT NULL REFERENCES puntos(id) ON DELETE CASCADE,
        identificador TEXT NOT NULL, tipo_sensor TEXT NOT NULL,
        ultima_calibracion TEXT NOT NULL)
    ''');
    lote.execute('''
      CREATE TABLE parametros (
        id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, unidad TEXT NOT NULL,
        via_captura TEXT NOT NULL, limite_min REAL, limite_max REAL,
        alerta_min REAL, alerta_max REAL,
        critico INTEGER NOT NULL DEFAULT 0, version_norma TEXT NOT NULL,
        descripcion TEXT NOT NULL DEFAULT '')
    ''');
    lote.execute('''
      CREATE TABLE muestras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        punto_id INTEGER NOT NULL REFERENCES puntos(id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
        fecha_hora TEXT NOT NULL, creado_en TEXT NOT NULL,
        latitud_captura REAL, longitud_captura REAL,
        clasificacion_global TEXT NOT NULL,
        parametro_limitante_id INTEGER REFERENCES parametros(id),
        observaciones TEXT NOT NULL DEFAULT '',
        sincronizada INTEGER NOT NULL DEFAULT 0,
        fecha_sincronizacion TEXT)
    ''');
    lote.execute('''
      CREATE TABLE mediciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        muestra_id INTEGER NOT NULL REFERENCES muestras(id) ON DELETE CASCADE,
        parametro_id INTEGER NOT NULL REFERENCES parametros(id),
        valor REAL NOT NULL, origen TEXT NOT NULL,
        clasificacion TEXT NOT NULL)
    ''');
    lote.execute('''
      CREATE TABLE alertas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        muestra_id INTEGER NOT NULL REFERENCES muestras(id) ON DELETE CASCADE,
        punto_id INTEGER NOT NULL REFERENCES puntos(id),
        tipo TEXT NOT NULL, detalle TEXT NOT NULL, fecha TEXT NOT NULL,
        atendida INTEGER NOT NULL DEFAULT 0)
    ''');
    lote.execute('''
      CREATE TABLE auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL,
        usuario_id INTEGER NOT NULL, usuario_nombre TEXT NOT NULL,
        rol TEXT NOT NULL, accion TEXT NOT NULL, entidad_id INTEGER,
        detalle TEXT NOT NULL DEFAULT '')
    ''');
    lote.execute('''
      CREATE TABLE preferencias (
        clave TEXT PRIMARY KEY, valor TEXT NOT NULL)
    ''');
    lote.execute('CREATE INDEX idx_puntos_zona ON puntos(zona_id)');
    lote.execute('CREATE INDEX idx_muestras_punto ON muestras(punto_id)');
    lote.execute('CREATE INDEX idx_muestras_fecha ON muestras(fecha_hora DESC)');
    lote.execute(
      'CREATE INDEX idx_muestras_pendientes ON muestras(sincronizada)',
    );
    lote.execute(
      'CREATE INDEX idx_mediciones_muestra ON mediciones(muestra_id)',
    );
    lote.execute('CREATE INDEX idx_auditoria_fecha ON auditoria(fecha DESC)');
    await lote.commit(noResult: true);
  }

  Future<List<String>> retrato(Database db) async {
    final filas = await db.rawQuery('''
      SELECT type, name, sql FROM sqlite_master
      WHERE name NOT LIKE 'sqlite_%'
      ORDER BY type, name
    ''');
    String normalizar(String sql) => sql
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*\(\s*'), '(')
        .replaceAll(RegExp(r'\s*\)'), ')')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .trim();

    return [
      for (final f in filas)
        '${f['type']} ${f['name']}: '
            '${normalizar(f['sql'] as String? ?? '')}',
    ];
  }

  Future<Database> abrirV1() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: esquemaV1,
          singleInstance: false,
        ),
      );

  test('migrar desde la v1 produce el mismo esquema que instalar de cero',
      () async {
    final vieja = await abrirV1();
    await BaseDatosLocal.migrar(vieja, 1, BaseDatosLocal.version);

    final nueva = await BaseDatosLocal.abrirEnMemoria();

    final deMigracion = await retrato(vieja);
    final deInstalacion = await retrato(nueva);

    expect(
      deMigracion,
      deInstalacion,
      reason: 'crearEsquema y las migraciones divergieron. Si agrego algo a '
          'uno, agreguelo tambien al otro.',
    );
  });

  test('la migracion conserva los datos existentes', () async {
    final db = await abrirV1();
    await db.insert('organizaciones', {
      'id': 1,
      'nombre': 'Agroindustria',
      'nit': '123',
      'activa': 1,
    });
    await db.insert('zonas', {
      'organizacion_id': 1,
      'nombre': 'Plantacion 1',
      'descripcion': 'bloque norte',
      'activa': 1,
    });

    await BaseDatosLocal.migrar(db, 1, BaseDatosLocal.version);

    final zonas = await db.query('zonas');
    expect(zonas, hasLength(1));
    expect(zonas.first['nombre'], 'Plantacion 1');
    expect(zonas.first['descripcion'], 'bloque norte');
  });

  test('la v2 renombra los duplicados que ya existian', () async {
    final db = await abrirV1();
    await db.insert('organizaciones', {
      'id': 1,
      'nombre': 'Agroindustria',
      'nit': '123',
      'activa': 1,
    });
    await db.insert('zonas', {'organizacion_id': 1, 'nombre': 'Prueba'});
    await db.insert('zonas', {'organizacion_id': 1, 'nombre': 'Prueba'});

    await BaseDatosLocal.migrar(db, 1, BaseDatosLocal.version);

    final nombres = (await db.query('zonas', orderBy: 'id'))
        .map((f) => f['nombre'] as String)
        .toList();

    expect(nombres.first, 'Prueba', reason: 'la mas antigua conserva su nombre');
    expect(nombres.toSet(), hasLength(2), reason: 'ya no hay duplicados');
  });

  test('tras la v2 la base rechaza dos zonas con el mismo nombre', () async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    await db.insert('organizaciones', {
      'id': 1,
      'nombre': 'Agroindustria',
      'nit': '123',
      'activa': 1,
    });
    await db.insert('zonas', {'organizacion_id': 1, 'nombre': 'Plantacion 1'});

    await expectLater(
      db.insert('zonas', {'organizacion_id': 1, 'nombre': 'Plantacion 1'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('una version sin migracion registrada falla de inmediato', () async {
    final db = await abrirV1();
    await expectLater(
      BaseDatosLocal.migrar(db, 1, 99),
      throwsA(isA<StateError>()),
    );
  });
}
