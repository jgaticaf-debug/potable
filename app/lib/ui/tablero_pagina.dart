import 'package:flutter/material.dart';

import '../core/responsivo.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'detalle_punto_pagina.dart';
import 'widgets/comunes.dart';

class TableroPagina extends StatelessWidget {
  const TableroPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    if (estado.cargando && estado.muestras.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final resumen = estado.resumenClasificacion;
    final pendientes = estado.pendientes.length;

    return RefreshIndicator(
      onRefresh: estado.cargarCatalogo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _Encabezado(estado: estado),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, limites) {
              final indicadores = <Widget>[
              TarjetaIndicador(
                titulo: 'Muestras conformes',
                valor: Formato.porcentaje(estado.conformidadGlobal),
                icono: Icons.verified_rounded,
                color: Tema.verde,
                detalle: '${resumen[Clasificacion.apto]} de '
                    '${estado.muestras.length} muestras',
              ),
              TarjetaIndicador(
                titulo: 'Alertas abiertas',
                valor: '${estado.alertasAbiertas}',
                icono: Icons.notifications_active_rounded,
                color: Tema.ambar,
                detalle:
                    '${resumen[Clasificacion.incumplimiento]} incumplimientos',
              ),
              TarjetaIndicador(
                titulo: 'Puntos monitoreados',
                valor: '${estado.puntos.length}',
                icono: Icons.place_rounded,
                color: Tema.azul,
                detalle:
                    '${estado.puntos.where((p) => p.instrumentado).length} '
                    'instrumentados',
              ),
              TarjetaIndicador(
                titulo: 'Cola de sincronizacion',
                valor: '$pendientes',
                icono: Icons.cloud_upload_rounded,
                color: pendientes == 0 ? Tema.verde : Tema.ambar,
                detalle: pendientes == 0
                    ? 'Todo enviado al servidor'
                    : 'Muestras en el dispositivo',
              ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: indicadores.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsivo.columnas(limites.maxWidth),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent:
                      MediaQuery.textScalerOf(context).scale(Responsivo.altoTarjeta),
                ),
                itemBuilder: (context, i) => indicadores[i],
              );
            },
          ),
          const SizedBox(height: 22),

          const TituloSeccion('Estado actual por punto de muestreo'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < estado.puntos.length; i++) ...[
                  _FilaPunto(estado: estado, punto: estado.puntos[i]),
                  if (i < estado.puntos.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          const TituloSeccion('Comparacion entre zonas'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Porcentaje de muestras conformes en las ultimas seis '
                    'semanas.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  for (final zona in estado.zonasConPuntos)
                    _BarraZona(
                      zona: zona.nombre,
                      muestras: estado.muestrasDeZona(zona.id),
                    ),
                  if (estado.zonasConPuntos.isEmpty)
                    const SinDatos(
                      mensaje: 'Aun no hay zonas con puntos asignados. '
                          'Cree una desde Administracion.',
                      icono: Icons.dashboard_customize_outlined,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    final u = estado.usuario!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Tema.azulOscuro, Tema.azul],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              u.iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${u.rol.etiqueta}  -  ${estado.organizacion?.nombre ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPunto extends StatelessWidget {
  const _FilaPunto({required this.estado, required this.punto});

  final EstadoApp estado;
  final PuntoMuestreo punto;

  @override
  Widget build(BuildContext context) {
    final ultima = estado.ultimaMuestraDe(punto.id);
    final clasificacion = ultima?.clasificacionGlobal ?? Clasificacion.apto;
    final limitante = ultima?.parametroLimitanteId == null
        ? null
        : estado.parametroPorId(ultima!.parametroLimitanteId!);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetallePuntoPagina(estado: estado, punto: punto),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Tema.color(clasificacion),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    punto.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ultima == null
                        ? '${estado.nombreZonaDe(punto)}  -  sin lecturas'
                        : '${estado.nombreZonaDe(punto)}  -  '
                            '${Formato.relativo(ultima.fechaHora)}'
                            '${limitante == null ? '' : '  -  ${limitante.nombre}'}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InsigniaClasificacion(clasificacion, compacta: true),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _BarraZona extends StatelessWidget {
  const _BarraZona({required this.zona, required this.muestras});

  final String zona;
  final List<Muestra> muestras;

  @override
  Widget build(BuildContext context) {
    final pct = MotorEvaluacion.porcentajeConformidad(muestras);
    final color = pct >= 85
        ? Tema.verde
        : pct >= 60
            ? Tema.ambar
            : Tema.rojo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  zona,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${Formato.porcentaje(pct)}  (${muestras.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
