import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'detalle_muestra_pagina.dart';
import 'widgets/comunes.dart';

class HistorialPagina extends StatefulWidget {
  const HistorialPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<HistorialPagina> createState() => _HistorialPaginaState();
}

class _HistorialPaginaState extends State<HistorialPagina> {
  int? _puntoId;
  Clasificacion? _clasificacion;

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final filtradas = estado.muestras.where((m) {
      if (_puntoId != null && m.puntoId != _puntoId) return false;
      if (_clasificacion != null && m.clasificacionGlobal != _clasificacion) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(34),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip(
                      'Todos los puntos',
                      _puntoId == null,
                      () => setState(() => _puntoId = null),
                    ),
                    for (final p in estado.puntos)
                      _chip(
                        p.nombre,
                        _puntoId == p.id,
                        () => setState(() => _puntoId = p.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(34),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip(
                      'Toda clasificacion',
                      _clasificacion == null,
                      () => setState(() => _clasificacion = null),
                    ),
                    for (final c in Clasificacion.values)
                      _chip(
                        c.etiqueta,
                        _clasificacion == c,
                        () => setState(() => _clasificacion = c),
                        color: Tema.color(c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Refrescable(
            estado: estado,
            child: filtradas.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      SinDatos(
                        mensaje:
                            'Ninguna muestra coincide con el filtro aplicado.',
                        icono: Icons.filter_alt_off_rounded,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _Tarjeta(estado: estado, muestra: filtradas[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback onTap, {Color? color}) {
    final c = color ?? Tema.azul;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(texto, style: const TextStyle(fontSize: 11.5)),
        selected: activo,
        selectedColor: c.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          color: activo ? c : Colors.black87,
          fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.estado, required this.muestra});

  final EstadoApp estado;
  final Muestra muestra;

  @override
  Widget build(BuildContext context) {
    final punto = estado.puntoPorId(muestra.puntoId);
    final limitante = muestra.parametroLimitanteId == null
        ? null
        : estado.parametroPorId(muestra.parametroLimitanteId!);
    final color = Tema.color(muestra.clasificacionGlobal);
    final parcial = estado.motor
        .criticosFaltantes(muestra.mediciones.map((m) => m.parametroId))
        .isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DetalleMuestraPagina(estado: estado, muestra: muestra),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              punto?.nombre ?? 'Punto desconocido',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          InsigniaClasificacion(
                            muestra.clasificacionGlobal,
                            compacta: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '#${muestra.id}  -  '
                        '${Formato.fechaHora(muestra.fechaHora)}'
                        '${parcial ? '  -  parcial' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: parcial ? Tema.ambar : Colors.black54,
                          fontWeight: parcial ? FontWeight.w600 : null,
                        ),
                      ),
                      if (limitante != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Limitante: ${limitante.nombre} = '
                          '${Formato.numero(muestra.medicionDe(limitante.id)!.valor)} '
                          '${limitante.unidad}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (!muestra.sincronizada) ...[
                        const SizedBox(height: 5),
                        const Row(
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 12, color: Tema.ambar),
                            SizedBox(width: 5),
                            Text(
                              'Pendiente de sincronizar',
                              style:
                                  TextStyle(fontSize: 11, color: Tema.ambar),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
