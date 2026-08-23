import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/modelos.dart';

class InsigniaClasificacion extends StatelessWidget {
  const InsigniaClasificacion(this.clasificacion, {super.key, this.compacta = false});

  final Clasificacion clasificacion;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final color = Tema.color(clasificacion);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? 8 : 10,
        vertical: compacta ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Tema.icono(clasificacion), size: compacta ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            clasificacion.etiqueta,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compacta ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class TarjetaIndicador extends StatelessWidget {
  const TarjetaIndicador({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.detalle,
  });

  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icono, size: 17, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 4),
              Text(
                detalle!,
                style: const TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Tema.azulOscuro,
              ),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

class SinDatos extends StatelessWidget {
  const SinDatos({super.key, required this.mensaje, this.icono = Icons.inbox_rounded});

  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icono, size: 44, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class FilaMedicion extends StatelessWidget {
  const FilaMedicion({
    super.key,
    required this.parametro,
    required this.medicion,
    this.esLimitante = false,
  });

  final Parametro parametro;
  final Medicion medicion;
  final bool esLimitante;

  @override
  Widget build(BuildContext context) {
    final color = Tema.color(medicion.clasificacion);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: esLimitante ? color.withValues(alpha: 0.07) : null,
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        parametro.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (esLimitante) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIMITANTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Norma ${parametro.rangoLegible}  -  '
                  '${medicion.origen.etiqueta}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formato.numero(medicion.valor),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                parametro.unidad,
                style: const TextStyle(fontSize: 10.5, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
