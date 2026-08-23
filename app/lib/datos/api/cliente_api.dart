import 'mock_api.dart';
import 'seguridad.dart';

class SesionExpirada implements Exception {
  const SesionExpirada(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class ErrorApi implements Exception {
  const ErrorApi(this.codigo, this.mensaje);

  final int codigo;
  final String mensaje;

  @override
  String toString() => mensaje;
}

class ClienteApi {
  ClienteApi(this._api);

  final MockApi _api;

  String? _token;
  String? get token => _token;

  bool get haySesion => _token != null;

  DateTime? get vencimiento =>
      _token == null ? null : Jwt.vencimientoDe(_token!);

  Duration? get tiempoRestante {
    final vence = vencimiento;
    if (vence == null) return null;
    final resto = vence.difference(DateTime.now());
    return resto.isNegative ? Duration.zero : resto;
  }

  bool get tokenVencido {
    final restante = tiempoRestante;
    return restante != null && restante == Duration.zero;
  }

  String? get _encabezado => _token == null ? null : 'Bearer $_token';

  Map<String, dynamic>? get reclamos =>
      _token == null ? null : Jwt.leerCuerpo(_token!);

  Future<Map<String, dynamic>> login(String correo, String clave) async {
    final r = await _api.postLogin(correo: correo, clave: clave);
    if (!r.exitosa) {
      throw ErrorApi(r.codigo, r.mensaje);
    }
    _token = r.cuerpo['token'] as String;
    return r.cuerpo['usuario'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _api.postLogout(_encabezado);
    _token = null;
  }

  Future<Map<String, dynamic>> perfil() async =>
      _desempaquetar(await _api.getPerfil(_encabezado));

  Future<Map<String, dynamic>> sincronizar(
    List<Map<String, dynamic>> muestras,
  ) async =>
      _desempaquetar(await _api.postSincronizacion(_encabezado, muestras));

  Future<Map<String, dynamic>> guardarZona(Map<String, dynamic> zona) async =>
      _desempaquetar(await _api.guardarZona(_encabezado, zona));

  Future<void> eliminarZona(int zonaId) async =>
      _desempaquetar(await _api.eliminarZona(_encabezado, zonaId));

  Future<Map<String, dynamic>> guardarPunto(
    Map<String, dynamic> punto,
  ) async =>
      _desempaquetar(await _api.guardarPunto(_encabezado, punto));

  Future<void> eliminarPunto(int puntoId) async =>
      _desempaquetar(await _api.eliminarPunto(_encabezado, puntoId));

  Map<String, dynamic> _desempaquetar(RespuestaHttp r) {
    if (r.exitosa) return r.cuerpo;
    if (r.codigo == 401) {
      _token = null;
      throw SesionExpirada(r.mensaje);
    }
    throw ErrorApi(r.codigo, r.mensaje);
  }
}
