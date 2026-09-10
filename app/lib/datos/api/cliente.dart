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

class SinConexion implements Exception {
  const SinConexion(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class CatalogoRemoto {
  const CatalogoRemoto({
    required this.organizacion,
    required this.parametros,
    required this.zonas,
    required this.puntos,
    required this.dispositivos,
    required this.usuarios,
  });

  final Map<String, dynamic> organizacion;
  final List<Map<String, dynamic>> parametros;
  final List<Map<String, dynamic>> zonas;
  final List<Map<String, dynamic>> puntos;
  final List<Map<String, dynamic>> dispositivos;
  final List<Map<String, dynamic>> usuarios;
}

abstract class Cliente {
  String? get token;

  bool get haySesion;

  Duration? get tiempoRestante;

  Map<String, dynamic>? get reclamos;

  void restaurarToken(String token);

  Future<Map<String, dynamic>> login(String correo, String clave);

  Future<void> logout();

  Future<Map<String, dynamic>> perfil();

  Future<CatalogoRemoto> catalogo();

  Future<List<Map<String, dynamic>>?> muestrasRemotas({int limite});

  Future<List<Map<String, dynamic>>?> alertasRemotas();

  Future<void> atenderAlerta(int alertaId);

  Future<Map<String, dynamic>> sincronizar(List<Map<String, dynamic>> muestras);

  Future<Map<String, dynamic>> guardarZona(Map<String, dynamic> zona);

  Future<void> eliminarZona(int zonaId);

  Future<Map<String, dynamic>> guardarPunto(Map<String, dynamic> punto);

  Future<void> eliminarPunto(int puntoId);

  Future<Map<String, dynamic>> guardarDispositivo(
    Map<String, dynamic> dispositivo,
  );

  Future<void> eliminarDispositivo(int dispositivoId);

  Future<Map<String, dynamic>> guardarUsuario(
    Map<String, dynamic> usuario, {
    String? clave,
  });

  Future<void> eliminarUsuario(int usuarioId);
}

mixin SesionEnToken implements Cliente {
  String? tokenActual;

  @override
  String? get token => tokenActual;

  @override
  bool get haySesion => tokenActual != null;

  @override
  void restaurarToken(String valor) {
    tokenActual = valor.trim().isEmpty ? null : valor.trim();
  }

  String? get encabezado => tokenActual == null ? null : 'Bearer $tokenActual';

  @override
  Map<String, dynamic>? get reclamos =>
      tokenActual == null ? null : Jwt.leerCuerpo(tokenActual!);

  DateTime? get vencimiento =>
      tokenActual == null ? null : Jwt.vencimientoDe(tokenActual!);

  @override
  Duration? get tiempoRestante {
    final vence = vencimiento;
    if (vence == null) return null;
    final resto = vence.difference(DateTime.now());
    return resto.isNegative ? Duration.zero : resto;
  }

  bool get tokenVencido => tiempoRestante == Duration.zero;
}
