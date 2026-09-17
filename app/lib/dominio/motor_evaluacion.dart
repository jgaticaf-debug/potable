import 'modelos.dart';

class ResultadoEvaluacion {
  const ResultadoEvaluacion({
    required this.clasificacion,
    required this.mediciones,
    this.parametroLimitanteId,
  });

  final Clasificacion clasificacion;
  final List<Medicion> mediciones;

  final int? parametroLimitanteId;
}

class MotorEvaluacion {
  const MotorEvaluacion(this.parametros);

  final List<Parametro> parametros;

  Parametro? parametroPorId(int id) {
    for (final p in parametros) {
      if (p.id == id) return p;
    }
    return null;
  }

  Clasificacion clasificarValor(Parametro p, double valor) {
    // Fuera de norma = incumplimiento. Dentro de norma pero fuera de la
    // banda = riesgo. La banda es nuestra, no de COGUANOR.
    final fueraDeNorma = (p.limiteMin != null && valor < p.limiteMin!) ||
        (p.limiteMax != null && valor > p.limiteMax!);
    if (fueraDeNorma) return Clasificacion.incumplimiento;

    final enBandaAlerta = (p.alertaMin != null && valor < p.alertaMin!) ||
        (p.alertaMax != null && valor > p.alertaMax!);
    if (enBandaAlerta) return Clasificacion.riesgo;

    return Clasificacion.apto;
  }

  double desviacionRelativa(Parametro p, double valor) {
    final min = p.limiteMin;
    final max = p.limiteMax;
    if (min != null && valor < min) {
      final amplitud = (max ?? min) - min;
      return amplitud > 0 ? (min - valor) / amplitud : (min - valor).abs() + 1;
    }
    if (max != null && valor > max) {
      final amplitud = max - (min ?? 0);
      return amplitud > 0 ? (valor - max) / amplitud : (valor - max).abs() + 1;
    }
    return 0;
  }

  ResultadoEvaluacion evaluarMuestra(
    Map<int, double> valores, {
    Map<int, ViaCaptura> origenes = const {},
  }) {
    final mediciones = <Medicion>[];

    for (final entrada in valores.entries) {
      final p = parametroPorId(entrada.key);
      if (p == null) continue;
      mediciones.add(
        Medicion(
          parametroId: p.id,
          valor: entrada.value,
          origen: origenes[p.id] ?? p.viaCaptura,
          clasificacion: clasificarValor(p, entrada.value),
        ),
      );
    }

    if (mediciones.isEmpty) {
      return const ResultadoEvaluacion(
        clasificacion: Clasificacion.apto,
        mediciones: [],
      );
    }

    // Los indicativos se miden y se guardan, pero no votan. El de turbidez
    // tiene +-22 UNT contra un limite de 5: seria una moneda al aire.
    final decisivas =
        mediciones.where((m) => !(parametroPorId(m.parametroId)?.indicativo ?? false));

    final global = Clasificacion.peorDe(decisivas.map((m) => m.clasificacion));

    Medicion? limitante;
    var mejorPeso = -1.0;
    for (final m in decisivas) {
      if (m.clasificacion != global) continue;
      final p = parametroPorId(m.parametroId)!;
    // Si empatan, gana el critico (cloro, coliformes) y entre iguales
    // el que este mas lejos de su limite.
      final peso =
          (p.critico ? 1000 : 0) + desviacionRelativa(p, m.valor);
      if (peso > mejorPeso) {
        mejorPeso = peso;
        limitante = m;
      }
    }

    return ResultadoEvaluacion(
      clasificacion: global,
      mediciones: mediciones,
      parametroLimitanteId:
          global == Clasificacion.apto ? null : limitante?.parametroId,
    );
  }

  // Los criticos que no se midieron. Coliformes es el caso tipico: necesita
  // incubacion de laboratorio, asi que en campo la muestra sale sin el. Sin
  // esto la app diria "apto" sin haber mirado el parametro que mas pesa.
  List<Parametro> criticosFaltantes(Iterable<int> medidos) {
    final presentes = medidos.toSet();
    return [
      for (final p in parametros)
        if (p.critico && !presentes.contains(p.id)) p,
    ];
  }

  int get totalParametros => parametros.length;

  static double porcentajeConformidad(List<Muestra> muestras) {
    if (muestras.isEmpty) return 0;
    final conformes = muestras
        .where((m) => m.clasificacionGlobal == Clasificacion.apto)
        .length;
    return conformes / muestras.length * 100;
  }
}
