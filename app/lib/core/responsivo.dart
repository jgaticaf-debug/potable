import 'package:flutter/material.dart';

class Responsivo {
  const Responsivo._();

  static const compacto = 600.0;

  static const mediano = 1024.0;

  static const anchoContenido = 720.0;

  static bool esCompacto(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compacto;

  static bool esAmplio(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediano;

  // Alto fijo, no razon de aspecto: con childAspectRatio la tarjeta se
  // estiraba a lo alto en horizontal y ocupaba media pantalla.
  static const altoTarjeta = 150.0;

  static int columnas(double ancho) {
    if (ancho >= mediano) return 4;
    if (ancho >= compacto) return 3;
    return 2;
  }
}

class ContenidoCentrado extends StatelessWidget {
  const ContenidoCentrado({
    super.key,
    required this.child,
    this.maxAncho = Responsivo.anchoContenido,
  });

  final Widget child;
  final double maxAncho;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxAncho),
        child: child,
      ),
    );
  }
}

class FilaDesplazable extends StatelessWidget {
  const FilaDesplazable({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
