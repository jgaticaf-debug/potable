import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../datos/estado_app.dart';
import '../../dominio/modelos.dart';
import 'comunes.dart';

/// Selector de punto de muestreo con busqueda.
///
/// Una empresa con varias plantaciones acumula decenas de puntos, y un
/// desplegable comun obliga a recorrerlos todos. Este abre una hoja con
/// buscador y la lista agrupada por zona.
Future<int?> mostrarSelectorPunto(
  BuildContext context, {
  required EstadoApp estado,
  int? seleccionado,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HojaSelector(
      estado: estado,
      seleccionado: seleccionado,
    ),
  );
}

class _HojaSelector extends StatefulWidget {
  const _HojaSelector({required this.estado, this.seleccionado});

  final EstadoApp estado;
  final int? seleccionado;

  @override
  State<_HojaSelector> createState() => _HojaSelectorState();
}

class _HojaSelectorState extends State<_HojaSelector> {
  final _busqueda = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Normaliza para que "plantacion" encuentre "Plantación".
  static String _normalizar(String s) {
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    var r = s.toLowerCase();
    acentos.forEach((con, sin) => r = r.replaceAll(con, sin));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final todos = estado.puntosDisponibles;
    final termino = _normalizar(_filtro.trim());

    final visibles = termino.isEmpty
        ? todos
        : todos.where((p) {
            final texto = _normalizar(
              '${estado.nombreZonaDe(p)} ${p.nombre} ${p.tipo.etiqueta}',
            );
            return texto.contains(termino);
          }).toList();

    // Agrupadas por zona, conservando el orden de puntosDisponibles.
    final porZona = <String, List<PuntoMuestreo>>{};
    for (final p in visibles) {
      (porZona[estado.nombreZonaDe(p)] ??= []).add(p);
    }

    final alto = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: alto * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Punto de muestreo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${visibles.length} de ${todos.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _busqueda,
                    autofocus: todos.length > 8,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _filtro = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por zona, punto o tipo',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _filtro.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _busqueda.clear();
                                setState(() => _filtro = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: visibles.isEmpty
                  ? SinDatos(
                      mensaje: todos.isEmpty
                          ? 'No hay puntos registrados. Cree uno desde '
                              'Administracion.'
                          : 'Ningun punto coincide con "$_filtro".',
                      icono: Icons.search_off_rounded,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        for (final entrada in porZona.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                            child: Text(
                              entrada.key.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Tema.azul,
                              ),
                            ),
                          ),
                          for (final p in entrada.value)
                            _FilaPunto(
                              punto: p,
                              activo: p.id == widget.seleccionado,
                              ultimaClasificacion:
                                  estado.ultimaMuestraDe(p.id)
                                      ?.clasificacionGlobal,
                              onTap: () => Navigator.of(context).pop(p.id),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaPunto extends StatelessWidget {
  const _FilaPunto({
    required this.punto,
    required this.activo,
    required this.onTap,
    this.ultimaClasificacion,
  });

  final PuntoMuestreo punto;
  final bool activo;
  final VoidCallback onTap;
  final Clasificacion? ultimaClasificacion;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: activo ? Tema.azul.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(
              punto.instrumentado
                  ? Icons.sensors_rounded
                  : Icons.edit_note_rounded,
              size: 19,
              color: punto.instrumentado ? Tema.cian : Colors.black38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    punto.nombre,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                      color: activo ? Tema.azul : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    punto.tipo.etiqueta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (ultimaClasificacion != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Tema.color(ultimaClasificacion!),
                  shape: BoxShape.circle,
                ),
              ),
            if (activo)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_rounded, size: 18, color: Tema.azul),
              ),
          ],
        ),
      ),
    );
  }
}
