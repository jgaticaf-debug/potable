import 'dart:convert';

class SensorNoDisponible implements Exception {
  const SensorNoDisponible(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class LecturaSensor {
  const LecturaSensor({
    required this.equipo,
    required this.valores,
    required this.simulada,
    required this.recibida,
  });

  final String equipo;

  final Map<String, double> valores;

  final bool simulada;
  final DateTime recibida;

  static const claveAParametro = {
    'ph': 'pH',
    'turbidez': 'Turbidez',
    'conductividad': 'Conductividad',
    'temperatura': 'Temperatura',
  };

  factory LecturaSensor.desdeJson(String json) {
    final mapa = jsonDecode(json) as Map<String, dynamic>;
    final crudos = mapa['valores'] as Map<String, dynamic>? ?? const {};

    return LecturaSensor(
      equipo: mapa['equipo'] as String? ?? 'desconocido',
      simulada: mapa['simulado'] as bool? ?? false,
      recibida: DateTime.now(),
      valores: {
        for (final e in crudos.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
    );
  }

  Map<int, double> aParametros(Map<String, int> idPorNombre) {
    final resultado = <int, double>{};
    valores.forEach((clave, valor) {
      final nombre = claveAParametro[clave];
      final id = nombre == null ? null : idPorNombre[nombre];
      if (id != null) resultado[id] = valor;
    });
    return resultado;
  }
}

class EquipoCercano {
  const EquipoCercano({required this.identificador, required this.intensidad});

  final String identificador;

  // RSSI en dBm: siempre negativo, y mientras mas cerca de cero, mas cerca
  // esta el aparato. Sirve para ordenar la lista por el que tengo a la mano.
  final int intensidad;

  bool get muyLejos => intensidad < -90;
}

abstract class SensorCliente {
  Future<LecturaSensor> leer(String identificador);

  Future<List<EquipoCercano>> buscarCercanos();
}
