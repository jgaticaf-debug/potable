import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import 'cliente.dart';

class ClienteHttp with SesionEnToken implements Cliente {
  ClienteHttp({http.Client? http_, String? baseUrl, Duration? timeout})
      : _http = http_ ?? http.Client(),
        _base = (baseUrl ?? Config.apiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _timeout = timeout ?? Config.apiTimeout;

  final http.Client _http;
  final String _base;
  final Duration _timeout;

  Uri _uri(String ruta) => Uri.parse('$_base$ruta');

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        ...(encabezado == null ? {} : {'Authorization': encabezado!}),
      };

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
  }) async {
    late http.Response respuesta;

    try {
      final peticion = http.Request(metodo, _uri(ruta))
        ..headers.addAll(_cabeceras);
      if (cuerpo != null) peticion.body = jsonEncode(cuerpo);

      final flujo = await _http.send(peticion).timeout(_timeout);
      respuesta = await http.Response.fromStream(flujo);
    } on SocketException catch (e) {
      throw SinConexion(
        'No se pudo contactar el servidor en $_base. '
        'Revise la conexion. (${e.osError?.message ?? e.message})',
      );
    } on http.ClientException catch (e) {
      throw SinConexion('Fallo la comunicacion con el servidor: ${e.message}');
    } catch (e) {
      if (e is SinConexion) rethrow;
      throw SinConexion('El servidor no respondio a tiempo.');
    }

    return _interpretar(respuesta);
  }

  Map<String, dynamic> _interpretar(http.Response r) {
    final vacia = r.body.trim().isEmpty;

    Map<String, dynamic> cuerpo = const {};
    if (!vacia) {
      try {
        final decodificado = jsonDecode(utf8.decode(r.bodyBytes));
        cuerpo = decodificado is Map<String, dynamic>
            ? decodificado
            : {'datos': decodificado};
      } catch (_) {
        cuerpo = {'mensaje': r.body};
      }
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return cuerpo;

    final mensaje = cuerpo['mensaje'] as String? ?? 'Error ${r.statusCode}';

    if (r.statusCode == 401) {
      tokenActual = null;
      throw SesionExpirada(mensaje);
    }
    throw ErrorApi(r.statusCode, mensaje);
  }

  Future<List<Map<String, dynamic>>> listar(String ruta) async {
    final cuerpo = await _enviar('GET', ruta);
    final datos = cuerpo['datos'];
    if (datos is! List) return const [];
    return datos.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> obtener(String ruta) => _enviar('GET', ruta);

  @override
  Future<Map<String, dynamic>> login(String correo, String clave) async {
    final Map<String, dynamic> cuerpo;
    try {
      cuerpo = await _enviar(
        'POST',
        '/auth/login',
        cuerpo: {'correo': correo, 'clave': clave},
      );
      // Un 401 aqui es clave incorrecta, no sesion vencida: todavia no
      // hay ninguna sesion.
    } on SesionExpirada catch (e) {
      throw ErrorApi(401, e.mensaje);
    }

    tokenActual = cuerpo['token'] as String?;
    return cuerpo['usuario'] as Map<String, dynamic>;
  }

  @override
  Future<void> logout() async {
    try {
      await _enviar('POST', '/auth/logout');
    } on SesionExpirada {
      tokenActual = null;
    } finally {
      tokenActual = null;
    }
  }

  @override
  Future<Map<String, dynamic>> perfil() => _enviar('GET', '/auth/perfil');

  @override
  Future<CatalogoRemoto> catalogo() async {
    final resultados = await Future.wait([
      obtener('/organizacion'),
      listar('/parametros'),
      listar('/zonas'),
      listar('/puntos'),
      listar('/dispositivos'),
      listar('/usuarios'),
    ]);

    return CatalogoRemoto(
      organizacion: resultados[0] as Map<String, dynamic>,
      parametros: resultados[1] as List<Map<String, dynamic>>,
      zonas: resultados[2] as List<Map<String, dynamic>>,
      puntos: resultados[3] as List<Map<String, dynamic>>,
      dispositivos: resultados[4] as List<Map<String, dynamic>>,
      usuarios: resultados[5] as List<Map<String, dynamic>>,
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> muestrasRemotas({int limite = 1000}) =>
      listar('/muestras?limite=$limite');

  @override
  Future<List<Map<String, dynamic>>?> alertasRemotas() => listar('/alertas');

  @override
  Future<void> atenderAlerta(int alertaId) =>
      _enviar('POST', '/alertas/$alertaId/atender');

  @override
  Future<Map<String, dynamic>> sincronizar(
    List<Map<String, dynamic>> muestras,
  ) =>
      _enviar('POST', '/sincronizacion', cuerpo: {'muestras': muestras});

  @override
  Future<Map<String, dynamic>> guardarZona(Map<String, dynamic> zona) {
    final id = zona['id'] as int? ?? 0;
    return id > 0
        ? _enviar('PUT', '/zonas/$id', cuerpo: zona)
        : _enviar('POST', '/zonas', cuerpo: zona);
  }

  @override
  Future<void> eliminarZona(int zonaId) => _enviar('DELETE', '/zonas/$zonaId');

  @override
  Future<Map<String, dynamic>> guardarPunto(Map<String, dynamic> punto) {
    final id = punto['id'] as int? ?? 0;
    return id > 0
        ? _enviar('PUT', '/puntos/$id', cuerpo: punto)
        : _enviar('POST', '/puntos', cuerpo: punto);
  }

  @override
  Future<void> eliminarPunto(int puntoId) =>
      _enviar('DELETE', '/puntos/$puntoId');

  @override
  Future<Map<String, dynamic>> guardarDispositivo(
    Map<String, dynamic> dispositivo,
  ) {
    final id = dispositivo['id'] as int? ?? 0;
    return id > 0
        ? _enviar('PUT', '/dispositivos/$id', cuerpo: dispositivo)
        : _enviar('POST', '/dispositivos', cuerpo: dispositivo);
  }

  @override
  Future<void> eliminarDispositivo(int dispositivoId) =>
      _enviar('DELETE', '/dispositivos/$dispositivoId');

  @override
  Future<Map<String, dynamic>> guardarUsuario(
    Map<String, dynamic> usuario, {
    String? clave,
  }) {
    final id = usuario['id'] as int? ?? 0;
    final cuerpo = {...usuario, if (clave != null && clave.isNotEmpty) 'clave': clave};
    return id > 0
        ? _enviar('PUT', '/usuarios/$id', cuerpo: cuerpo)
        : _enviar('POST', '/usuarios', cuerpo: cuerpo);
  }

  @override
  Future<void> eliminarUsuario(int usuarioId) =>
      _enviar('DELETE', '/usuarios/$usuarioId');

  Future<bool> disponible() async {
    try {
      await _enviar('GET', '/salud');
      return true;
    } catch (_) {
      return false;
    }
  }

  void cerrar() => _http.close();
}
