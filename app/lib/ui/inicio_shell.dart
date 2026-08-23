import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../datos/estado_app.dart';
import 'admin_pagina.dart';
import 'captura_pagina.dart';
import 'sesion_pagina.dart';
import 'historial_pagina.dart';
import 'sincronizacion_pagina.dart';
import 'tablero_pagina.dart';

class InicioShell extends StatefulWidget {
  const InicioShell({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<InicioShell> createState() => _InicioShellState();
}

class _InicioShellState extends State<InicioShell> {
  int _indice = 0;

  static const _titulos = [
    'Tablero',
    'Captura de datos',
    'Historial',
    'Sincronizacion',
    'Administracion',
  ];

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;

    if (estado.parametros.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Cargando catalogo de la organizacion...',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final pendientes = estado.pendientes.length;
    final alertas = estado.alertasAbiertas;

    final paginas = [
      TableroPagina(estado: estado),
      CapturaPagina(estado: estado),
      HistorialPagina(estado: estado),
      SincronizacionPagina(estado: estado),
      AdminPagina(estado: estado),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.water_drop_rounded, size: 20),
            const SizedBox(width: 8),
            Text(_titulos[_indice], style: const TextStyle(fontSize: 17)),
          ],
        ),
        actions: [
          if (pendientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: '$pendientes muestra(s) sin sincronizar',
                icon: Badge(
                  label: Text('$pendientes'),
                  backgroundColor: Tema.ambar,
                  child: const Icon(Icons.cloud_off_rounded),
                ),
                onPressed: () => setState(() => _indice = 3),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_rounded),
            onSelected: (v) {
              if (v == 'salir') {
                estado.cerrarSesion();
              } else if (v == 'sesion') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SesionPagina(estado: estado),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado.usuario?.nombre ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      estado.usuario?.rol.etiqueta ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sesion',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Mi sesion'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'salir',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Cerrar sesion'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _indice, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tablero',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_chart_outlined),
            selectedIcon: Icon(Icons.add_chart_rounded),
            label: 'Capturar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alertas > 0,
              label: Text('$alertas'),
              child: const Icon(Icons.sync_outlined),
            ),
            selectedIcon: const Icon(Icons.sync_rounded),
            label: 'Sincronizar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}
