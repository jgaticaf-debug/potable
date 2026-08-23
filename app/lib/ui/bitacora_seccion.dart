import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../dominio/modelos.dart';
import 'widgets/comunes.dart';

/// Bitacora de auditoria: quien hizo que y cuando.
///
/// Es el respaldo documental frente a una auditoria sanitaria. La tabla solo
/// admite inserciones: ninguna pantalla edita ni borra un registro.
class BitacoraSeccion extends StatefulWidget {
  const BitacoraSeccion({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<BitacoraSeccion> createState() => _BitacoraSeccionState();
}

class _BitacoraSeccionState extends State<BitacoraSeccion> {
  String? _entidad;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await widget.estado.cargarBitacora();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final todos = widget.estado.bitacora;
    final registros = _entidad == null
        ? todos
        : todos.where((r) => r.accion.entidad == _entidad).toList();

    final entidades = <String>{for (final r in todos) r.accion.entidad}.toList()
      ..sort();

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Tema.azul.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_edu_outlined, size: 17, color: Tema.azul),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Registro de todo lo que ocurre en el sistema. No se '
                    'puede editar ni borrar: es el respaldo ante una '
                    'auditoria sanitaria.',
                    style: TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (entidades.length > 1)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Todo', _entidad == null, () {
                    setState(() => _entidad = null);
                  }),
                  for (final e in entidades)
                    _chip(_titulo(e), _entidad == e, () {
                      setState(() => _entidad = e);
                    }),
                ],
              ),
            ),
          const SizedBox(height: 6),

          if (registros.isEmpty)
            const Card(
              child: SinDatos(
                mensaje: 'Todavia no hay movimientos registrados.',
                icono: Icons.history_toggle_off_rounded,
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < registros.length; i++) ...[
                    _Fila(registro: registros[i]),
                    if (i < registros.length - 1)
                      Divider(
                        height: 1,
                        indent: 46,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _titulo(String entidad) =>
      entidad[0].toUpperCase() + entidad.substring(1);

  Widget _chip(String texto, bool activo, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(texto, style: const TextStyle(fontSize: 11.5)),
        selected: activo,
        selectedColor: Tema.azul.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          color: activo ? Tema.azul : Colors.black87,
          fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.registro});

  final RegistroAuditoria registro;

  static const _iconos = {
    'sesion': Icons.login_rounded,
    'muestra': Icons.science_outlined,
    'zona': Icons.map_outlined,
    'punto': Icons.place_outlined,
    'alerta': Icons.notifications_active_outlined,
    'sistema': Icons.sync_rounded,
  };

  static const _colores = {
    'sesion': Tema.azulOscuro,
    'muestra': Tema.cian,
    'zona': Tema.azul,
    'punto': Tema.azul,
    'alerta': Tema.ambar,
    'sistema': Tema.verde,
  };

  @override
  Widget build(BuildContext context) {
    final entidad = registro.accion.entidad;
    final color = _colores[entidad] ?? Tema.azul;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              _iconos[entidad] ?? Icons.circle_outlined,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  registro.accion.etiqueta,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (registro.detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    registro.detalle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${registro.usuarioNombre}  -  ${registro.rol}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formato.hora(registro.fecha),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                Formato.fecha(registro.fecha),
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
