import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'widgets/comunes.dart';

class NormaPagina extends StatelessWidget {
  const NormaPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tema.azul.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel_rounded, color: Tema.azul, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Los limites provienen de la norma COGUANOR NTG 29001. La '
                  'banda de alerta es el margen operativo interno: permite '
                  'reaccionar antes de caer en incumplimiento.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const TituloSeccion('Parametros configurados'),
        for (final p in estado.parametros)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TarjetaParametro(parametro: p),
          ),
        const SizedBox(height: 10),
        const TituloSeccion('Dispositivos registrados'),
        Card(
          child: Column(
            children: [
              for (final d in estado.dispositivos)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.memory_rounded,
                    size: 20,
                    color: d.calibracionVencida ? Tema.ambar : Tema.azul,
                  ),
                  title: Text(
                    d.identificador,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${estado.puntoPorId(d.puntoId)?.nombre ?? ''}\n'
                    '${d.tipoSensor}',
                    style: const TextStyle(fontSize: 11.5, height: 1.35),
                  ),
                  isThreeLine: true,
                  trailing: d.calibracionVencida
                      ? const Chip(
                          label: Text(
                            'Calibrar',
                            style: TextStyle(fontSize: 10, color: Tema.ambar),
                          ),
                          backgroundColor: Color(0x22D98A0B),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaParametro extends StatelessWidget {
  const _TarjetaParametro({required this.parametro});

  final Parametro parametro;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    parametro.nombre,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (parametro.critico)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Tema.rojo.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CRITICO',
                      style: TextStyle(
                        fontSize: 9,
                        color: Tema.rojo,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  parametro.viaCaptura == ViaCaptura.sensor
                      ? Icons.sensors_rounded
                      : Icons.edit_note_rounded,
                  size: 16,
                  color: Colors.black38,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              parametro.descripcion,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _bloque('Limite normado', parametro.rangoLegible, Tema.verde),
                const SizedBox(width: 8),
                _bloque(
                  'Banda de alerta',
                  parametro.bandaAlertaLegible,
                  Tema.ambar,
                ),
                const SizedBox(width: 8),
                _bloque('Captura', parametro.viaCaptura.etiqueta, Tema.azul),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloque(String etiqueta, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: const TextStyle(fontSize: 9.5, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              valor,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
