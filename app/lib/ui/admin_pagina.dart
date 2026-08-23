import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'bitacora_seccion.dart';
import 'norma_pagina.dart';
import 'widgets/comunes.dart';
import 'widgets/formularios_admin.dart';

class AdminPagina extends StatefulWidget {
  const AdminPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<AdminPagina> createState() => _AdminPaginaState();
}

class _AdminPaginaState extends State<AdminPagina> {
  int _seccion = 0;

  EstadoApp get estado => widget.estado;

  void _aviso(String mensaje, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _editarZona([Zona? zona]) async {
    final resultado = await mostrarFormularioZona(
      context,
      organizacionId: estado.organizacion?.id ?? 1,
      zona: zona,
    );
    if (resultado == null) return;

    final error = await estado.guardarZona(resultado);
    if (!mounted) return;
    _aviso(
      error ?? 'Zona ${zona == null ? 'creada' : 'actualizada'}.',
      error == null ? Tema.verde : Tema.rojo,
    );
  }

  Future<void> _borrarZona(Zona zona) async {
    final confirmado = await _confirmar(
      'Eliminar zona',
      'Se eliminara "${zona.nombre}". Esta accion no se puede deshacer.',
    );
    if (!confirmado) return;

    final error = await estado.eliminarZona(zona.id);
    if (!mounted) return;
    _aviso(error ?? 'Zona eliminada.', error == null ? Tema.verde : Tema.rojo);
  }

  Future<void> _editarPunto([PuntoMuestreo? punto]) async {
    if (estado.zonasActivas.isEmpty) {
      _aviso('Primero cree una zona.', Tema.ambar);
      return;
    }

    final resultado = await mostrarFormularioPunto(
      context,
      organizacionId: estado.organizacion?.id ?? 1,
      zonas: estado.zonasActivas,
      punto: punto,
    );
    if (resultado == null) return;

    final error = await estado.guardarPunto(resultado);
    if (!mounted) return;
    _aviso(
      error ?? 'Punto ${punto == null ? 'creado' : 'actualizado'}.',
      error == null ? Tema.verde : Tema.rojo,
    );
  }

  Future<void> _borrarPunto(PuntoMuestreo punto) async {
    final confirmado = await _confirmar(
      'Eliminar punto',
      'Se eliminara "${punto.nombre}" y sus dispositivos asociados.',
    );
    if (!confirmado) return;

    final error = await estado.eliminarPunto(punto.id);
    if (!mounted) return;
    _aviso(error ?? 'Punto eliminado.', error == null ? Tema.verde : Tema.rojo);
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Tema.rojo,
              minimumSize: const Size(90, 42),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Zonas', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.map_outlined, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Puntos', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.place_outlined, size: 16),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Norma', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.gavel_rounded, size: 16),
              ),
              ButtonSegment(
                value: 3,
                label: Text('Bitacora', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.history_edu_outlined, size: 16),
              ),
            ],
            selected: {_seccion},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _seccion = s.first),
          ),
        ),
        Expanded(
          child: switch (_seccion) {
            0 => _listaZonas(),
            1 => _listaPuntos(),
            2 => NormaPagina(estado: estado),
            _ => BitacoraSeccion(estado: estado),
          },
        ),
      ],
    );
  }

  Widget _listaZonas() {
    final zonas = estado.zonas;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            const _Explicacion(
              'Las zonas son las areas que su organizacion define: '
              'plantaciones, plantas de proceso o cualquier agrupacion '
              'propia. El tablero compara la calidad del agua entre ellas.',
            ),
            const SizedBox(height: 14),
            if (zonas.isEmpty)
              const Card(
                child: SinDatos(
                  mensaje: 'No hay zonas registradas.',
                  icono: Icons.map_outlined,
                ),
              )
            else
              for (final z in zonas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TarjetaZona(
                    zona: z,
                    puntos: estado.puntosDeZona(z.id).length,
                    instrumentados: estado
                        .puntosDeZona(z.id)
                        .where((p) => p.instrumentado)
                        .length,
                    puedeEditar: estado.puedeAdministrar,
                    onEditar: () => _editarZona(z),
                    onEliminar: () => _borrarZona(z),
                  ),
                ),
          ],
        ),
        if (estado.puedeAdministrar)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _editarZona(),
              backgroundColor: Tema.azulOscuro,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva zona'),
            ),
          ),
      ],
    );
  }

  Widget _listaPuntos() {
    final zonas = estado.zonas;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            const _Explicacion(
              'Cada punto pertenece a una zona. Marque como instrumentado '
              'aquel que tenga sensor conectado; los demas se registran de '
              'forma manual.',
            ),
            const SizedBox(height: 14),
            for (final z in zonas) ...[
              if (estado.puntosDeZona(z.id).isNotEmpty) ...[
                TituloSeccion(z.nombre),
                Card(
                  child: Column(
                    children: [
                      for (final p in estado.puntosDeZona(z.id))
                        _FilaPunto(
                          punto: p,
                          dispositivos: estado.dispositivosDe(p.id).length,
                          muestras: estado.muestrasDe(p.id).length,
                          puedeEditar: estado.puedeAdministrar,
                          onEditar: () => _editarPunto(p),
                          onEliminar: () => _borrarPunto(p),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            if (estado.puntos.isEmpty)
              const Card(
                child: SinDatos(
                  mensaje: 'No hay puntos registrados.',
                  icono: Icons.place_outlined,
                ),
              ),
          ],
        ),
        if (estado.puedeAdministrar)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _editarPunto(),
              backgroundColor: Tema.azulOscuro,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo punto'),
            ),
          ),
      ],
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Tema.azul.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 17, color: Tema.azul),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaZona extends StatelessWidget {
  const _TarjetaZona({
    required this.zona,
    required this.puntos,
    required this.instrumentados,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final Zona zona;
  final int puntos;
  final int instrumentados;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          zona.nombre,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!zona.activa) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'INACTIVA',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (zona.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      zona.descripcion,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _pastilla(
                        Icons.place_outlined,
                        '$puntos punto${puntos == 1 ? '' : 's'}',
                      ),
                      const SizedBox(width: 7),
                      _pastilla(
                        Icons.sensors_rounded,
                        '$instrumentados con sensor',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (puedeEditar)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (v) => v == 'editar' ? onEditar() : onEliminar(),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 17, color: Tema.rojo),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Tema.rojo)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _pastilla(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: Colors.black45),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FilaPunto extends StatelessWidget {
  const _FilaPunto({
    required this.punto,
    required this.dispositivos,
    required this.muestras,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final PuntoMuestreo punto;
  final int dispositivos;
  final int muestras;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        punto.instrumentado ? Icons.sensors_rounded : Icons.edit_note_rounded,
        size: 20,
        color: punto.instrumentado ? Tema.cian : Colors.black38,
      ),
      title: Text(
        punto.nombre,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${punto.tipo.etiqueta}  -  $muestras muestras'
        '${dispositivos > 0 ? '  -  $dispositivos equipo(s)' : ''}',
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: puedeEditar
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 19),
              onSelected: (v) => v == 'editar' ? onEditar() : onEliminar(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 17),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 17, color: Tema.rojo),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Tema.rojo)),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
