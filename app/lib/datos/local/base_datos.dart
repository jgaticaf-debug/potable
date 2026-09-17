import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../semilla.dart';

class BaseDatosLocal {
  BaseDatosLocal._();

  static const nombreArchivo = 'potable.db';
  // Si cambio el esquema tengo que subir esto Y agregar su bloque en
  // _migraciones. Si no, los telefonos ya instalados se quedan atras.
  static const version = 4;

  static Database? _instancia;

  static bool get soportado =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS);

  static Future<Database> abrir() async {
    if (_instancia != null) return _instancia!;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final ruta = p.join(await getDatabasesPath(), nombreArchivo);

    _instancia = await openDatabase(
      ruta,
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: crearEsquema,
      onUpgrade: migrar,
      onDowngrade: _rechazarRetroceso,
    );
    return _instancia!;
  }

  static Future<Database> abrirEnMemoria() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: crearEsquema,
        singleInstance: false,
      ),
    );
  }

  static Future<void> cerrar() async {
    await _instancia?.close();
    _instancia = null;
  }

  static Future<void> crearEsquema(Database db, [int? version]) async {
    final lote = db.batch();

    lote.execute('''
      CREATE TABLE organizaciones (
        id      INTEGER PRIMARY KEY,
        nombre  TEXT    NOT NULL,
        nit     TEXT    NOT NULL,
        activa  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    lote.execute('''
      CREATE TABLE usuarios (
        id              INTEGER PRIMARY KEY,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        nombre          TEXT    NOT NULL,
        correo          TEXT    NOT NULL UNIQUE,
        rol             TEXT    NOT NULL,
        activo          INTEGER NOT NULL DEFAULT 1
      )
    ''');

    lote.execute('''
      CREATE TABLE zonas (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        nombre          TEXT    NOT NULL,
        descripcion     TEXT    NOT NULL DEFAULT '',
        activa          INTEGER NOT NULL DEFAULT 1
      )
    ''');

    lote.execute('''
      CREATE TABLE puntos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        organizacion_id INTEGER NOT NULL REFERENCES organizaciones(id),
        zona_id         INTEGER NOT NULL REFERENCES zonas(id),
        nombre          TEXT    NOT NULL,
        tipo            TEXT    NOT NULL,
        instrumentado   INTEGER NOT NULL DEFAULT 0,
        latitud         REAL,
        longitud        REAL
      )
    ''');

    lote.execute('''
      CREATE TABLE dispositivos (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        punto_id           INTEGER NOT NULL REFERENCES puntos(id) ON DELETE CASCADE,
        identificador      TEXT    NOT NULL,
        tipo_sensor        TEXT    NOT NULL,
        ultima_calibracion TEXT    NOT NULL
      )
    ''');

    lote.execute('''
      CREATE TABLE parametros (
        id            INTEGER PRIMARY KEY,
        nombre        TEXT    NOT NULL,
        unidad        TEXT    NOT NULL,
        via_captura   TEXT    NOT NULL,
        limite_min    REAL,
        limite_max    REAL,
        alerta_min    REAL,
        alerta_max    REAL,
        critico       INTEGER NOT NULL DEFAULT 0,
        version_norma TEXT    NOT NULL,
        descripcion   TEXT    NOT NULL DEFAULT '',
        nota_indicativa TEXT
      )
    ''');

    lote.execute('''
      CREATE TABLE muestras (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        punto_id               INTEGER NOT NULL REFERENCES puntos(id),
        usuario_id             INTEGER NOT NULL REFERENCES usuarios(id),
        fecha_hora             TEXT    NOT NULL,
        creado_en              TEXT    NOT NULL,
        latitud_captura        REAL,
        longitud_captura       REAL,
        clasificacion_global   TEXT    NOT NULL,
        parametro_limitante_id INTEGER REFERENCES parametros(id),
        observaciones          TEXT    NOT NULL DEFAULT '',
        sincronizada           INTEGER NOT NULL DEFAULT 0,
        fecha_sincronizacion   TEXT,
        id_servidor            INTEGER
      )
    ''');

    lote.execute('''
      CREATE TABLE mediciones (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        muestra_id    INTEGER NOT NULL REFERENCES muestras(id) ON DELETE CASCADE,
        parametro_id  INTEGER NOT NULL REFERENCES parametros(id),
        valor         REAL    NOT NULL,
        origen        TEXT    NOT NULL,
        clasificacion TEXT    NOT NULL
      )
    ''');

    lote.execute('''
      CREATE TABLE alertas (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        muestra_id INTEGER NOT NULL REFERENCES muestras(id) ON DELETE CASCADE,
        punto_id   INTEGER NOT NULL REFERENCES puntos(id),
        tipo       TEXT    NOT NULL,
        detalle    TEXT    NOT NULL,
        fecha       TEXT    NOT NULL,
        atendida    INTEGER NOT NULL DEFAULT 0,
        id_servidor INTEGER
      )
    ''');

    lote.execute('''
      CREATE TABLE auditoria (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha          TEXT    NOT NULL,
        usuario_id     INTEGER NOT NULL,
        usuario_nombre TEXT    NOT NULL,
        rol            TEXT    NOT NULL,
        accion         TEXT    NOT NULL,
        entidad_id     INTEGER,
        detalle        TEXT    NOT NULL DEFAULT ''
      )
    ''');

    lote.execute('''
      CREATE TABLE preferencias (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
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

    lote.execute(
      'CREATE UNIQUE INDEX idx_zonas_nombre ON zonas(organizacion_id, nombre)',
    );
    lote.execute('CREATE INDEX idx_alertas_atendida ON alertas(atendida)');
    lote.execute('CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id)');

    lote.execute(
      'CREATE UNIQUE INDEX idx_muestras_servidor ON muestras(id_servidor) '
      'WHERE id_servidor IS NOT NULL',
    );
    lote.execute(
      'CREATE UNIQUE INDEX idx_alertas_servidor ON alertas(id_servidor) '
      'WHERE id_servidor IS NOT NULL',
    );

    await lote.commit(noResult: true);
  }

  static final Map<int, Future<void> Function(Database)> _migraciones = {
    2: _v2NombresDeZonaUnicos,
    3: _v3IdentidadEnElServidor,
    4: _v4TurbidezIndicativa,
  };

  static Future<void> migrar(Database db, int anterior, int nueva) async {
    for (var v = anterior + 1; v <= nueva; v++) {
      final paso = _migraciones[v];
      if (paso == null) {
        throw StateError(
          'Falta la migracion a la version $v. Agreguela en '
          'BaseDatosLocal._migraciones.',
        );
      }
      await paso(db);
    }
  }

  static Future<void> _rechazarRetroceso(
    Database db,
    int anterior,
    int nueva,
  ) async {
    throw StateError(
      'La base local esta en la version $anterior y esta aplicacion espera '
      'la $nueva. Desinstale y vuelva a instalar para continuar.',
    );
  }

  static Future<void> _v3IdentidadEnElServidor(Database db) async {
    await db.execute('ALTER TABLE muestras ADD COLUMN id_servidor INTEGER');
    await db.execute('ALTER TABLE alertas ADD COLUMN id_servidor INTEGER');

    await db.execute(
      'CREATE UNIQUE INDEX idx_muestras_servidor ON muestras(id_servidor) '
      'WHERE id_servidor IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_alertas_servidor ON alertas(id_servidor) '
      'WHERE id_servidor IS NOT NULL',
    );
  }

  static Future<void> _v4TurbidezIndicativa(Database db) async {
    await db.execute('ALTER TABLE parametros ADD COLUMN nota_indicativa TEXT');

    // Lo pongo de una vez para que el aviso salga aun sin red, que es donde
    // el operario lo necesita.
    final turbidez = Semilla.parametros
        .where((p) => p.notaIndicativa != null)
        .toList();
    for (final p in turbidez) {
      await db.update(
        'parametros',
        {'nota_indicativa': p.notaIndicativa},
        where: 'nombre = ?',
        whereArgs: [p.nombre],
      );
    }
  }

  static Future<void> _v2NombresDeZonaUnicos(Database db) async {
    // Puede haber duplicados de antes: los renombro antes de poner el indice
    // unico, si no la migracion truena.
    await db.execute('''
      UPDATE zonas
      SET nombre = nombre || ' (' || id || ')'
      WHERE id NOT IN (
        SELECT MIN(id) FROM zonas GROUP BY organizacion_id, nombre
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX idx_zonas_nombre ON zonas(organizacion_id, nombre)',
    );
    await db.execute(
      'CREATE INDEX idx_alertas_atendida ON alertas(atendida)',
    );
    await db.execute(
      'CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id)',
    );
  }
}
