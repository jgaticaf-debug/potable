import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'detalle_muestra_pagina.dart';
import 'widgets/comunes.dart';

class SincronizacionPagina extends StatelessWidget {
  const SincronizacionPagina({super.key, required this.estado});

  final EstadoApp estado;

  Future<void> _sincronizar(BuildContext context) async {
    final enviadas = await estado.sincronizar();
    if (!context.mounted) return;
    final mensaje = enviadas == null
        ? estado.errorSincronizacion ?? 'No se pudo sincronizar.'
        : enviadas == 0
            ? 'No habia muestras pendientes.'
            : '$enviadas muestra(s) enviadas al servidor.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: enviadas == null ? Tema.rojo : Tema.verde,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = estado.pendientes;
    final alertas = estado.alertas.where((a) => !a.atendida).take(12).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      pendientes.isEmpty
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_upload_rounded,
                      color: pendientes.isEmpty ? Tema.verde : Tema.ambar,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendientes.isEmpty
                                ? 'Todo sincronizado'
                                : '${pendientes.length} muestra(s) en cola',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Cola local en el dispositivo -> API REST',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (estado.errorSincronizacion != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Tema.rojo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 16, color: Tema.rojo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            estado.errorSincronizacion!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Tema.rojo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: estado.sincronizando
                      ? null
                      : () => _sincronizar(context),
                  icon: estado.sincronizando
                      ? const SizedBox(
                          height: 17,
                          width: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    estado.sincronizando
                        ? 'Enviando al servidor...'
                        : 'Sincronizar ahora',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        TituloSeccion('Cola pendiente (${pendientes.length})'),
        if (pendientes.isEmpty)
          const Card(
            child: SinDatos(
              mensaje: 'No hay muestras esperando envio.',
              icono: Icons.cloud_done_rounded,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final m in pendientes)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule_send_rounded,
                        color: Tema.ambar, size: 20),
                    title: Text(
                      estado.puntoPorId(m.puntoId)?.nombre ?? 'Punto',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '#${m.id}  -  ${Formato.fechaHora(m.fechaHora)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: InsigniaClasificacion(
                      m.clasificacionGlobal,
                      compacta: true,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DetalleMuestraPagina(estado: estado, muestra: m),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        TituloSeccion('Alertas sin atender (${estado.alertasAbiertas})'),
        if (alertas.isEmpty)
          const Card(
            child: SinDatos(
              mensaje: 'Ninguna alerta abierta.',
              icono: Icons.notifications_off_rounded,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final a in alertas)
                  _FilaAlerta(estado: estado, alerta: a),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaAlerta extends StatelessWidget {
  const _FilaAlerta({required this.estado, required this.alerta});

  final EstadoApp estado;
  final Alerta alerta;

  @override
  Widget build(BuildContext context) {
    final esIncumplimiento =
        alerta.tipo == Clasificacion.incumplimiento.etiqueta;
    final color = esIncumplimiento ? Tema.rojo : Tema.ambar;

    return ListTile(
      dense: true,
      leading: Icon(
        esIncumplimiento
            ? Icons.dangerous_rounded
            : Icons.warning_amber_rounded,
        color: color,
        size: 20,
      ),
      title: Text(
        estado.puntoPorId(alerta.puntoId)?.nombre ?? 'Punto',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${alerta.detalle}\n${Formato.relativo(alerta.fecha)}',
        style: const TextStyle(fontSize: 11.5, height: 1.35),
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Marcar atendida',
        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
        onPressed: () => estado.atenderAlerta(alerta.id),
      ),
    );
  }
}
