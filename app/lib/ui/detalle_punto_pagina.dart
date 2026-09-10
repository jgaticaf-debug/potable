import 'package:flutter/material.dart';

import '../core/responsivo.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'detalle_muestra_pagina.dart';
import 'widgets/comunes.dart';
import 'widgets/grafica_serie.dart';

class DetallePuntoPagina extends StatefulWidget {
  const DetallePuntoPagina({
    super.key,
    required this.estado,
    required this.punto,
  });

  final EstadoApp estado;
  final PuntoMuestreo punto;

  @override
  State<DetallePuntoPagina> createState() => _DetallePuntoPaginaState();
}

class _DetallePuntoPaginaState extends State<DetallePuntoPagina> {
  int? _parametroSeleccionado;

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final punto = widget.punto;

    if (estado.parametros.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(punto.nombre)),
        body: const SinDatos(
          mensaje: 'El catalogo de parametros aun no esta disponible.',
          icono: Icons.hourglass_empty_rounded,
        ),
      );
    }

    final muestras = estado.muestrasDe(punto.id);
    final ultima = muestras.isEmpty ? null : muestras.first;
    final parametro = estado.parametros.firstWhere(
      (p) => p.id == _parametroSeleccionado,
      orElse: () => estado.parametros.first,
    );
    final dispositivos = estado.dispositivosDe(punto.id);

    final serie = <PuntoSerie>[
      for (final m in muestras.reversed)
        if (m.medicionDe(parametro.id) != null)
          PuntoSerie(
            m.fechaHora,
            m.medicionDe(parametro.id)!.valor,
            m.medicionDe(parametro.id)!.clasificacion,
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(punto.nombre)),
      body: Refrescable(
        estado: estado,
        child: ContenidoCentrado(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estado.nombreZonaDe(punto),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              punto.tipo.etiqueta,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ultima != null)
                        InsigniaClasificacion(ultima.clasificacionGlobal),
                    ],
                  ),
                  const Divider(height: 22),
                  if (punto.tieneCoordenadas)
                    _linea(
                      Icons.my_location_rounded,
                      Formato.coordenada(punto.latitud!, punto.longitud!),
                    ),
                  _linea(
                    punto.instrumentado
                        ? Icons.sensors_rounded
                        : Icons.edit_note_rounded,
                    dispositivos.isEmpty
                        ? 'Captura manual (sin instrumentacion)'
                        : '${dispositivos.first.identificador}  -  '
                            '${dispositivos.first.tipoSensor}',
                  ),
                  if (dispositivos.isNotEmpty)
                    _linea(
                      Icons.tune_rounded,
                      'Ultima calibracion: '
                      '${Formato.fecha(dispositivos.first.ultimaCalibracion)}',
                      alerta: dispositivos.first.calibracionVencida,
                    ),
                  _linea(
                    Icons.insights_rounded,
                    'Conformidad: '
                    '${Formato.porcentaje(MotorEvaluacion.porcentajeConformidad(muestras))}'
                    '  en ${muestras.length} muestras',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const TituloSeccion('Tendencia por parametro'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(34),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in estado.parametros)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                p.nombre,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: p.id == _parametroSeleccionado,
                              onSelected: (_) => setState(
                                () => _parametroSeleccionado = p.id,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    parametro.descripcion,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GraficaSerie(puntos: serie, parametro: parametro),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _leyenda(Tema.verde, 'Apto'),
                      _leyenda(Tema.ambar, 'En riesgo'),
                      _leyenda(Tema.rojo, 'Incumplimiento'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          TituloSeccion('Historial (${muestras.length})'),
          if (muestras.isEmpty)
            const Card(
              child: SinDatos(mensaje: 'Este punto aun no tiene muestras.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < muestras.length; i++) ...[
                    _FilaMuestra(estado: estado, muestra: muestras[i]),
                    if (i < muestras.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _linea(IconData icono, String texto, {bool alerta = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 15, color: alerta ? Tema.ambar : Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alerta ? '$texto  (vencida)' : texto,
              style: TextStyle(
                fontSize: 12,
                color: alerta ? Tema.ambar : Colors.black87,
                fontWeight: alerta ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FilaMuestra extends StatelessWidget {
  const _FilaMuestra({required this.estado, required this.muestra});

  final EstadoApp estado;
  final Muestra muestra;

  @override
  Widget build(BuildContext context) {
    final limitante = muestra.parametroLimitanteId == null
        ? null
        : estado.parametroPorId(muestra.parametroLimitanteId!);

    return ListTile(
      dense: true,
      leading: Icon(
        Tema.icono(muestra.clasificacionGlobal),
        color: Tema.color(muestra.clasificacionGlobal),
        size: 20,
      ),
      title: Text(
        Formato.fechaHora(muestra.fechaHora),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        limitante == null
            ? 'Dentro de norma'
            : 'Limitante: ${limitante.nombre}',
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!muestra.sincronizada)
            const Icon(Icons.cloud_off_rounded, size: 15, color: Tema.ambar),
          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleMuestraPagina(estado: estado, muestra: muestra),
        ),
      ),
    );
  }
}
