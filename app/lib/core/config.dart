import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static final Map<String, String> _valores = {};

  static bool _cargado = false;
  static bool get cargado => _cargado;

  static String? _motivoFalla;
  static String? get motivoFalla => _motivoFalla;

  static Future<void> cargar({String archivo = '.env'}) async {
    try {
      await dotenv.load(fileName: archivo);
      _valores
        ..clear()
        ..addAll(dotenv.env);
      _cargado = true;
      _motivoFalla = null;
    } catch (e) {
      _valores.clear();
      _cargado = false;
      _motivoFalla = 'No se pudo leer $archivo: $e';
    }
  }

  static void cargarDesdeMapa(Map<String, String> valores) {
    _valores
      ..clear()
      ..addAll(valores);
    _cargado = true;
    _motivoFalla = null;
  }

  static String texto(String clave, String porDefecto) {
    final valor = _valores[clave]?.trim();
    return (valor == null || valor.isEmpty) ? porDefecto : valor;
  }

  static int entero(String clave, int porDefecto) =>
      int.tryParse(texto(clave, '')) ?? porDefecto;

  static bool bandera(String clave, bool porDefecto) {
    final valor = texto(clave, '').toLowerCase();
    if (valor == 'true' || valor == '1') return true;
    if (valor == 'false' || valor == '0') return false;
    return porDefecto;
  }

  static String get apiBaseUrl =>
      texto('API_BASE_URL', 'http://localhost:3000');

  static Duration get apiTimeout =>
      Duration(milliseconds: entero('API_TIMEOUT_MS', 8000));

  static bool get usarMock => bandera('USAR_MOCK', true);

  static String get jwtSecreto =>
      texto('JWT_SECRET', 'potable-secreto-por-defecto-solo-desarrollo');

  static Duration get jwtVigencia =>
      Duration(hours: entero('JWT_VIGENCIA_HORAS', 8));

  static int get pbkdf2Iteraciones => entero('PBKDF2_ITERACIONES', 12000);

  static String get claveDemo => texto('CLAVE_DEMO', 'agua2026');

  static int get latenciaBaseMs => entero('LATENCIA_BASE_MS', 320);

  // Sin valor en el .env decide la plataforma: BLE donde hay radio, simulado
  // en escritorio y en pruebas. Poner false fuerza el simulado en el telefono,
  // que es lo que uso cuando no tengo el equipo a la mano.
  static bool? get usarSensorBle {
    final valor = texto('USAR_SENSOR_BLE', '').toLowerCase();
    if (valor == 'true' || valor == '1') return true;
    if (valor == 'false' || valor == '0') return false;
    return null;
  }

  static int get sincronizacionFallasIniciales =>
      entero('SINCRONIZACION_FALLAS_INICIALES', 1);
}
