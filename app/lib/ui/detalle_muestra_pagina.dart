import 'package:flutter/material.dart';

import '../core/responsivo.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'widgets/comunes.dart';

class DetalleMuestraPagina extends StatelessWidget {
  const DetalleMuestraPagina({
    super.key,
    required this.estado,
    required this.muestra,
    this.recienGuardada = false,
  });

  final EstadoApp estado;
  final Muestra muestra;
  final bool recienGuardada;

  @override
  Widget build(BuildContext context) {
    final punto = estado.puntoPorId(muestra.puntoId);
    final usuario = estado.usuarioPorId(muestra.usuarioId);
    final color = Tema.color(muestra.clasificacionGlobal);
    final faltantes = estado.motor.criticosFaltantes(
      muestra.mediciones.map((m) => m.parametroId),
    );
    final limitante = muestra.parametroLimitanteId == null
        ? null
        : estado.parametroPorId(muestra.parametroLimitanteId!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Muestra #${muestra.id}'),
      ),
      body: ContenidoCentrado(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (recienGuardada)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Tema.verde.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Tema.verde, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Muestra guardada en el dispositivo y encolada para '
                      'sincronizacion.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Tema.icono(muestra.clasificacionGlobal),
                    size: 42, color: color),
                const SizedBox(height: 8),
                Text(
                  muestra.clasificacionGlobal.etiqueta.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  limitante == null
                      ? faltantes.isEmpty
                          ? 'Todos los parametros dentro de la norma COGUANOR '
                              'NTG 29001.'
                          : 'Dentro de norma en los parametros medidos.'
                      : 'Determinado por ${limitante.nombre}: norma '
                          '${limitante.rangoLegible}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
                if (faltantes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x14D98A0B),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'EVALUACION PARCIAL - '
                          '${muestra.mediciones.length} de '
                          '${estado.motor.totalParametros} parametros',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB8770A),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Falta ${faltantes.map((p) => p.nombre).join(', ')}, '
                          'que la norma trata como critico. No se puede '
                          'declarar apta hasta tener ese resultado.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          const TituloSeccion('Trazabilidad'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _Dato('Punto', punto?.nombre ?? 'Desconocido'),
                  _Dato(
                    'Zona',
                    punto == null ? '-' : estado.nombreZonaDe(punto),
                  ),
                  _Dato('Fecha y hora', Formato.fechaHora(muestra.fechaHora)),
                  _Dato('Registrado por', usuario?.nombre ?? '-'),
                  if (muestra.latitudCaptura != null &&
                      muestra.longitudCaptura != null)
                    _Dato(
                      'Coordenadas de captura',
                      Formato.coordenada(
                        muestra.latitudCaptura!,
                        muestra.longitudCaptura!,
                      ),
                    ),
                  _Dato(
                    'Sincronizacion',
                    muestra.sincronizada
                        ? 'Enviada ${Formato.fechaHora(muestra.fechaSincronizacion!)}'
                        : 'Pendiente en cola local',
                    color: muestra.sincronizada ? null : Tema.ambar,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const TituloSeccion('Mediciones'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final m in muestra.mediciones)
                  if (estado.parametroPorId(m.parametroId) != null)
                    FilaMedicion(
                      parametro: estado.parametroPorId(m.parametroId)!,
                      medicion: m,
                      esLimitante: m.parametroId == muestra.parametroLimitanteId,
                    ),
              ],
            ),
          ),

          if (muestra.observaciones.isNotEmpty) ...[
            const SizedBox(height: 20),
            const TituloSeccion('Observaciones'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  muestra.observaciones,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.color});

  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
