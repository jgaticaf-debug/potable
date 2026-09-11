import 'dart:convert';
import 'dart:math';

import 'sensor_cliente.dart';

class SensorSimulado implements SensorCliente {
  SensorSimulado({this.baseDelPunto, this.latencia = const Duration(milliseconds: 1500)});

  final Future<Map<String, double>> Function(String equipo)? baseDelPunto;
  final Duration latencia;

  final _azar = Random();

  static const _centro = {
    'ph': 7.2,
    'turbidez': 0.8,
    'conductividad': 320.0,
    'temperatura': 22.0,
  };

  static const _amplitud = {
    'ph': 0.9,
    'turbidez': 1.6,
    'conductividad': 190.0,
    'temperatura': 6.0,
  };

  static const _decimales = {
    'ph': 2,
    'turbidez': 2,
    'conductividad': 0,
    'temperatura': 1,
  };

  @override
  Future<List<EquipoCercano>> buscarCercanos() async {
    await Future<void>.delayed(latencia);
    return const [
      EquipoCercano(identificador: 'ESP32-POZO1', intensidad: -52),
      EquipoCercano(identificador: 'ESP32-TANQN', intensidad: -74),
    ];
  }

  @override
  Future<LecturaSensor> leer(String identificador) async {
    await Future<void>.delayed(latencia);

    final base = await baseDelPunto?.call(identificador) ?? const {};
    final valores = <String, double>{};

    for (final clave in _centro.keys) {
      final centro = base[clave] ?? _centro[clave]!;
      final desvio = (_azar.nextDouble() - 0.45) * _amplitud[clave]!;
      final factor = pow(10, _decimales[clave]!);
      valores[clave] =
          max(0.0, (centro + desvio) * factor).round() / factor;
    }

    final json = jsonEncode({
      'equipo': identificador,
      'simulado': true,
      'ms': DateTime.now().millisecondsSinceEpoch % 100000,
      'valores': valores,
    });

    return LecturaSensor.desdeJson(json);
  }
}
