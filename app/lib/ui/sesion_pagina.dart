import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import 'widgets/comunes.dart';

class SesionPagina extends StatelessWidget {
  const SesionPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    final usuario = estado.usuario;
    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi sesion')),
        body: const SinDatos(mensaje: 'No hay sesion activa.'),
      );
    }

    final restante = estado.vigenciaRestante;
    final vigente = restante != null && restante > Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi sesion')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Tema.azulOscuro,
                    child: Text(
                      usuario.iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usuario.rol.etiqueta,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Tema.azul,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          usuario.correo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const TituloSeccion('Lo que puede hacer'),
          Card(
            child: Column(
              children: [
                const _Permiso('Consultar el tablero y el historial', true),
                _Permiso('Registrar muestras en campo', estado.puedeCapturar),
                _Permiso(
                  'Administrar zonas, puntos y equipos',
                  estado.puedeAdministrar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    vigente ? Icons.schedule_rounded : Icons.lock_clock_rounded,
                    size: 20,
                    color: vigente ? Tema.verde : Tema.rojo,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vigente
                              ? 'Sesion activa'
                              : 'La sesion expiro',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vigente
                              ? 'Se cerrara sola ${_cierre(restante)}. '
                                  'Vuelva a entrar para continuar.'
                              : 'Vuelva a iniciar sesion.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () async {
              await estado.cerrarSesion();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesion'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Tema.rojo,
            ),
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _BloqueTecnico(estado: estado),
          ],
        ],
      ),
    );
  }

  static String _cierre(Duration restante) {
    final horas = restante.inHours;
    final minutos = restante.inMinutes % 60;
    if (horas == 0) return 'en $minutos minutos';
    final momento = DateTime.now().add(restante);
    return 'a las ${Formato.hora(momento)} (en $horas h $minutos min)';
  }
}

class _Permiso extends StatelessWidget {
  const _Permiso(this.texto, this.concedido);

  final String texto;
  final bool concedido;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        concedido ? Icons.check_circle_rounded : Icons.remove_circle_outline,
        size: 19,
        color: concedido ? Tema.verde : Colors.black26,
      ),
      title: Text(
        texto,
        style: TextStyle(
          fontSize: 12.5,
          color: concedido ? Colors.black87 : Colors.black38,
        ),
      ),
    );
  }
}

class _BloqueTecnico extends StatelessWidget {
  const _BloqueTecnico({required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    final reclamos = estado.reclamosToken;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.bug_report_outlined, size: 20),
        title: const Text(
          'Informacion tecnica',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Solo visible en compilacion de depuracion',
          style: TextStyle(fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const _Subtitulo('Token de acceso (JWT, firma HS256)'),
          if (reclamos != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFF0E2430),
                borderRadius: BorderRadius.circular(9),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(reclamos),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  height: 1.45,
                  color: Color(0xFF8FD8C4),
                ),
              ),
            ),
          const _Subtitulo('Almacenamiento de la contrasena'),
          const Text(
            'PBKDF2-HMAC-SHA256 con sal unica por cuenta. El servidor nunca '
            'guarda la contrasena en claro.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
          ),
          const _Subtitulo('Entorno'),
          _Ajuste('Origen', Config.cargado ? '.env' : 'valores por defecto'),
          _Ajuste('API', Config.apiBaseUrl),
          _Ajuste(
            'Repositorio',
            Config.usarMock ? 'Mock en memoria' : 'API remota',
          ),
          _Ajuste('Iteraciones PBKDF2', '${Config.pbkdf2Iteraciones}'),
          _Ajuste('Latencia simulada', '${Config.latenciaBaseMs} ms'),
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 7),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.black45,
        ),
      ),
    );
  }
}

class _Ajuste extends StatelessWidget {
  const _Ajuste(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
