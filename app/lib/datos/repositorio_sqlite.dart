import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'api/cliente_api.dart';
import 'api/mock_api.dart';
import 'local/base_datos.dart';
import 'local/mapeadores.dart';
import 'repositorio.dart';
import 'semilla.dart';

/// Repositorio con persistencia real en SQLite.
///
/// El dato se guarda primero en el dispositivo y solo despues viaja al
/// servidor. Ese orden es lo que permite capturar sin conexion: la muestra
/// existe aunque el envio falle.
class RepositorioSqlite implements Repositorio {
  RepositorioSqlite(this._db, {ClienteApi? cliente})
      : _cliente = cliente ?? ClienteApi(MockApi());

  final Database _db;
  final ClienteApi _cliente;

  final _azar = Random();

  Usuario? _sesion;

  static String get claveDemo => MockApi.claveDemo;

  /// Abre la base, la siembra la primera vez y devuelve el repositorio.
  static Future<RepositorioSqlite> crear({ClienteApi? cliente}) async {
    final db = await BaseDatosLocal.abrir();
    final repo = RepositorioSqlite(db, cliente: cliente);
    await repo.sembrarSiEstaVacia();
    return repo;
  }

  // --- Siembra inicial -----------------------------------------------------

  /// Carga el catalogo y el historial de ejemplo la primera vez que se abre
  /// la base. En arranques posteriores no hace nada.
  Future<void> sembrarSiEstaVacia() async {
    final total = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM organizaciones'),
    );
    if (total != null && total > 0) return;

    const motor = MotorEvaluacion(Semilla.parametros);
    final muestras = Semilla.muestras(motor);

    await _db.transaction((txn) async {
      await txn.insert(
        'organizaciones',
        Mapeadores.deOrganizacion(Semilla.organizacion),
      );
      for (final u in Semilla.usuarios) {
        await txn.insert('usuarios', Mapeadores.deUsuario(u));
      }
      for (final p in Semilla.parametros) {
        await txn.insert('parametros', Mapeadores.deParametro(p));
      }
      for (final z in Semilla.zonas) {
        await txn.insert('zonas', Mapeadores.deZona(z));
      }
      for (final p in Semilla.puntos) {
        await txn.insert('puntos', Mapeadores.dePunto(p));
      }
      for (final d in Semilla.dispositivos()) {
        await txn.insert('dispositivos', Mapeadores.deDispositivo(d));
      }

      for (final m in muestras) {
        final id = await txn.insert(
          'muestras',
          Mapeadores.deMuestra(m, conId: false),
        );
        for (final med in m.mediciones) {
          await txn.insert('mediciones', Mapeadores.deMedicion(med, id));
        }
        if (m.clasificacionGlobal != Clasificacion.apto) {
          final limitante = m.parametroLimitanteId == null
              ? null
              : motor.parametroPorId(m.parametroLimitanteId!);
          final valor = m.parametroLimitanteId == null
              ? null
              : m.medicionDe(m.parametroLimitanteId!)?.valor;
          await txn.insert('alertas', {
            'muestra_id': id,
            'punto_id': m.puntoId,
            'tipo': m.clasificacionGlobal.etiqueta,
            'detalle': limitante == null || valor == null
                ? 'Muestra fuera de norma.'
                : '${limitante.nombre} en $valor ${limitante.unidad} '
                    '(norma: ${limitante.rangoLegible}).',
            'fecha': m.fechaHora.toIso8601String(),
            'atendida': m.fechaHora
                    .isBefore(DateTime.now().subtract(const Duration(days: 14)))
                ? 1
                : 0,
          });
        }
      }
    });
  }

  // --- Bitacora ------------------------------------------------------------

  /// Deja constancia de una accion. Se llama dentro de la misma transaccion
  /// que la operacion cuando importa que ambas caigan juntas.
  Future<void> _auditar(
    AccionAuditoria accion, {
    int? entidadId,
    String detalle = '',
    DatabaseExecutor? txn,
  }) async {
    final u = _sesion;
    if (u == null) return;
    await (txn ?? _db).insert('auditoria', {
      'fecha': DateTime.now().toIso8601String(),
      'usuario_id': u.id,
      'usuario_nombre': u.nombre,
      'rol': u.rol.etiqueta,
      'accion': accion.name,
      'entidad_id': entidadId,
      'detalle': detalle,
    });
  }

  @override
  Future<List<RegistroAuditoria>> auditoria({int limite = 200}) async {
    final filas = await _db.query(
      'auditoria',
      orderBy: 'fecha DESC, id DESC',
      limit: limite,
    );
    return filas.map(Mapeadores.auditoria).toList();
  }

  // --- Sesion --------------------------------------------------------------

  @override
  bool get haySesion => _cliente.haySesion;

  @override
  Duration? get vigenciaRestante => _cliente.tiempoRestante;

  @override
  Map<String, dynamic>? get reclamosToken => _cliente.reclamos;

  @override
  Future<Usuario> autenticar(String correo, String clave) async {
    final datos = await _cliente.login(correo, clave);

    final filas = await _db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [datos['id']],
      limit: 1,
    );

    _sesion = filas.isEmpty
        ? Usuario(
            id: datos['id'] as int,
            organizacionId: datos['organizacion_id'] as int,
            nombre: datos['nombre'] as String,
            correo: datos['correo'] as String,
            rol: RolUsuario.values.firstWhere(
              (r) => r.name == datos['rol'],
              orElse: () => RolUsuario.operario,
            ),
          )
        : Mapeadores.usuario(filas.first);

    await _guardarPreferencia('token', _cliente.token ?? '');
    await _auditar(AccionAuditoria.inicioSesion, detalle: _sesion!.correo);
    return _sesion!;
  }

  @override
  Future<void> cerrarSesion() async {
    await _auditar(AccionAuditoria.cierreSesion);
    await _cliente.logout();
    await _borrarPreferencia('token');
    _sesion = null;
  }

  Future<void> _guardarPreferencia(String clave, String valor) =>
      _db.insert(
        'preferencias',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> _borrarPreferencia(String clave) =>
      _db.delete('preferencias', where: 'clave = ?', whereArgs: [clave]);

  // --- Catalogo ------------------------------------------------------------

  @override
  Future<Organizacion> organizacion() async {
    final filas = await _db.query('organizaciones', limit: 1);
    return Mapeadores.organizacion(filas.first);
  }

  @override
  Future<List<Parametro>> parametros() async {
    final filas = await _db.query('parametros', orderBy: 'id');
    return filas.map(Mapeadores.parametro).toList();
  }

  @override
  Future<List<Zona>> zonas() async {
    final filas = await _db.query('zonas', orderBy: 'nombre');
    return filas.map(Mapeadores.zona).toList();
  }

  @override
  Future<Zona> guardarZona(Zona zona) async {
    await _cliente.guardarZona({
      'id': zona.id,
      'organizacion_id': zona.organizacionId,
      'nombre': zona.nombre,
      'descripcion': zona.descripcion,
      'activa': zona.activa,
    });

    if (zona.id == 0) {
      final id =
          await _db.insert('zonas', Mapeadores.deZona(zona, conId: false));
      await _auditar(
        AccionAuditoria.altaZona,
        entidadId: id,
        detalle: zona.nombre,
      );
      final filas = await _db.query('zonas', where: 'id = ?', whereArgs: [id]);
      return Mapeadores.zona(filas.first);
    }

    await _db.update(
      'zonas',
      Mapeadores.deZona(zona, conId: false),
      where: 'id = ?',
      whereArgs: [zona.id],
    );
    await _auditar(
      AccionAuditoria.edicionZona,
      entidadId: zona.id,
      detalle: zona.nombre,
    );
    return zona;
  }

  @override
  Future<void> eliminarZona(int zonaId) async {
    await _cliente.eliminarZona(zonaId);
    final previa = await _db.query('zonas', where: 'id = ?', whereArgs: [zonaId]);
    await _db.delete('zonas', where: 'id = ?', whereArgs: [zonaId]);
    await _auditar(
      AccionAuditoria.bajaZona,
      entidadId: zonaId,
      detalle: previa.isEmpty ? '' : previa.first['nombre']! as String,
    );
  }

  @override
  Future<List<PuntoMuestreo>> puntos() async {
    final filas = await _db.query('puntos', orderBy: 'zona_id, nombre');
    return filas.map(Mapeadores.punto).toList();
  }

  @override
  Future<PuntoMuestreo> guardarPunto(PuntoMuestreo punto) async {
    await _cliente.guardarPunto({
      'id': punto.id,
      'organizacion_id': punto.organizacionId,
      'zona_id': punto.zonaId,
      'nombre': punto.nombre,
      'tipo': punto.tipo.name,
      'instrumentado': punto.instrumentado,
      'latitud': punto.latitud,
      'longitud': punto.longitud,
    });

    if (punto.id == 0) {
      final id =
          await _db.insert('puntos', Mapeadores.dePunto(punto, conId: false));
      await _auditar(
        AccionAuditoria.altaPunto,
        entidadId: id,
        detalle: punto.nombre,
      );
      final filas = await _db.query('puntos', where: 'id = ?', whereArgs: [id]);
      return Mapeadores.punto(filas.first);
    }

    await _db.update(
      'puntos',
      Mapeadores.dePunto(punto, conId: false),
      where: 'id = ?',
      whereArgs: [punto.id],
    );
    await _auditar(
      AccionAuditoria.edicionPunto,
      entidadId: punto.id,
      detalle: punto.nombre,
    );
    return punto;
  }

  @override
  Future<void> eliminarPunto(int puntoId) async {
    await _cliente.eliminarPunto(puntoId);
    final previa =
        await _db.query('puntos', where: 'id = ?', whereArgs: [puntoId]);
    await _db.delete('puntos', where: 'id = ?', whereArgs: [puntoId]);
    await _auditar(
      AccionAuditoria.bajaPunto,
      entidadId: puntoId,
      detalle: previa.isEmpty ? '' : previa.first['nombre']! as String,
    );
  }

  @override
  Future<List<Dispositivo>> dispositivos() async {
    final filas = await _db.query('dispositivos', orderBy: 'identificador');
    return filas.map(Mapeadores.dispositivo).toList();
  }

  // --- Muestras ------------------------------------------------------------

  @override
  Future<List<Muestra>> muestras() async {
    final filasMuestras =
        await _db.query('muestras', orderBy: 'fecha_hora DESC');
    if (filasMuestras.isEmpty) return const [];

    // Una sola consulta para todas las mediciones, agrupadas en memoria:
    // evita N+1 consultas cuando el historial crece.
    final filasMediciones = await _db.query('mediciones');
    final porMuestra = <int, List<Medicion>>{};
    for (final f in filasMediciones) {
      final id = f['muestra_id']! as int;
      (porMuestra[id] ??= []).add(Mapeadores.medicion(f));
    }

    return [
      for (final f in filasMuestras)
        Mapeadores.muestra(f, porMuestra[f['id']] ?? const []),
    ];
  }

  @override
  Future<Muestra> guardarMuestra(Muestra muestra) async {
    late int id;

    await _db.transaction((txn) async {
      id = await txn.insert('muestras', Mapeadores.deMuestra(muestra, conId: false));

      for (final m in muestra.mediciones) {
        await txn.insert('mediciones', Mapeadores.deMedicion(m, id));
      }

      if (muestra.clasificacionGlobal != Clasificacion.apto) {
        await txn.insert('alertas', {
          'muestra_id': id,
          'punto_id': muestra.puntoId,
          'tipo': muestra.clasificacionGlobal.etiqueta,
          'detalle': await _detalleAlerta(txn, muestra),
          'fecha': muestra.fechaHora.toIso8601String(),
          'atendida': 0,
        });
      }

      await _auditar(
        AccionAuditoria.registroMuestra,
        entidadId: id,
        detalle: '${muestra.clasificacionGlobal.etiqueta} en '
            '${await _nombrePunto(txn, muestra.puntoId)}',
        txn: txn,
      );
    });

    final filas = await _db.query('muestras', where: 'id = ?', whereArgs: [id]);
    return Mapeadores.muestra(filas.first, muestra.mediciones);
  }

  Future<String> _nombrePunto(DatabaseExecutor txn, int puntoId) async {
    final filas = await txn.query(
      'puntos',
      columns: ['nombre'],
      where: 'id = ?',
      whereArgs: [puntoId],
      limit: 1,
    );
    return filas.isEmpty ? 'punto $puntoId' : filas.first['nombre']! as String;
  }

  Future<String> _detalleAlerta(DatabaseExecutor txn, Muestra muestra) async {
    final id = muestra.parametroLimitanteId;
    if (id == null) return 'Muestra fuera de norma.';
    final filas =
        await txn.query('parametros', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return 'Muestra fuera de norma.';
    final p = Mapeadores.parametro(filas.first);
    final valor = muestra.medicionDe(id)?.valor;
    return '${p.nombre} en $valor ${p.unidad} (norma: ${p.rangoLegible}).';
  }

  // --- Alertas -------------------------------------------------------------

  @override
  Future<List<Alerta>> alertas() async {
    final filas = await _db.query('alertas', orderBy: 'fecha DESC');
    return filas.map(Mapeadores.alerta).toList();
  }

  @override
  Future<void> marcarAlertaAtendida(int alertaId) async {
    await _db.update(
      'alertas',
      {'atendida': 1},
      where: 'id = ?',
      whereArgs: [alertaId],
    );
    await _auditar(AccionAuditoria.atencionAlerta, entidadId: alertaId);
  }

  // --- Sensores ------------------------------------------------------------

  @override
  Future<Map<int, double>> leerSensores(int puntoId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final filas =
        await _db.query('puntos', where: 'id = ?', whereArgs: [puntoId], limit: 1);
    if (filas.isEmpty) {
      throw const ErrorSincronizacion('El punto ya no existe.');
    }
    final punto = Mapeadores.punto(filas.first);
    if (!punto.instrumentado) {
      throw const ErrorSincronizacion(
        'Este punto no tiene dispositivo instrumentado. Registre los valores '
        'de forma manual.',
      );
    }

    final previas = await _db.rawQuery(
      '''
      SELECT me.parametro_id, me.valor
      FROM mediciones me
      JOIN muestras mu ON mu.id = me.muestra_id
      WHERE mu.punto_id = ?
      ORDER BY mu.fecha_hora DESC
      LIMIT 20
      ''',
      [puntoId],
    );

    final base = <int, double>{};
    for (final f in previas) {
      base.putIfAbsent(
        f['parametro_id']! as int,
        () => (f['valor']! as num).toDouble(),
      );
    }

    final lectura = <int, double>{};
    for (final p in await parametros()) {
      if (p.viaCaptura != ViaCaptura.sensor) continue;
      final centro =
          base[p.id] ?? ((p.limiteMin ?? 0) + (p.limiteMax ?? 1)) / 2;
      final amplitud = ((p.limiteMax ?? 10) - (p.limiteMin ?? 0)) * 0.10;
      final valor = max(0.0, centro + (_azar.nextDouble() - 0.45) * amplitud);
      final decimales = p.unidad == 'uS/cm' ? 0 : 2;
      final f = pow(10, decimales);
      lectura[p.id] = (valor * f).round() / f;
    }

    await _auditar(AccionAuditoria.lecturaSensor, entidadId: puntoId);
    return lectura;
  }

  // --- Sincronizacion ------------------------------------------------------

  @override
  Future<int> sincronizar() async {
    final pendientes = await _db.query(
      'muestras',
      where: 'sincronizada = 0',
      orderBy: 'fecha_hora',
    );

    if (pendientes.isEmpty) return 0;

    try {
      await _cliente.sincronizar([
        for (final f in pendientes) {'id': f['id'], 'punto_id': f['punto_id']},
      ]);
    } on ErrorApi catch (e) {
      throw ErrorSincronizacion(e.mensaje);
    }

    final ahora = DateTime.now().toIso8601String();
    final ids = pendientes.map((f) => f['id']).toList();
    final marcadores = List.filled(ids.length, '?').join(',');

    await _db.rawUpdate(
      'UPDATE muestras SET sincronizada = 1, fecha_sincronizacion = ? '
      'WHERE id IN ($marcadores)',
      [ahora, ...ids],
    );

    await _auditar(
      AccionAuditoria.sincronizacion,
      detalle: '${ids.length} muestra(s) enviadas',
    );
    return ids.length;
  }
}
