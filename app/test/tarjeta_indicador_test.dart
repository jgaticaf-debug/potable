import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potable/core/responsivo.dart';
import 'package:potable/core/tema.dart';
import 'package:potable/ui/widgets/comunes.dart';

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required double ancho,
    required String titulo,
    required String detalle,
    double escalaTexto = 1.0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escalaTexto)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: ancho,
                height: Responsivo.altoTarjeta * escalaTexto,
                child: TarjetaIndicador(
                  titulo: titulo,
                  valor: '100.0 %',
                  icono: Icons.verified_rounded,
                  color: Tema.verde,
                  detalle: detalle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('cabe en la celda mas angosta de dos columnas', (tester) async {
    await montar(
      tester,
      ancho: 138,
      titulo: 'Cola de sincronizacion',
      detalle: 'Muestras en el dispositivo',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe con el titulo y el detalle mas largos', (tester) async {
    await montar(
      tester,
      ancho: 138,
      titulo: 'Porcentaje de muestras conformes por zona',
      detalle: '1234 de 5678 muestras registradas en el periodo',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe con el tamano de letra grande de accesibilidad',
      (tester) async {
    await montar(
      tester,
      ancho: 138,
      titulo: 'Cola de sincronizacion',
      detalle: 'Muestras en el dispositivo',
      escalaTexto: 1.5,
    );
    expect(tester.takeException(), isNull);
  });

  test('el alto de la tarjeta no depende del ancho disponible', () {
    expect(Responsivo.altoTarjeta, isA<double>());
    expect(Responsivo.columnas(360), 2);
    expect(Responsivo.columnas(700), 3);
    expect(Responsivo.columnas(1200), 4);
  });
}
