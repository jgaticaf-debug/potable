import 'dart:math';

import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';

class Semilla {
  static const organizacion = Organizacion(
    id: 1,
    nombre: 'Agroindustria del Valle, S.A.',
    nit: '4521896-7',
  );

  static const parametros = <Parametro>[
    Parametro(
      id: 1,
      nombre: 'pH',
      unidad: 'uds pH',
      viaCaptura: ViaCaptura.sensor,
      limiteMin: 6.0,
      limiteMax: 8.5,
      alertaMin: 6.5,
      alertaMax: 8.0,
      descripcion:
          'Acidez o alcalinidad. Fuera de rango el agua corroe la tuberia y '
          'el cloro pierde eficacia.',
    ),
    Parametro(
      id: 2,
      nombre: 'Turbidez',
      unidad: 'UNT',
      viaCaptura: ViaCaptura.sensor,
      limiteMin: 0,
      limiteMax: 5,
      alertaMax: 1,
      descripcion:
          'Particulas en suspension. La norma admite hasta 5 UNT, pero arriba '
          'de 1 UNT ya se compromete la desinfeccion.',
    ),
    Parametro(
      id: 3,
      nombre: 'Cloro residual libre',
      unidad: 'mg/L',
      viaCaptura: ViaCaptura.manual,
      limiteMin: 0.2,
      limiteMax: 1.0,
      alertaMin: 0.3,
      alertaMax: 0.9,
      critico: true,
      descripcion:
          'Desinfeccion activa en el punto. Por debajo del minimo el cloro se '
          'agoto; por encima aparecen subproductos.',
    ),
    Parametro(
      id: 4,
      nombre: 'Conductividad',
      unidad: 'uS/cm',
      viaCaptura: ViaCaptura.sensor,
      limiteMin: 0,
      limiteMax: 750,
      alertaMax: 600,
      descripcion:
          'No dice que hay en el agua, pero delata cambios respecto a la '
          'linea base. Funciona como alerta temprana.',
    ),
    Parametro(
      id: 5,
      nombre: 'Nitratos',
      unidad: 'mg/L',
      viaCaptura: ViaCaptura.manual,
      limiteMin: 0,
      limiteMax: 50,
      alertaMax: 35,
      descripcion: 'Senal de contaminacion agricola o residual.',
    ),
    Parametro(
      id: 6,
      nombre: 'Coliformes totales',
      unidad: 'NMP/100 mL',
      viaCaptura: ViaCaptura.manual,
      limiteMin: 0,
      limiteMax: 0,
      alertaMax: 0,
      critico: true,
      descripcion:
          'Contaminacion fecal reciente. La norma exige ausencia en 100 mL.',
    ),
    Parametro(
      id: 7,
      nombre: 'Temperatura',
      unidad: 'C',
      viaCaptura: ViaCaptura.sensor,
      limiteMin: 10,
      limiteMax: 32,
      alertaMin: 15,
      alertaMax: 28,
      descripcion:
          'Interpreta a los demas: a mayor temperatura el cloro se degrada '
          'mas rapido.',
    ),
  ];

  static const usuarios = <Usuario>[
    Usuario(
      id: 1,
      organizacionId: 1,
      nombre: 'Jason Gatica',
      correo: 'operario@aguapura.gt',
      rol: RolUsuario.operario,
    ),
    Usuario(
      id: 2,
      organizacionId: 1,
      nombre: 'Lucia Ramirez',
      correo: 'calidad@aguapura.gt',
      rol: RolUsuario.calidad,
    ),
    Usuario(
      id: 3,
      organizacionId: 1,
      nombre: 'Marco Chavarria',
      correo: 'admin@aguapura.gt',
      rol: RolUsuario.administrador,
    ),
  ];

  static const zonas = <Zona>[
    Zona(
      id: 1,
      organizacionId: 1,
      nombre: 'Plantacion 1',
      descripcion: 'Bloque norte. Riego por goteo y consumo de personal.',
    ),
    Zona(
      id: 2,
      organizacionId: 1,
      nombre: 'Plantacion 2',
      descripcion: 'Bloque sur. Abastecida por pozo propio.',
    ),
    Zona(
      id: 3,
      organizacionId: 1,
      nombre: 'Plantacion 3',
      descripcion: 'Bloque de expansion. Aun sin instrumentacion.',
    ),
    Zona(
      id: 4,
      organizacionId: 1,
      nombre: 'Planta de proceso',
      descripcion: 'Lavado, empaque y agua de consumo humano.',
    ),
  ];

  static const puntos = <PuntoMuestreo>[
    PuntoMuestreo(
      id: 1,
      organizacionId: 1,
      zonaId: 1,
      nombre: 'Pozo 1',
      tipo: TipoPunto.pozo,
      instrumentado: true,
    ),
    PuntoMuestreo(
      id: 2,
      organizacionId: 1,
      zonaId: 1,
      nombre: 'Tanque elevado norte',
      tipo: TipoPunto.tanque,
      instrumentado: true,
    ),
    PuntoMuestreo(
      id: 3,
      organizacionId: 1,
      zonaId: 2,
      nombre: 'Pozo 2',
      tipo: TipoPunto.pozo,
      instrumentado: true,
    ),
    PuntoMuestreo(
      id: 4,
      organizacionId: 1,
      zonaId: 2,
      nombre: 'Linea de riego sur',
      tipo: TipoPunto.linea,
      instrumentado: false,
    ),
    PuntoMuestreo(
      id: 5,
      organizacionId: 1,
      zonaId: 3,
      nombre: 'Toma provisional',
      tipo: TipoPunto.linea,
      instrumentado: false,
    ),
    PuntoMuestreo(
      id: 6,
      organizacionId: 1,
      zonaId: 4,
      nombre: 'Salida de filtros',
      tipo: TipoPunto.tratamiento,
      instrumentado: true,
    ),
    PuntoMuestreo(
      id: 7,
      organizacionId: 1,
      zonaId: 4,
      nombre: 'Comedor de personal',
      tipo: TipoPunto.consumo,
      instrumentado: false,
    ),
  ];

  static List<Dispositivo> dispositivos() {
    final hoy = DateTime.now();
    return [
      Dispositivo(
        id: 1,
        puntoId: 1,
        identificador: 'ESP32-POZO1',
        tipoSensor: 'pH / turbidez / TDS / temperatura',
        ultimaCalibracion: hoy.subtract(const Duration(days: 21)),
      ),
      Dispositivo(
        id: 2,
        puntoId: 2,
        identificador: 'ESP32-TANQN',
        tipoSensor: 'pH / turbidez / TDS / temperatura',
        ultimaCalibracion: hoy.subtract(const Duration(days: 64)),
      ),
      Dispositivo(
        id: 3,
        puntoId: 3,
        identificador: 'ESP32-POZO2',
        tipoSensor: 'pH / turbidez / TDS / temperatura',
        ultimaCalibracion: hoy.subtract(const Duration(days: 118)),
      ),
      Dispositivo(
        id: 4,
        puntoId: 6,
        identificador: 'ESP32-FILTR',
        tipoSensor: 'pH / turbidez / TDS / temperatura',
        ultimaCalibracion: hoy.subtract(const Duration(days: 9)),
      ),
    ];
  }

  static List<Muestra> muestras(MotorEvaluacion motor) {
    final azar = Random(20260821);
    final ahora = DateTime.now();
    final resultado = <Muestra>[];
    var id = 1;

    const sesgos = <int, List<double>>{
      1: [7.2, 0.8, 0.55, 320, 9],
      2: [7.1, 1.1, 0.42, 350, 11],
      3: [6.9, 1.6, 0.30, 430, 18],
      4: [6.7, 2.4, 0.16, 540, 34],
      5: [6.4, 3.3, 0.10, 690, 46],
      6: [7.4, 0.3, 0.72, 260, 4],
      7: [7.3, 0.6, 0.58, 300, 6],
    };

    const riesgoFecal = <int, double>{
      1: 0.03,
      2: 0.05,
      3: 0.08,
      4: 0.15,
      5: 0.28,
      6: 0.0,
      7: 0.02,
    };

    for (final punto in puntos) {
      final base = sesgos[punto.id]!;
      for (var semana = 5; semana >= 0; semana--) {
        for (var toma = 0; toma < 2; toma++) {
          final fecha = ahora.subtract(
            Duration(days: semana * 7 + toma * 3, hours: azar.nextInt(9) + 6),
          );
          double ruido(double amplitud) => (azar.nextDouble() - 0.5) * amplitud;

          final coliformes = azar.nextDouble() < riesgoFecal[punto.id]!
              ? (azar.nextInt(4) + 1).toDouble()
              : 0.0;

          final valores = <int, double>{
            1: _redondear(base[0] + ruido(0.9), 2),
            2: _redondear(max(0, base[1] + ruido(1.6)), 2),
            3: _redondear(max(0, base[2] + ruido(0.28)), 2),
            4: _redondear(max(0, base[3] + ruido(190)), 0),
            5: _redondear(max(0, base[4] + ruido(16)), 1),
            6: coliformes,
            7: _redondear(22 + ruido(7), 1),
          };

          final origenes = <int, ViaCaptura>{
            for (final p in parametros)
              p.id: punto.instrumentado ? p.viaCaptura : ViaCaptura.manual,
          };

          final evaluacion = motor.evaluarMuestra(valores, origenes: origenes);

          resultado.add(
            Muestra(
              id: id++,
              puntoId: punto.id,
              usuarioId: usuarios[azar.nextInt(2)].id,
              fechaHora: fecha,
              latitudCaptura: punto.latitud,
              longitudCaptura: punto.longitud,
              clasificacionGlobal: evaluacion.clasificacion,
              mediciones: evaluacion.mediciones,
              parametroLimitanteId: evaluacion.parametroLimitanteId,
              sincronizada: true,
              fechaSincronizacion: fecha.add(const Duration(minutes: 4)),
            ),
          );
        }
      }
    }

    resultado.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    return resultado;
  }

  static double _redondear(double v, int decimales) {
    final f = pow(10, decimales);
    return (v * f).round() / f;
  }
}
