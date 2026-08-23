import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/modelos.dart';

class PuntoSerie {
  const PuntoSerie(this.fecha, this.valor, this.clasificacion);
  final DateTime fecha;
  final double valor;
  final Clasificacion clasificacion;
}

class GraficaSerie extends StatelessWidget {
  const GraficaSerie({
    super.key,
    required this.puntos,
    required this.parametro,
    this.altura = 170,
  });

  final List<PuntoSerie> puntos;
  final Parametro parametro;
  final double altura;

  @override
  Widget build(BuildContext context) {
    if (puntos.length < 2) {
      return SizedBox(
        height: altura,
        child: const Center(
          child: Text(
            'Se requieren al menos dos lecturas para trazar la tendencia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12.5),
          ),
        ),
      );
    }

    return SizedBox(
      height: altura,
      child: CustomPaint(
        painter: _PintorSerie(puntos: puntos, parametro: parametro),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PintorSerie extends CustomPainter {
  _PintorSerie({required this.puntos, required this.parametro});

  final List<PuntoSerie> puntos;
  final Parametro parametro;

  static const _margenIzq = 44.0;
  static const _margenInf = 20.0;
  static const _margenSup = 10.0;
  static const _margenDer = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final areaIzq = _margenIzq;
    final areaDer = size.width - _margenDer;
    final areaSup = _margenSup;
    final areaInf = size.height - _margenInf;
    final ancho = areaDer - areaIzq;
    final alto = areaInf - areaSup;
    if (ancho <= 0 || alto <= 0) return;

    final valores = puntos.map((p) => p.valor).toList();
    var minY = valores.reduce((a, b) => a < b ? a : b);
    var maxY = valores.reduce((a, b) => a > b ? a : b);
    if (parametro.limiteMin != null) {
      minY = minY < parametro.limiteMin! ? minY : parametro.limiteMin!;
    }
    if (parametro.limiteMax != null) {
      maxY = maxY > parametro.limiteMax! ? maxY : parametro.limiteMax!;
    }
    if ((maxY - minY).abs() < 1e-9) {
      minY -= 1;
      maxY += 1;
    }
    final holgura = (maxY - minY) * 0.12;
    minY -= holgura;
    maxY += holgura;

    double x(int i) => areaIzq + ancho * (i / (puntos.length - 1));
    double y(double v) => areaInf - alto * ((v - minY) / (maxY - minY));

    if (parametro.limiteMin != null || parametro.limiteMax != null) {
      final arriba = y(parametro.limiteMax ?? maxY);
      final abajo = y(parametro.limiteMin ?? minY);
      canvas.drawRect(
        Rect.fromLTRB(areaIzq, arriba, areaDer, abajo),
        Paint()..color = Tema.verde.withValues(alpha: 0.08),
      );
      final linea = Paint()
        ..color = Tema.verde.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(areaIzq, arriba), Offset(areaDer, arriba), linea);
      canvas.drawLine(Offset(areaIzq, abajo), Offset(areaDer, abajo), linea);
    }

    final ejes = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(areaIzq, areaInf), Offset(areaDer, areaInf), ejes);

    _texto(canvas, Formato.numero(maxY, maxDecimales: 1),
        Offset(0, areaSup - 5), 9.5);
    _texto(canvas, Formato.numero(minY, maxDecimales: 1),
        Offset(0, areaInf - 12), 9.5);

    final ruta = Path();
    for (var i = 0; i < puntos.length; i++) {
      final p = Offset(x(i), y(puntos[i].valor));
      if (i == 0) {
        ruta.moveTo(p.dx, p.dy);
      } else {
        ruta.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      ruta,
      Paint()
        ..color = Tema.azul
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < puntos.length; i++) {
      final centro = Offset(x(i), y(puntos[i].valor));
      canvas.drawCircle(centro, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(
        centro,
        3.2,
        Paint()..color = Tema.color(puntos[i].clasificacion),
      );
    }

    _texto(canvas, Formato.fecha(puntos.first.fecha),
        Offset(areaIzq, areaInf + 4), 9.5);
    _texto(
      canvas,
      Formato.fecha(puntos.last.fecha),
      Offset(areaDer - 58, areaInf + 4),
      9.5,
    );
  }

  void _texto(Canvas canvas, String texto, Offset offset, double tam) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: Colors.black54, fontSize: tam),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_PintorSerie old) =>
      old.puntos != puntos || old.parametro != parametro;
}
