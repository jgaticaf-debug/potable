import 'package:potable/datos/semilla.dart';
import 'package:potable/dominio/modelos.dart';
import 'package:potable/dominio/motor_evaluacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const motor = MotorEvaluacion(Semilla.parametros);

  Parametro porNombre(String nombre) =>
      Semilla.parametros.firstWhere((p) => p.nombre == nombre);

  final ph = porNombre('pH');
  final turbidez = porNombre('Turbidez');
  final cloro = porNombre('Cloro residual libre');
  final coliformes = porNombre('Coliformes totales');

  group('clasificarValor', () {
    test('valor dentro de la banda de alerta resulta apto', () {
      expect(motor.clasificarValor(ph, 7.2), Clasificacion.apto);
      expect(motor.clasificarValor(cloro, 0.6), Clasificacion.apto);
    });

    test('valor dentro de norma pero fuera de la banda resulta en riesgo', () {
      expect(motor.clasificarValor(ph, 8.2), Clasificacion.riesgo);
      expect(motor.clasificarValor(turbidez, 3), Clasificacion.riesgo);
    });

    test('valor fuera del limite normado resulta en incumplimiento', () {
      expect(motor.clasificarValor(ph, 5.4), Clasificacion.incumplimiento);
      expect(motor.clasificarValor(ph, 9.1), Clasificacion.incumplimiento);
      expect(motor.clasificarValor(cloro, 0.05), Clasificacion.incumplimiento);
      expect(motor.clasificarValor(turbidez, 6), Clasificacion.incumplimiento);
    });

    test('coliformes exige ausencia en 100 mL', () {
      expect(motor.clasificarValor(coliformes, 0), Clasificacion.apto);
      expect(motor.clasificarValor(coliformes, 1),
          Clasificacion.incumplimiento);
    });

    test('los limites son inclusivos', () {
      expect(motor.clasificarValor(ph, 6.0), Clasificacion.riesgo);
      expect(motor.clasificarValor(ph, 8.5), Clasificacion.riesgo);
    });
  });

  group('evaluarMuestra', () {
    test('la clasificacion global toma la peor medicion', () {
      final r = motor.evaluarMuestra({
        ph.id: 7.1,
        turbidez.id: 2.4,
        cloro.id: 0.1,
      });
      expect(r.clasificacion, Clasificacion.incumplimiento);
      expect(r.mediciones, hasLength(3));
    });

    test('muestra sin desviaciones no tiene parametro limitante', () {
      final r = motor.evaluarMuestra({
        ph.id: 7.2,
        turbidez.id: 0.4,
        cloro.id: 0.6,
      });
      expect(r.clasificacion, Clasificacion.apto);
      expect(r.parametroLimitanteId, isNull);
    });

    test('el parametro critico gana como limitante ante un empate', () {
      final r = motor.evaluarMuestra({
        turbidez.id: 9,
        cloro.id: 0.05,
      });
      expect(r.clasificacion, Clasificacion.incumplimiento);
      expect(r.parametroLimitanteId, cloro.id);
    });

    test('sin parametro critico gana el valor mas desviado', () {
      final r = motor.evaluarMuestra({
        ph.id: 5.9,
        turbidez.id: 40,
      });
      expect(r.parametroLimitanteId, turbidez.id);
    });

    test('el origen declarado se conserva en la medicion', () {
      final r = motor.evaluarMuestra(
        {ph.id: 7.2},
        origenes: {ph.id: ViaCaptura.manual},
      );
      expect(r.mediciones.single.origen, ViaCaptura.manual);
    });

    test('los parametros desconocidos se ignoran', () {
      final r = motor.evaluarMuestra({999: 12.0, ph.id: 7.2});
      expect(r.mediciones, hasLength(1));
      expect(r.mediciones.single.parametroId, ph.id);
    });

    test('una muestra vacia no rompe la evaluacion', () {
      final r = motor.evaluarMuestra({});
      expect(r.clasificacion, Clasificacion.apto);
      expect(r.mediciones, isEmpty);
    });
  });

  group('porcentajeConformidad', () {
    test('cuenta solo las muestras aptas', () {
      final muestras = [
        _muestra(Clasificacion.apto),
        _muestra(Clasificacion.apto),
        _muestra(Clasificacion.riesgo),
        _muestra(Clasificacion.incumplimiento),
      ];
      expect(MotorEvaluacion.porcentajeConformidad(muestras), 50);
    });

    test('sin muestras devuelve cero y no divide por cero', () {
      expect(MotorEvaluacion.porcentajeConformidad([]), 0);
    });
  });

  group('criticosFaltantes', () {
    test('con todos los parametros medidos no falta nada', () {
      final todos = Semilla.parametros.map((p) => p.id);
      expect(motor.criticosFaltantes(todos), isEmpty);
    });

    test('detecta el critico de laboratorio que falta en campo', () {
      // El caso real: coliformes necesita incubacion, en campo no se mide.
      final enCampo = Semilla.parametros
          .where((p) => p.id != coliformes.id)
          .map((p) => p.id);

      final faltantes = motor.criticosFaltantes(enCampo);

      expect(faltantes, hasLength(1));
      expect(faltantes.single.nombre, 'Coliformes totales');
    });

    test('un parametro no critico ausente no cuenta', () {
      final nitratos = porNombre('Nitratos');
      expect(nitratos.critico, isFalse);

      final sinNitratos = Semilla.parametros
          .where((p) => p.id != nitratos.id)
          .map((p) => p.id);

      expect(motor.criticosFaltantes(sinNitratos), isEmpty);
    });

    test('sin ninguna medicion faltan todos los criticos', () {
      final criticos =
          Semilla.parametros.where((p) => p.critico).map((p) => p.nombre);

      expect(
        motor.criticosFaltantes(const <int>[]).map((p) => p.nombre),
        unorderedEquals(criticos),
      );
    });

    test('una muestra sin el critico no deberia presumir de apta', () {
      // El motor sigue evaluando lo que recibe; lo que cambia es que ahora
      // se puede saber que el veredicto salio incompleto.
      final valores = {ph.id: 7.2, turbidez.id: 0.5, cloro.id: 0.6};
      final resultado = motor.evaluarMuestra(valores);

      expect(resultado.clasificacion, Clasificacion.apto);
      expect(
        motor.criticosFaltantes(valores.keys),
        isNotEmpty,
        reason: 'la interfaz tiene que marcarla como evaluacion parcial',
      );
    });

    test('totalParametros refleja el catalogo', () {
      expect(motor.totalParametros, Semilla.parametros.length);
    });
  });
}

Muestra _muestra(Clasificacion c) => Muestra(
      id: 1,
      puntoId: 1,
      usuarioId: 1,
      fechaHora: DateTime(2026, 8, 21),
      creadoEn: DateTime(2026, 8, 21),
      latitudCaptura: 14.6,
      longitudCaptura: -90.5,
      clasificacionGlobal: c,
      mediciones: const [],
    );
