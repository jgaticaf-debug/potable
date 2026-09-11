import 'package:flutter/material.dart';

import '../core/formato.dart';
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

  static const _secciones = <(String, IconData)>[
    ('Zonas', Icons.map_outlined),
    ('Puntos', Icons.place_outlined),
    ('Usuarios', Icons.people_alt_outlined),
    ('Norma', Icons.gavel_rounded),
    ('Bitacora', Icons.history_edu_outlined),
  ];

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

  Future<void> _editarUsuario([Usuario? usuario]) async {
    final resultado = await mostrarFormularioUsuario(
      context,
      organizacionId: estado.organizacion?.id ?? 1,
      usuario: usuario,
    );
    if (resultado == null) return;

    final error = await estado.guardarUsuario(
      resultado.usuario,
      clave: resultado.clave,
    );
    if (!mounted) return;
    _aviso(
      error ?? 'Usuario ${usuario == null ? 'creado' : 'actualizado'}.',
      error == null ? Tema.verde : Tema.rojo,
    );
  }

  Future<void> _borrarUsuario(Usuario usuario) async {
    final confirmado = await _confirmar(
      'Eliminar usuario',
      'Se eliminara la cuenta de ${usuario.nombre}.',
    );
    if (!confirmado) return;

    final error = await estado.eliminarUsuario(usuario.id);
    if (!mounted) return;
    _aviso(
      error ?? 'Usuario eliminado.',
      error == null ? Tema.verde : Tema.rojo,
    );
  }

  Widget _listaUsuarios() {
    final usuarios = estado.usuarios;

    return Stack(
      children: [
        Refrescable(
          estado: estado,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
            const _Explicacion(
              'El rol decide que puede hacer cada persona. Una cuenta '
              'inactiva no puede entrar, pero conserva sus muestras y su '
              'rastro en la bitacora.',
            ),
            const SizedBox(height: 14),
            if (usuarios.isEmpty)
              const Card(
                child: SinDatos(
                  mensaje: 'No hay usuarios registrados.',
                  icono: Icons.people_alt_outlined,
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < usuarios.length; i++) ...[
                      _FilaUsuario(
                        usuario: usuarios[i],
                        muestras: estado.muestras
                            .where((m) => m.usuarioId == usuarios[i].id)
                            .length,
                        esUsted: usuarios[i].id == estado.usuario?.id,
                        puedeEditar: estado.puedeAdministrar,
                        onEditar: () => _editarUsuario(usuarios[i]),
                        onEliminar: () => _borrarUsuario(usuarios[i]),
                      ),
                      if (i < usuarios.length - 1)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (estado.puedeAdministrar)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _editarUsuario(),
              backgroundColor: Tema.azulOscuro,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Nuevo usuario'),
            ),
          ),
      ],
    );
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

  Future<void> _verEquipos(PuntoMuestreo punto) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListenableBuilder(
        listenable: estado,
        builder: (contexto, _) => _HojaEquipos(
          punto: punto,
          equipos: estado.dispositivosDe(punto.id),
          puedeEditar: estado.puedeAdministrar,
          onNuevo: () => _editarEquipo(punto),
          onEditar: (d) => _editarEquipo(punto, d),
          onEliminar: _borrarEquipo,
        ),
      ),
    );
  }

  Future<void> _editarEquipo(PuntoMuestreo punto, [Dispositivo? equipo]) async {
    final resultado = await mostrarFormularioDispositivo(
      context,
      puntoId: punto.id,
      dispositivo: equipo,
      buscarCercanos: estado.buscarEquiposCercanos,
    );
    if (resultado == null) return;

    final error = await estado.guardarDispositivo(resultado);
    if (!mounted) return;
    _aviso(
      error ?? 'Equipo ${equipo == null ? 'registrado' : 'actualizado'}.',
      error == null ? Tema.verde : Tema.rojo,
    );
  }

  Future<void> _borrarEquipo(Dispositivo equipo) async {
    final confirmado = await _confirmar(
      'Eliminar equipo',
      'Se eliminara ${equipo.identificador}. El punto quedara sin lectura '
      'automatica.',
    );
    if (!confirmado) return;

    final error = await estado.eliminarDispositivo(equipo.id);
    if (!mounted) return;
    _aviso(
      error ?? 'Equipo eliminado.',
      error == null ? Tema.verde : Tema.rojo,
    );
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
          child: SizedBox(
            height: MediaQuery.textScalerOf(context).scale(36),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, s) in _secciones.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(
                        s.$2,
                        size: 15,
                        color: _seccion == i ? Tema.azul : Colors.black45,
                      ),
                      label: Text(s.$1, style: const TextStyle(fontSize: 12)),
                      selected: _seccion == i,
                      selectedColor: Tema.azul.withValues(alpha: 0.16),
                      labelStyle: TextStyle(
                        color: _seccion == i ? Tema.azul : Colors.black87,
                        fontWeight:
                            _seccion == i ? FontWeight.w700 : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _seccion = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_seccion) {
            0 => _listaZonas(),
            1 => _listaPuntos(),
            2 => _listaUsuarios(),
            3 => NormaPagina(estado: estado),
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
        Refrescable(
          estado: estado,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
        Refrescable(
          estado: estado,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                          onEquipos: () => _verEquipos(p),
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
    required this.onEquipos,
  });

  final VoidCallback onEquipos;

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
      onTap: onEquipos,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, size: 19),
        onSelected: (v) => switch (v) {
          'equipos' => onEquipos(),
          'editar' => onEditar(),
          _ => onEliminar(),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'equipos',
            child: Row(
              children: [
                const Icon(Icons.memory_rounded, size: 17),
                const SizedBox(width: 8),
                Text('Equipos ($dispositivos)'),
              ],
            ),
          ),
          if (puedeEditar) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 17),
                  SizedBox(width: 8),
                  Text('Editar punto'),
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
        ],
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({
    required this.usuario,
    required this.muestras,
    required this.esUsted,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final Usuario usuario;
  final int muestras;
  final bool esUsted;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  static const _colorRol = {
    RolUsuario.administrador: Tema.azulOscuro,
    RolUsuario.calidad: Tema.cian,
    RolUsuario.operario: Tema.azul,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorRol[usuario.rol] ?? Tema.azul;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 17,
        backgroundColor:
            usuario.activo ? color : Colors.black.withValues(alpha: 0.12),
        child: Text(
          usuario.iniciales,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: usuario.activo ? Colors.white : Colors.black38,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              usuario.nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: usuario.activo ? Colors.black87 : Colors.black38,
              ),
            ),
          ),
          if (esUsted) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Tema.azul.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'USTED',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Tema.azul,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${usuario.rol.etiqueta}  -  ${usuario.correo}\n'
        '${usuario.activo ? '' : 'Cuenta inactiva  -  '}'
        '$muestras muestra(s) registradas',
        style: const TextStyle(fontSize: 11.5, height: 1.35),
      ),
      isThreeLine: true,
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
                if (!esUsted)
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

class _HojaEquipos extends StatelessWidget {
  const _HojaEquipos({
    required this.punto,
    required this.equipos,
    required this.puedeEditar,
    required this.onNuevo,
    required this.onEditar,
    required this.onEliminar,
  });

  final PuntoMuestreo punto;
  final List<Dispositivo> equipos;
  final bool puedeEditar;
  final VoidCallback onNuevo;
  final void Function(Dispositivo) onEditar;
  final void Function(Dispositivo) onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Equipos de ${punto.nombre}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            punto.instrumentado
                ? 'El codigo debe coincidir con el nombre BLE que anuncia el '
                    'ESP32.'
                : 'Este punto no esta marcado como instrumentado, asi que la '
                    'lectura automatica seguira deshabilitada.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: punto.instrumentado ? Colors.black54 : Tema.ambar,
            ),
          ),
          const SizedBox(height: 16),
          if (equipos.isEmpty)
            const SinDatos(
              mensaje: 'Sin equipos registrados.',
              icono: Icons.memory_rounded,
            )
          else
            for (final d in equipos)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.memory_rounded,
                  color: d.calibracionVencida ? Tema.ambar : Tema.cian,
                ),
                title: Text(
                  d.identificador,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${d.tipoSensor}\n'
                  'Calibrado ${Formato.relativo(d.ultimaCalibracion)}'
                  '${d.calibracionVencida ? '  -  vencida' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: d.calibracionVencida ? Tema.ambar : null,
                  ),
                ),
                isThreeLine: true,
                trailing: puedeEditar
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEditar(d);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: Tema.rojo,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEliminar(d);
                            },
                          ),
                        ],
                      )
                    : null,
              ),
          if (puedeEditar) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onNuevo();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar equipo'),
            ),
          ],
        ],
      ),
    );
  }
}
