import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'api/cliente_api.dart';
import 'api/mock_api.dart';
import 'local/base_datos.dart';
import 'local/mapeadores.dart';
import 'sensores/sensor_cliente.dart';
import 'sensores/sensor_simulado.dart';
import 'repositorio.dart';
import 'semilla.dart';

class RepositorioSqlite implements Repositorio {
  RepositorioSqlite(this._db, {Cliente? cliente, SensorCliente? sensor})
      : _cliente = cliente ?? ClienteApi(MockApi()),
        _sensor = sensor ?? SensorSimulado();

  final Database _db;
  final Cliente _cliente;
  final SensorCliente _sensor;

  @visibleForTesting
  Database get db => _db;

  @visibleForTesting
  Future<void> guardarTokenParaPruebas(String token) =>
      _guardarPreferencia('token', token);

  Usuario? _sesion;

  static String get claveDemo => MockApi.claveDemo;

  static Future<RepositorioSqlite> crear({
    Cliente? cliente,
    SensorCliente? sensor,
  }) async {
    final db = await BaseDatosLocal.abrir();
    final repo = RepositorioSqlite(db, cliente: cliente, sensor: sensor);
    await repo.sembrarSiEstaVacia();
    return repo;
  }

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
  Future<Usuario?> restaurarSesion() async {
    final token = await _leerPreferencia('token');
    if (token == null || token.isEmpty) return null;

    _cliente.restaurarToken(token);

    Map<String, dynamic>? perfil;
    try {
      perfil = await _cliente.perfil();
    } on SesionExpirada {
      await _borrarPreferencia('token');
      return null;
      // Sin servidor no puedo validar la firma, pero la app es
      // offline-first: si el token no ha vencido dejo entrar. El
      // servidor lo rechaza igual cuando toque sincronizar.
    } on SinConexion {
      if (_cliente.tiempoRestante == Duration.zero) {
        await _borrarPreferencia('token');
        return null;
      }
      perfil = _cliente.reclamos == null
          ? null
          : {'id': _cliente.reclamos!['sub']};
    } on ErrorApi {
      await _borrarPreferencia('token');
      return null;
    }

    if (perfil == null) {
      await _borrarPreferencia('token');
      return null;
    }

    final filas = await _db.query(
      'usuarios',
      where: 'id = ? AND activo = 1',
      whereArgs: [perfil['id']],
      limit: 1,
    );
    if (filas.isEmpty) {
      await _borrarPreferencia('token');
      return null;
    }

    _sesion = Mapeadores.usuario(filas.first);
    await _auditar(AccionAuditoria.sesionReanudada, detalle: _sesion!.correo);
    return _sesion;
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

  Future<String?> _leerPreferencia(String clave) async {
    final filas = await _db.query(
      'preferencias',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: [clave],
      limit: 1,
    );
    return filas.isEmpty ? null : filas.first['valor'] as String?;
  }

  Future<void> _borrarPreferencia(String clave) =>
      _db.delete('preferencias', where: 'clave = ?', whereArgs: [clave]);

  @override
  Future<void> descargarCatalogo() async {
    final remoto = await _cliente.catalogo();

    await _db.transaction((txn) async {
      await _reflejar(txn, 'organizaciones', [remoto.organizacion]);
      await _reflejar(txn, 'usuarios', remoto.usuarios);
      await _reflejar(txn, 'parametros', remoto.parametros);
      await _reflejar(txn, 'zonas', remoto.zonas);
      await _reflejar(txn, 'puntos', remoto.puntos);
      await _reflejar(txn, 'dispositivos', remoto.dispositivos);

      await _borrarAusentes(txn, 'dispositivos', remoto.dispositivos);
      await _borrarAusentes(txn, 'puntos', remoto.puntos);
      await _borrarAusentes(txn, 'zonas', remoto.zonas);
      await _borrarAusentes(txn, 'usuarios', remoto.usuarios);
    });

    await descargarHistorial();
  }

  Future<void> descargarHistorial() async {
    final remotas = await _cliente.muestrasRemotas();
    if (remotas == null) return;

    final alertas = await _cliente.alertasRemotas() ?? const [];

    await _db.transaction((txn) async {
      final localPorServidor = <int, int>{};
      for (final f in await txn.query(
        'muestras',
        columns: ['id', 'id_servidor'],
        where: 'id_servidor IS NOT NULL',
      )) {
        localPorServidor[f['id_servidor']! as int] = f['id']! as int;
      }

      for (final cruda in remotas) {
        final idServidor = cruda['id'] as int;
        final fila = {
          'punto_id': cruda['punto_id'],
          'usuario_id': cruda['usuario_id'],
          'fecha_hora': cruda['fecha_hora'],
          'creado_en': cruda['creado_en'] ?? cruda['fecha_hora'],
          'latitud_captura': cruda['latitud_captura'],
          'longitud_captura': cruda['longitud_captura'],
          'clasificacion_global': cruda['clasificacion_global'],
          'parametro_limitante_id': cruda['parametro_limitante_id'],
          'observaciones': cruda['observaciones'] ?? '',
          'sincronizada': 1,
          'fecha_sincronizacion': cruda['recibido_en'],
          'id_servidor': idServidor,
        };

        final existente = localPorServidor[idServidor];
        final int idLocal;
        if (existente != null) {
          await txn.update('muestras', fila,
              where: 'id = ?', whereArgs: [existente]);
          idLocal = existente;
        } else {
          idLocal = await txn.insert('muestras', fila);
          localPorServidor[idServidor] = idLocal;
        }

        await txn.delete('mediciones',
            where: 'muestra_id = ?', whereArgs: [idLocal]);
        for (final m in (cruda['mediciones'] as List? ?? const [])) {
          await txn.insert('mediciones', {
            'muestra_id': idLocal,
            'parametro_id': m['parametro_id'],
            'valor': m['valor'],
            'origen': m['origen'],
            'clasificacion': m['clasificacion'],
          });
        }
      }

      // Las alertas de muestras ya sincronizadas manda el servidor, que
      // ademas sabe cuales se atendieron. Las de la cola no se tocan.
      await txn.rawDelete(
        'DELETE FROM alertas WHERE muestra_id IN '
        '(SELECT id FROM muestras WHERE id_servidor IS NOT NULL)',
      );

      for (final a in alertas) {
        final idLocalMuestra = localPorServidor[a['muestra_id'] as int];
        if (idLocalMuestra == null) continue;

        await txn.insert('alertas', {
          'muestra_id': idLocalMuestra,
          'punto_id': a['punto_id'],
          'tipo': a['tipo'],
          'detalle': a['detalle'],
          'fecha': a['fecha'],
          'atendida': a['atendida'] == true ? 1 : 0,
          'id_servidor': a['id'],
        });
      }
    });
  }

  Future<void> _reflejar(
    DatabaseExecutor txn,
    String tabla,
    List<Map<String, dynamic>> filas,
  ) async {
    for (final fila in filas) {
      await txn.insert(
        tabla,
        _aFilaLocal(fila),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _borrarAusentes(
    DatabaseExecutor txn,
    String tabla,
    List<Map<String, dynamic>> filas,
  ) async {
    final vigentes = filas.map((f) => f['id']).whereType<int>().toList();
    if (vigentes.isEmpty) return;

    final marcadores = List.filled(vigentes.length, '?').join(',');
    final sobrantes = await txn.query(
      tabla,
      columns: ['id'],
      where: 'id NOT IN ($marcadores)',
      whereArgs: vigentes,
    );

    for (final fila in sobrantes) {
      try {
        await txn.delete(tabla, where: 'id = ?', whereArgs: [fila['id']]);
      } on DatabaseException {
        continue;
      }
    }
  }

  Map<String, Object?> _aFilaLocal(Map<String, dynamic> fila) => {
        for (final e in fila.entries)
          e.key: e.value is bool ? (e.value == true ? 1 : 0) : e.value,
      };

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
  Future<List<Usuario>> usuarios() async {
    final filas = await _db.query('usuarios', orderBy: 'nombre');
    return filas.map(Mapeadores.usuario).toList();
  }

  @override
  Future<Usuario> guardarUsuario(Usuario usuario, {String? clave}) async {
    final datos = await _cliente.guardarUsuario({
      'id': usuario.id,
      'organizacion_id': usuario.organizacionId,
      'nombre': usuario.nombre,
      'correo': usuario.correo,
      'rol': usuario.rol.name,
      'activo': usuario.activo,
    }, clave: clave);

    final guardado = Usuario(
      id: datos['id'] as int,
      organizacionId: datos['organizacion_id'] as int,
      nombre: datos['nombre'] as String,
      correo: datos['correo'] as String,
      rol: RolUsuario.values.firstWhere(
        (r) => r.name == datos['rol'],
        orElse: () => RolUsuario.operario,
      ),
      activo: datos['activo'] as bool? ?? true,
    );

    await _db.insert(
      'usuarios',
      Mapeadores.deUsuario(guardado),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _auditar(
      usuario.id == 0
          ? AccionAuditoria.altaUsuario
          : AccionAuditoria.edicionUsuario,
      entidadId: guardado.id,
      detalle: '${guardado.nombre} (${guardado.rol.etiqueta})',
    );
    return guardado;
  }

  @override
  Future<void> eliminarUsuario(int usuarioId) async {
    final muestras = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COUNT(*) FROM muestras WHERE usuario_id = ?',
        [usuarioId],
      ),
    );
    if (muestras != null && muestras > 0) {
      throw ErrorApi(
        409,
        'Tiene $muestras muestra(s) registradas. Desactive la cuenta en vez '
        'de eliminarla, para no perder la trazabilidad.',
      );
    }

    await _cliente.eliminarUsuario(usuarioId);

    final previo =
        await _db.query('usuarios', where: 'id = ?', whereArgs: [usuarioId]);
    await _db.delete('usuarios', where: 'id = ?', whereArgs: [usuarioId]);
    await _auditar(
      AccionAuditoria.bajaUsuario,
      entidadId: usuarioId,
      detalle: previo.isEmpty ? '' : previo.first['nombre']! as String,
    );
  }

  @override
  Future<List<Zona>> zonas() async {
    final filas = await _db.query('zonas', orderBy: 'nombre');
    return filas.map(Mapeadores.zona).toList();
  }

  @override
  Future<Zona> guardarZona(Zona zona) async {
    final datos = await _cliente.guardarZona({
      'id': zona.id,
      'organizacion_id': zona.organizacionId,
      'nombre': zona.nombre,
      'descripcion': zona.descripcion,
      'activa': zona.activa,
    });

    if (zona.id == 0) {
      final idServidor = datos['id'] as int? ?? 0;
      final fila = Mapeadores.deZona(zona, conId: false);
      if (idServidor > 0) fila['id'] = idServidor;

      final id = await _insertarSinDuplicar(
        () => _db.insert('zonas', fila),
        zona.nombre,
      );
      await _auditar(
        AccionAuditoria.altaZona,
        entidadId: id,
        detalle: zona.nombre,
      );
      final filas = await _db.query('zonas', where: 'id = ?', whereArgs: [id]);
      return Mapeadores.zona(filas.first);
    }

    await _insertarSinDuplicar(
      () => _db.update(
        'zonas',
        Mapeadores.deZona(zona, conId: false),
        where: 'id = ?',
        whereArgs: [zona.id],
      ),
      zona.nombre,
    );
    await _auditar(
      AccionAuditoria.edicionZona,
      entidadId: zona.id,
      detalle: zona.nombre,
    );
    return zona;
  }

  Future<int> _insertarSinDuplicar(
    Future<int> Function() operacion,
    String nombre,
  ) async {
    try {
      return await operacion();
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ErrorApi(409, 'Ya existe una zona llamada "$nombre".');
      }
      rethrow;
    }
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
    final datos = await _cliente.guardarPunto({
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
      final idServidor = datos['id'] as int? ?? 0;
      final fila = Mapeadores.dePunto(punto, conId: false);
      if (idServidor > 0) fila['id'] = idServidor;

      final id = await _db.insert('puntos', fila);
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

  @override
  Future<Dispositivo> guardarDispositivo(Dispositivo dispositivo) async {
    final datos = await _cliente.guardarDispositivo({
      'id': dispositivo.id,
      'punto_id': dispositivo.puntoId,
      'identificador': dispositivo.identificador,
      'tipo_sensor': dispositivo.tipoSensor,
      'ultima_calibracion':
          dispositivo.ultimaCalibracion.toIso8601String().substring(0, 10),
    });

    final identificador = datos['identificador'] as String;

    if (dispositivo.id == 0) {
      final idServidor = datos['id'] as int? ?? 0;
      final fila = Mapeadores.deDispositivo(dispositivo)..remove('id');
      if (idServidor > 0) fila['id'] = idServidor;
      fila['identificador'] = identificador;

      final id = await _insertarSinDuplicar(
        () => _db.insert('dispositivos', fila),
        identificador,
      );
      await _auditar(
        AccionAuditoria.altaDispositivo,
        entidadId: id,
        detalle: identificador,
      );
      final filas =
          await _db.query('dispositivos', where: 'id = ?', whereArgs: [id]);
      return Mapeadores.dispositivo(filas.first);
    }

    final fila = Mapeadores.deDispositivo(dispositivo)..remove('id');
    fila['identificador'] = identificador;
    await _insertarSinDuplicar(
      () => _db.update(
        'dispositivos',
        fila,
        where: 'id = ?',
        whereArgs: [dispositivo.id],
      ),
      identificador,
    );
    await _auditar(
      AccionAuditoria.edicionDispositivo,
      entidadId: dispositivo.id,
      detalle: identificador,
    );
    return dispositivo;
  }

  @override
  Future<void> eliminarDispositivo(int dispositivoId) async {
    await _cliente.eliminarDispositivo(dispositivoId);
    final previo = await _db
        .query('dispositivos', where: 'id = ?', whereArgs: [dispositivoId]);
    await _db.delete('dispositivos', where: 'id = ?', whereArgs: [dispositivoId]);
    await _auditar(
      AccionAuditoria.bajaDispositivo,
      entidadId: dispositivoId,
      detalle: previo.isEmpty ? '' : previo.first['identificador']! as String,
    );
  }

  @override
  Future<List<Muestra>> muestras() async {
    final filasMuestras =
        await _db.query('muestras', orderBy: 'fecha_hora DESC');
    if (filasMuestras.isEmpty) return const [];

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

  @override
  Future<List<Alerta>> alertas() async {
    final filas = await _db.query('alertas', orderBy: 'fecha DESC');
    return filas.map(Mapeadores.alerta).toList();
  }

  @override
  Future<void> marcarAlertaAtendida(int alertaId) async {
    final filas = await _db.query(
      'alertas',
      columns: ['id_servidor'],
      where: 'id = ?',
      whereArgs: [alertaId],
      limit: 1,
    );
    final idServidor =
        filas.isEmpty ? null : filas.first['id_servidor'] as int?;

    await _db.update(
      'alertas',
      {'atendida': 1},
      where: 'id = ?',
      whereArgs: [alertaId],
    );
    await _auditar(AccionAuditoria.atencionAlerta, entidadId: alertaId);

    if (idServidor == null) return;
    try {
      await _cliente.atenderAlerta(idServidor);
    } on SinConexion {
      return;
    } on ErrorApi {
      return;
    }
  }

  @override
  Future<List<EquipoCercano>> buscarEquiposCercanos() =>
      _sensor.buscarCercanos();

  @override
  Future<Map<int, double>> leerSensores(int puntoId) async {
    final filas = await _db.query(
      'puntos',
      where: 'id = ?',
      whereArgs: [puntoId],
      limit: 1,
    );
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

    final equipos = await _db.query(
      'dispositivos',
      where: 'punto_id = ?',
      whereArgs: [puntoId],
      limit: 1,
    );
    if (equipos.isEmpty) {
      throw const ErrorSincronizacion(
        'El punto esta marcado como instrumentado pero no tiene equipo '
        'registrado. Agreguelo desde Administracion.',
      );
    }
    final equipo = equipos.first['identificador']! as String;

    final LecturaSensor lectura;
    try {
      lectura = await _sensor.leer(equipo);
    } on SensorNoDisponible catch (e) {
      throw ErrorSincronizacion(e.mensaje);
    }

    final idPorNombre = {
      for (final p in await parametros()) p.nombre: p.id,
    };
    final valores = lectura.aParametros(idPorNombre);

    if (valores.isEmpty) {
      throw const ErrorSincronizacion(
        'El equipo respondio, pero ningun valor coincide con los parametros '
        'configurados.',
      );
    }

    // Anoto el equipo que de verdad contesto, no el que estaba registrado.
    // Con un solo aparato portatil casi nunca son el mismo, y la bitacora
    // tiene que decir la verdad.
    final quienRespondio = lectura.equipo;
    await _auditar(
      AccionAuditoria.lecturaSensor,
      entidadId: puntoId,
      detalle: quienRespondio == equipo
          ? '$equipo: ${valores.length} valor(es)'
          : '$quienRespondio (registrado $equipo): '
              '${valores.length} valor(es)',
    );
    return valores;
  }

  @override
  Future<int> sincronizar() async {
    final pendientes = await _db.query(
      'muestras',
      where: 'sincronizada = 0',
      orderBy: 'fecha_hora',
    );

    if (pendientes.isEmpty) return 0;

    final mediciones = await _db.query(
      'mediciones',
      where: 'muestra_id IN (${List.filled(pendientes.length, '?').join(',')})',
      whereArgs: pendientes.map((f) => f['id']).toList(),
    );
    final porMuestra = <int, List<Map<String, Object?>>>{};
    for (final f in mediciones) {
      (porMuestra[f['muestra_id']! as int] ??= []).add(f);
    }

    final Map<String, dynamic> respuesta;
    try {
      respuesta = await _cliente.sincronizar([
        for (final f in pendientes)
          {
            'id_local': f['id'],
            'punto_id': f['punto_id'],
            'fecha_hora': f['fecha_hora'],
            'creado_en': f['creado_en'],
            'latitud_captura': f['latitud_captura'],
            'longitud_captura': f['longitud_captura'],
            'clasificacion_global': f['clasificacion_global'],
            'parametro_limitante_id': f['parametro_limitante_id'],
            'observaciones': f['observaciones'],
            'mediciones': [
              for (final m in porMuestra[f['id']] ?? const [])
                {
                  'parametro_id': m['parametro_id'],
                  'valor': m['valor'],
                  'origen': m['origen'],
                  'clasificacion': m['clasificacion'],
                },
            ],
          },
      ]);
    } on SesionExpirada {
      rethrow;
    } on SinConexion catch (e) {
      throw ErrorSincronizacion(e.mensaje);
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

    // Me quedo con el id que el servidor le puso. Es lo que despues me
    // deja reconocerla al bajar el historial y no duplicarla.
    final asignaciones = respuesta['asignaciones'];
    if (asignaciones is List) {
      for (final a in asignaciones) {
        if (a is! Map) continue;
        await _db.update(
          'muestras',
          {'id_servidor': a['id_servidor']},
          where: 'id = ?',
          whereArgs: [a['id_local']],
        );
      }
    }

    await _auditar(
      AccionAuditoria.sincronizacion,
      detalle: '${ids.length} muestra(s) enviadas',
    );
    return ids.length;
  }
}
