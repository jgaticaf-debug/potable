import '../dominio/modelos.dart';
import 'sensores/sensor_cliente.dart';

abstract class Repositorio {
  Future<Usuario> autenticar(String correo, String clave);

  Future<Usuario?> restaurarSesion();

  Future<void> cerrarSesion();

  bool get haySesion;

  Duration? get vigenciaRestante;

  Map<String, dynamic>? get reclamosToken;

  Future<Organizacion> organizacion();

  Future<List<Parametro>> parametros();

  Future<List<Usuario>> usuarios();

  Future<Usuario> guardarUsuario(Usuario usuario, {String? clave});

  Future<void> eliminarUsuario(int usuarioId);

  Future<List<Zona>> zonas();

  Future<Zona> guardarZona(Zona zona);

  Future<void> eliminarZona(int zonaId);

  Future<List<PuntoMuestreo>> puntos();

  Future<PuntoMuestreo> guardarPunto(PuntoMuestreo punto);

  Future<void> eliminarPunto(int puntoId);

  Future<List<Dispositivo>> dispositivos();

  Future<Dispositivo> guardarDispositivo(Dispositivo dispositivo);

  Future<void> eliminarDispositivo(int dispositivoId);

  Future<List<Muestra>> muestras();

  Future<Muestra> guardarMuestra(Muestra muestra);

  Future<List<Alerta>> alertas();

  Future<void> marcarAlertaAtendida(int alertaId);

  Future<Map<int, double>> leerSensores(int puntoId);

  Future<List<EquipoCercano>> buscarEquiposCercanos();

  Future<int> sincronizar();

  Future<void> descargarCatalogo();

  Future<List<RegistroAuditoria>> auditoria({int limite = 200});
}

class ErrorSincronizacion implements Exception {
  const ErrorSincronizacion(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}
