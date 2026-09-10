import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/tema.dart';
import 'datos/estado_app.dart';
import 'datos/api/cliente_api.dart';
import 'datos/api/cliente_http.dart';
import 'datos/api/mock_api.dart';
import 'datos/local/base_datos.dart';
import 'datos/repositorio.dart';
import 'datos/repositorio_mock.dart';
import 'datos/repositorio_sqlite.dart';
import 'datos/sensores/sensor_ble.dart';
import 'datos/sensores/sensor_cliente.dart';
import 'datos/sensores/sensor_simulado.dart';
import 'ui/inicio_shell.dart';
import 'ui/login_pagina.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.cargar();
  final estado = EstadoApp(await _abrirRepositorio());
  runApp(PotableApp(estado: estado));

  unawaited(estado.restaurarSesion());
}

Future<Repositorio> _abrirRepositorio() async {
  final cliente = _abrirCliente();
  final sensor = _abrirSensor();

  if (!BaseDatosLocal.soportado) return RepositorioMock(cliente: cliente);
  try {
    return await RepositorioSqlite.crear(cliente: cliente, sensor: sensor);
  } catch (e) {
    debugPrint('No se pudo abrir SQLite, se usa memoria: $e');
    return RepositorioMock(cliente: cliente);
  }
}

SensorCliente _abrirSensor() {
  final soportaBle = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (Config.usarSensorBle ?? soportaBle) {
    debugPrint('Sensores por Bluetooth.');
    return SensorBle();
  }
  debugPrint('Sensores simulados dentro de la aplicacion.');
  return SensorSimulado();
}

Cliente _abrirCliente() {
  if (Config.usarMock) {
    debugPrint('Servidor simulado dentro de la aplicacion.');
    return ClienteApi(MockApi());
  }
  debugPrint('API remota en ${Config.apiBaseUrl}');
  return ClienteHttp();
}

class PotableApp extends StatefulWidget {
  const PotableApp({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<PotableApp> createState() => _PotableAppState();
}

class _PotableAppState extends State<PotableApp> {
  late final AppLifecycleListener _ciclo;

  EstadoApp get estado => widget.estado;

  @override
  void initState() {
    super.initState();

    // El operario guarda el telefono, camina al siguiente punto y lo
    // saca. Ese es el momento de refrescar. Un Timer no sirve: Android
    // los suspende mientras la app esta en segundo plano.
    _ciclo = AppLifecycleListener(
      onResume: () => estado.refrescar(forzar: false),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potable',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      home: ListenableBuilder(
        listenable: estado,
        builder: (context, _) => switch (estado) {
          _ when estado.restaurando => const _Arranque(),
          _ when estado.autenticado => InicioShell(estado: estado),
          _ => LoginPagina(estado: estado),
        },
      ),
    );
  }
}

class _Arranque extends StatelessWidget {
  const _Arranque();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Tema.azulOscuro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, size: 54, color: Colors.white),
            SizedBox(height: 18),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
