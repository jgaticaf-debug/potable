import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../datos/estado_app.dart';
import '../datos/repositorio.dart';
import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'detalle_muestra_pagina.dart';
import 'widgets/comunes.dart';
import 'widgets/selector_punto.dart';

class CapturaPagina extends StatefulWidget {
  const CapturaPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<CapturaPagina> createState() => _CapturaPaginaState();
}

class _CapturaPaginaState extends State<CapturaPagina> {
  int? _puntoId;
  final _controles = <int, TextEditingController>{};
  final _origenes = <int, ViaCaptura>{};
  final _observaciones = TextEditingController();

  bool _leyendoSensor = false;
  bool _guardando = false;

  EstadoApp get estado => widget.estado;

  void _asegurarControles() {
    for (final p in estado.parametros) {
      _controles.putIfAbsent(p.id, TextEditingController.new);
      _origenes.putIfAbsent(p.id, () => ViaCaptura.manual);
    }
  }

  TextEditingController _controlDe(int parametroId) =>
      _controles.putIfAbsent(parametroId, TextEditingController.new);

  ViaCaptura _origenDe(int parametroId) =>
      _origenes[parametroId] ?? ViaCaptura.manual;

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    _observaciones.dispose();
    super.dispose();
  }

  PuntoMuestreo? get _punto =>
      _puntoId == null ? null : estado.puntoPorId(_puntoId!);

  Map<int, double> get _valores {
    final mapa = <int, double>{};
    for (final entrada in _controles.entries) {
      final texto = entrada.value.text.trim().replaceAll(',', '.');
      if (texto.isEmpty) continue;
      final valor = double.tryParse(texto);
      if (valor != null) mapa[entrada.key] = valor;
    }
    return mapa;
  }

  ResultadoEvaluacion get _evaluacion =>
      estado.motor.evaluarMuestra(_valores, origenes: _origenes);

  Future<void> _elegirPunto() async {
    final elegido = await mostrarSelectorPunto(
      context,
      estado: estado,
      seleccionado: _puntoId,
    );
    if (elegido != null && mounted) setState(() => _puntoId = elegido);
  }

  Future<void> _leerSensores() async {
    final punto = _punto;
    if (punto == null) return;
    setState(() => _leyendoSensor = true);
    try {
      final lectura = await estado.leerSensores(punto.id);
      if (!mounted) return;
      setState(() {
        lectura.forEach((parametroId, valor) {
          _controlDe(parametroId).text = Formato.numero(valor);
          _origenes[parametroId] = ViaCaptura.sensor;
        });
      });
      _aviso(
        'Lectura recibida de ${estado.dispositivosDe(punto.id).isEmpty ? 'el sensor' : estado.dispositivosDe(punto.id).first.identificador}.',
        Tema.verde,
      );
    } on ErrorSincronizacion catch (e) {
      if (mounted) _aviso(e.mensaje, Tema.ambar);
    } finally {
      if (mounted) setState(() => _leyendoSensor = false);
    }
  }

  // Coliformes necesita laboratorio, asi que en campo va a faltar casi
  // siempre. No lo bloqueo, pero que quede claro que el veredicto sale sin el.
  Future<bool> _confirmarSiFaltanCriticos() async {
    final faltantes = estado.motor.criticosFaltantes(_valores.keys);
    if (faltantes.isEmpty) return true;

    final nombres = faltantes.map((p) => p.nombre).join(', ');
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Faltan parametros criticos'),
        content: Text(
          'No registro: $nombres.\n\n'
          'La muestra se va a guardar como evaluacion parcial: el resultado '
          'sale de los parametros que si midio, y no se puede declarar apta '
          'mientras falte un critico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Guardar parcial'),
          ),
        ],
      ),
    );
    return respuesta == true;
  }

  Future<void> _guardar() async {
    final punto = _punto;
    if (punto == null) {
      _aviso('Seleccione el punto de muestreo.', Tema.ambar);
      return;
    }
    if (_valores.isEmpty) {
      _aviso('Registre al menos un parametro.', Tema.ambar);
      return;
    }

    if (!await _confirmarSiFaltanCriticos()) return;

    setState(() => _guardando = true);
    final muestra = await estado.registrarMuestra(
      puntoId: punto.id,
      valores: _valores,
      origenes: _origenes,
      observaciones: _observaciones.text.trim(),
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleMuestraPagina(
          estado: estado,
          muestra: muestra,
          recienGuardada: true,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      for (final c in _controles.values) {
        c.clear();
      }
      for (final k in _origenes.keys.toList()) {
        _origenes[k] = ViaCaptura.manual;
      }
      _observaciones.clear();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    _asegurarControles();
    final punto = _punto;
    final evaluacion = _evaluacion;
    final hayValores = _valores.isNotEmpty;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const TituloSeccion('Punto de muestreo'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _elegirPunto,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Punto de muestreo',
                          prefixIcon: Icon(Icons.place_outlined),
                          suffixIcon: Icon(Icons.unfold_more_rounded),
                        ),
                        child: Text(
                          punto == null
                              ? 'Toque para buscar'
                              : '${estado.nombreZonaDe(punto)}  /  '
                                  '${punto.nombre}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: punto == null
                                ? Colors.black45
                                : Colors.black87,
                            fontWeight: punto == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (punto != null) ...[
                      const SizedBox(height: 12),
                      _InfoPunto(estado: estado, punto: punto),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: (_leyendoSensor || !punto.instrumentado)
                            ? null
                            : _leerSensores,
                        icon: _leyendoSensor
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(
                          _leyendoSensor
                              ? 'Conectando con el dispositivo...'
                              : punto.instrumentado
                                  ? 'Leer sensores por Bluetooth'
                                  : 'Punto sin instrumentacion',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            TituloSeccion(
              'Parametros COGUANOR NTG 29001',
              accion: hayValores
                  ? InsigniaClasificacion(evaluacion.clasificacion,
                      compacta: true)
                  : null,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final p in estado.parametros)
                      _CampoParametro(
                        parametro: p,
                        controlador: _controlDe(p.id),
                        origen: _origenDe(p.id),
                        motor: estado.motor,
                        onCambio: () => setState(() {
                          _origenes[p.id] = ViaCaptura.manual;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const TituloSeccion('Observaciones'),
            TextField(
              controller: _observaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Condiciones del punto, incidencias, acciones '
                    'tomadas...',
              ),
            ),
            const SizedBox(height: 16),

            if (hayValores) _ResumenEvaluacion(estado: estado, evaluacion: evaluacion),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_guardando ? 'Guardando...' : 'Registrar muestra'),
          ),
        ),
      ],
    );
  }
}

class _InfoPunto extends StatelessWidget {
  const _InfoPunto({required this.estado, required this.punto});

  final EstadoApp estado;
  final PuntoMuestreo punto;

  @override
  Widget build(BuildContext context) {
    final dispositivos = estado.dispositivosDe(punto.id);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Tema.azul.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linea(Icons.map_outlined, estado.nombreZonaDe(punto)),
          _linea(Icons.category_outlined, punto.tipo.etiqueta),
          if (punto.tieneCoordenadas)
            _linea(
              Icons.my_location_rounded,
              Formato.coordenada(punto.latitud!, punto.longitud!),
            ),
          _linea(
            Icons.memory_rounded,
            dispositivos.isEmpty
                ? 'Sin dispositivo: captura manual'
                : '${dispositivos.first.identificador}  -  calibrado '
                    '${Formato.relativo(dispositivos.first.ultimaCalibracion)}',
            alerta: dispositivos.isNotEmpty &&
                dispositivos.first.calibracionVencida,
          ),
        ],
      ),
    );
  }

  Widget _linea(IconData icono, String texto, {bool alerta = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: alerta ? Tema.ambar : Colors.black45),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              alerta ? '$texto  (calibracion vencida)' : texto,
              style: TextStyle(
                fontSize: 11.5,
                color: alerta ? Tema.ambar : Colors.black87,
                fontWeight: alerta ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoParametro extends StatelessWidget {
  const _CampoParametro({
    required this.parametro,
    required this.controlador,
    required this.origen,
    required this.motor,
    required this.onCambio,
  });

  final Parametro parametro;
  final TextEditingController controlador;
  final ViaCaptura origen;
  final MotorEvaluacion motor;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final texto = controlador.text.trim().replaceAll(',', '.');
    final valor = texto.isEmpty ? null : double.tryParse(texto);
    final clasificacion =
        valor == null ? null : motor.clasificarValor(parametro, valor);
    final color = clasificacion == null
        ? Colors.black26
        : Tema.color(clasificacion);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
                        parametro.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (parametro.critico) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.priority_high_rounded,
                          size: 13, color: Tema.rojo),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Norma ${parametro.rangoLegible}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (origen == ViaCaptura.sensor)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Icon(Icons.sensors_rounded, size: 11, color: Tema.cian),
                        SizedBox(width: 4),
                        Text(
                          'Lectura del sensor',
                          style: TextStyle(fontSize: 10.5, color: Tema.cian),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child: TextField(
              controller: controlador,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => onCambio(),
              decoration: InputDecoration(
                hintText: '--',
                isDense: true,
                suffixText: parametro.unidad,
                suffixStyle: const TextStyle(fontSize: 9.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: color, width: valor == null ? 1 : 1.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: color, width: 1.8),
                ),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: clasificacion == null ? Colors.black87 : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenEvaluacion extends StatelessWidget {
  const _ResumenEvaluacion({required this.estado, required this.evaluacion});

  final EstadoApp estado;
  final ResultadoEvaluacion evaluacion;

  @override
  Widget build(BuildContext context) {
    final c = evaluacion.clasificacion;
    final color = Tema.color(c);
    final limitante = evaluacion.parametroLimitanteId == null
        ? null
        : estado.parametroPorId(evaluacion.parametroLimitanteId!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Tema.icono(c), color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evaluacion automatica: ${c.etiqueta}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  limitante == null
                      ? 'Los ${evaluacion.mediciones.length} valores '
                          'capturados estan dentro de norma.'
                      : 'Parametro limitante: ${limitante.nombre}. '
                          'Norma ${limitante.rangoLegible}.',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
