import '../../core/config.dart';
import '../semilla.dart';
import 'seguridad.dart';

class RespuestaHttp {
  const RespuestaHttp(this.codigo, this.cuerpo);

  final int codigo;
  final Map<String, dynamic> cuerpo;

  bool get exitosa => codigo >= 200 && codigo < 300;
  String get mensaje => cuerpo['mensaje'] as String? ?? 'Error $codigo';
}

class CuentaAlmacenada {
  const CuentaAlmacenada({
    required this.id,
    required this.organizacionId,
    required this.nombre,
    required this.correo,
    required this.claveHash,
    required this.rol,
    this.activo = true,
  });

  final int id;
  final int organizacionId;
  final String nombre;
  final String correo;
  final String claveHash;
  final String rol;
  final bool activo;
}

class MockApi {
  static String get claveDemo => Config.claveDemo;

  static String get _secreto => Config.jwtSecreto;

  static Duration get vigenciaToken => Config.jwtVigencia;

  static const _rolesAdministracion = {'administrador'};

  late final List<CuentaAlmacenada> _cuentas = _sembrarCuentas();

  static List<CuentaAlmacenada> _sembrarCuentas() => [
        for (final u in Semilla.usuarios)
          CuentaAlmacenada(
            id: u.id,
            organizacionId: u.organizacionId,
            nombre: u.nombre,
            correo: u.correo,
            claveHash: Pbkdf2.hashear(claveDemo),
            rol: u.rol.name,
            activo: u.activo,
          ),
      ];

  final Set<String> _revocados = {};

  int _intentosFallidos = 0;
  int get intentosFallidos => _intentosFallidos;

  Future<RespuestaHttp> postLogin({
    required String correo,
    required String clave,
  }) async {
    await _latencia(Config.latenciaBaseMs);

    final normalizado = correo.trim().toLowerCase();
    CuentaAlmacenada? cuenta;
    for (final c in _cuentas) {
      if (c.correo == normalizado) {
        cuenta = c;
        break;
      }
    }

    if (cuenta == null || !Pbkdf2.verificar(clave, cuenta.claveHash)) {
      _intentosFallidos++;
      return const RespuestaHttp(401, {
        'mensaje': 'Correo o contrasena incorrectos.',
      });
    }

    if (!cuenta.activo) {
      return const RespuestaHttp(403, {
        'mensaje': 'La cuenta esta desactivada. Consulte al administrador.',
      });
    }

    _intentosFallidos = 0;

    final token = Jwt.firmar(
      {
        'sub': cuenta.id,
        'correo': cuenta.correo,
        'nombre': cuenta.nombre,
        'rol': cuenta.rol,
        'org': cuenta.organizacionId,
      },
      _secreto,
      vigencia: vigenciaToken,
    );

    return RespuestaHttp(200, {
      'token': token,
      'tipo': 'Bearer',
      'expira_en': vigenciaToken.inSeconds,
      'usuario': {
        'id': cuenta.id,
        'nombre': cuenta.nombre,
        'correo': cuenta.correo,
        'rol': cuenta.rol,
        'organizacion_id': cuenta.organizacionId,
      },
    });
  }

  Future<RespuestaHttp> postLogout(String? autorizacion) async {
    await _latencia((Config.latenciaBaseMs * 0.4).round());
    final token = _extraerToken(autorizacion);
    if (token != null) _revocados.add(token);
    return const RespuestaHttp(204, {});
  }

  Future<RespuestaHttp> getPerfil(String? autorizacion) async {
    await _latencia((Config.latenciaBaseMs * 0.5).round());
    return _protegido(autorizacion, (reclamos) {
      return RespuestaHttp(200, {
        'id': reclamos['sub'],
        'nombre': reclamos['nombre'],
        'correo': reclamos['correo'],
        'rol': reclamos['rol'],
        'expira': reclamos['exp'],
      });
    });
  }

  Future<RespuestaHttp> postSincronizacion(
    String? autorizacion,
    List<Map<String, dynamic>> muestras,
  ) async {
    await _latencia((Config.latenciaBaseMs * 1.9).round());
    return _protegido(autorizacion, (reclamos) {
      if (_fallasForzadas > 0) {
        _fallasForzadas--;
        return const RespuestaHttp(503, {
          'mensaje': 'Sin conectividad con el servidor. Las muestras quedan '
              'en la cola local y se reintentara el envio.',
        });
      }
      return RespuestaHttp(201, {
        'recibidas': muestras.length,
        'servidor': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<RespuestaHttp> guardarZona(
    String? autorizacion,
    Map<String, dynamic> zona,
  ) async {
    await _latencia((Config.latenciaBaseMs * 0.7).round());
    return _protegido(
      autorizacion,
      (reclamos) {
        final nombre = (zona['nombre'] as String? ?? '').trim();
        if (nombre.isEmpty) {
          return const RespuestaHttp(422, {
            'mensaje': 'El nombre de la zona es obligatorio.',
          });
        }
        return RespuestaHttp(200, {...zona, 'nombre': nombre});
      },
      rolesPermitidos: _rolesAdministracion,
    );
  }

  Future<RespuestaHttp> eliminarZona(String? autorizacion, int zonaId) async {
    await _latencia((Config.latenciaBaseMs * 0.7).round());
    return _protegido(
      autorizacion,
      (reclamos) => const RespuestaHttp(204, {}),
      rolesPermitidos: _rolesAdministracion,
    );
  }

  Future<RespuestaHttp> guardarPunto(
    String? autorizacion,
    Map<String, dynamic> punto,
  ) async {
    await _latencia((Config.latenciaBaseMs * 0.7).round());
    return _protegido(
      autorizacion,
      (reclamos) {
        final nombre = (punto['nombre'] as String? ?? '').trim();
        if (nombre.isEmpty) {
          return const RespuestaHttp(422, {
            'mensaje': 'El nombre del punto es obligatorio.',
          });
        }
        return RespuestaHttp(200, {...punto, 'nombre': nombre});
      },
      rolesPermitidos: _rolesAdministracion,
    );
  }

  Future<RespuestaHttp> eliminarPunto(
    String? autorizacion,
    int puntoId,
  ) async {
    await _latencia((Config.latenciaBaseMs * 0.7).round());
    return _protegido(
      autorizacion,
      (reclamos) => const RespuestaHttp(204, {}),
      rolesPermitidos: _rolesAdministracion,
    );
  }

  late int _fallasForzadas = Config.sincronizacionFallasIniciales;

  RespuestaHttp _protegido(
    String? autorizacion,
    RespuestaHttp Function(Map<String, dynamic> reclamos) manejador, {
    Set<String>? rolesPermitidos,
  }) {
    final token = _extraerToken(autorizacion);
    if (token == null) {
      return const RespuestaHttp(401, {
        'mensaje': 'Falta el encabezado Authorization.',
      });
    }
    if (_revocados.contains(token)) {
      return const RespuestaHttp(401, {'mensaje': 'La sesion fue cerrada.'});
    }

    final Map<String, dynamic> reclamos;
    try {
      reclamos = Jwt.verificar(token, _secreto);
    } on TokenInvalido catch (e) {
      return RespuestaHttp(401, {'mensaje': e.motivo});
    }

    if (rolesPermitidos != null &&
        !rolesPermitidos.contains(reclamos['rol'] as String?)) {
      return const RespuestaHttp(403, {
        'mensaje': 'Su rol no tiene permiso para esta operacion.',
      });
    }

    return manejador(reclamos);
  }

  static String? _extraerToken(String? autorizacion) {
    if (autorizacion == null) return null;
    if (!autorizacion.startsWith('Bearer ')) return null;
    final token = autorizacion.substring(7).trim();
    return token.isEmpty ? null : token;
  }

  static Future<void> _latencia(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
}
