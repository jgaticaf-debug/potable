import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/tema.dart';
import 'datos/estado_app.dart';
import 'datos/local/base_datos.dart';
import 'datos/repositorio.dart';
import 'datos/repositorio_mock.dart';
import 'datos/repositorio_sqlite.dart';
import 'ui/inicio_shell.dart';
import 'ui/login_pagina.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.cargar();
  runApp(PotableApp(estado: EstadoApp(await _abrirRepositorio())));
}

/// SQLite es el almacenamiento real. En las plataformas donde no esta
/// disponible (web) se cae al repositorio en memoria para no bloquear la
/// ejecucion, aunque los datos no sobreviven al cierre.
Future<Repositorio> _abrirRepositorio() async {
  if (!BaseDatosLocal.soportado) return RepositorioMock();
  try {
    return await RepositorioSqlite.crear();
  } catch (e) {
    debugPrint('No se pudo abrir SQLite, se usa memoria: $e');
    return RepositorioMock();
  }
}

class PotableApp extends StatelessWidget {
  const PotableApp({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potable',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      home: ListenableBuilder(
        listenable: estado,
        builder: (context, _) => estado.autenticado
            ? InicioShell(estado: estado)
            : LoginPagina(estado: estado),
      ),
    );
  }
}
