import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BaseDatosLocal {
  BaseDatosLocal._();

  static const nombreArchivo = 'potable.db';
  static const version = 1;

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
      onUpgrade: _migrar,
    );
    return _instancia!;
  }

  /// Base efimera en memoria, para pruebas.
  static Future<Database> abrirEnMemoria() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: crearEsquema,
      ),
    );
  }

  static Future<void> cerrar() async {
    await _instancia?.close();
    _instancia = null;
  }

  /// Crea el esquema completo. Publico para que las pruebas usen
  /// exactamente el mismo que produccion.
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
        descripcion   TEXT    NOT NULL DEFAULT ''
      )
    ''');

    // fecha_hora  = cuando se tomo la muestra en el punto
    // creado_en   = cuando quedo registrada en el dispositivo
    // Las dos rara vez coinciden y la auditoria necesita ambas.
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
        fecha_sincronizacion   TEXT
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
        fecha      TEXT    NOT NULL,
        atendida   INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Bitacora inmutable: solo admite INSERT.
    // El nombre y el rol se copian al momento del hecho para que el registro
    // siga siendo legible aunque el usuario cambie de rol o sea dado de baja.
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

    await lote.commit(noResult: true);
  }

  static Future<void> _migrar(Database db, int anterior, int nueva) async {
    // Sin migraciones todavia: la version 1 es la primera publicada.
    // Cada cambio de esquema sube `version` y agrega su bloque aqui.
  }
}
