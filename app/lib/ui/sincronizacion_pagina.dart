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

    return Refrescable(
      estado: estado,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                if (estado.proximoReintento != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Tema.azul.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.autorenew_rounded,
                            size: 16, color: Tema.azul),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se reintentara solo a las '
                            '${Formato.hora(estado.proximoReintento!)}. '
                            'No hace falta que espere aqui.',
                            style: const TextStyle(fontSize: 11.5),
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

        _SeccionAlertas(estado: estado),
        ],
      ),
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

class _SeccionAlertas extends StatefulWidget {
  const _SeccionAlertas({required this.estado});

  final EstadoApp estado;

  @override
  State<_SeccionAlertas> createState() => _SeccionAlertasState();
}

class _SeccionAlertasState extends State<_SeccionAlertas> {
  static const _tope = 15;

  String? _filtro;
  bool _atendiendo = false;

  EstadoApp get estado => widget.estado;

  List<Alerta> get _abiertas =>
      estado.alertas.where((a) => !a.atendida).toList();

  List<Alerta> get _visibles => _filtro == null
      ? _abiertas
      : _abiertas.where((a) => a.tipo == _filtro).toList();

  int _cuantas(String tipo) =>
      _abiertas.where((a) => a.tipo == tipo).length;

  Future<void> _atenderVisibles() async {
    final objetivo = _visibles;
    if (objetivo.isEmpty) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Marcar como atendidas'),
        content: Text(
          'Se van a marcar ${objetivo.length} alerta(s) como atendidas a su '
          'nombre, y cada una queda registrada en la bitacora.\n\n'
          'Hagalo solo si de verdad las reviso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Marcar todas'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() => _atendiendo = true);
    final hechas = await estado.atenderAlertas([
      for (final a in objetivo) a.id,
    ]);
    if (!mounted) return;
    setState(() => _atendiendo = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hechas == objetivo.length
                ? '$hechas alerta(s) marcadas como atendidas.'
                : 'Se marcaron $hechas de ${objetivo.length}. '
                    'Intente de nuevo con las que quedaron.',
          ),
          backgroundColor: hechas == objetivo.length ? Tema.verde : Tema.ambar,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _chip(String texto, String? tipo, Color color) {
    final activo = _filtro == tipo;
    final cuantas = tipo == null ? _abiertas.length : _cuantas(tipo);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: activo,
        onSelected: (_) => setState(() => _filtro = activo ? null : tipo),
        label: Text('$texto ($cuantas)'),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
          color: activo ? Colors.white : color,
        ),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.10),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    final mostradas = visibles.take(_tope).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion('Alertas sin atender (${_abiertas.length})'),

        if (_abiertas.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todas', null, Tema.azul),
                _chip(
                  'Incumple',
                  Clasificacion.incumplimiento.etiqueta,
                  Tema.rojo,
                ),
                _chip('En riesgo', Clasificacion.riesgo.etiqueta, Tema.ambar),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        if (visibles.isEmpty)
          Card(
            child: SinDatos(
              mensaje: _abiertas.isEmpty
                  ? 'Ninguna alerta abierta.'
                  : 'Ninguna alerta de ese tipo.',
              icono: Icons.notifications_off_rounded,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final a in mostradas)
                  _FilaAlerta(estado: estado, alerta: a),
                if (visibles.length > mostradas.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text(
                      'y ${visibles.length - mostradas.length} mas...',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                const Divider(height: 1),
                TextButton.icon(
                  onPressed: _atendiendo ? null : _atenderVisibles,
                  icon: _atendiendo
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all_rounded, size: 19),
                  label: Text(
                    _atendiendo
                        ? 'Marcando...'
                        : _filtro == null
                            ? 'Marcar las ${visibles.length} como atendidas'
                            : 'Marcar estas ${visibles.length} como atendidas',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
