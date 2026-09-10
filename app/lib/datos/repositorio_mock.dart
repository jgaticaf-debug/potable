import 'dart:math';

import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'api/cliente_api.dart';
import 'api/mock_api.dart';
import 'repositorio.dart';
import 'semilla.dart';

class RepositorioMock implements Repositorio {
  RepositorioMock({Cliente? cliente})
      : _cliente = cliente ?? ClienteApi(MockApi()) {
    _motor = MotorEvaluacion(Semilla.parametros);
    _muestras = Semilla.muestras(_motor);
    _alertas = _derivarAlertas(_muestras);
    _siguienteMuestraId = _muestras.map((m) => m.id).fold<int>(0, max) + 1;
    _zonas = List<Zona>.from(Semilla.zonas);
    _puntos = List<PuntoMuestreo>.from(Semilla.puntos);
    _siguienteZonaId = _zonas.map((z) => z.id).fold<int>(0, max) + 1;
    _siguientePuntoId = _puntos.map((p) => p.id).fold<int>(0, max) + 1;
  }

  late final MotorEvaluacion _motor;
  late List<Muestra> _muestras;
  late List<Alerta> _alertas;
  late int _siguienteMuestraId;
  late List<Zona> _zonas;
  late List<PuntoMuestreo> _puntos;
  late int _siguienteZonaId;
  late int _siguientePuntoId;
  int _siguienteAlertaId = 1;

  final Cliente _cliente;

  final _azar = Random();

  static String get claveDemo => MockApi.claveDemo;

  Future<T> _latencia<T>(T valor, [int ms = 420]) =>
      Future.delayed(Duration(milliseconds: ms), () => valor);

  @override
  bool get haySesion => _cliente.haySesion;

  @override
  Duration? get vigenciaRestante => _cliente.tiempoRestante;

  @override
  Map<String, dynamic>? get reclamosToken => _cliente.reclamos;

  @override
  Future<Usuario> autenticar(String correo, String clave) async {
    final datos = await _cliente.login(correo, clave);
    final rol = RolUsuario.values.firstWhere(
      (r) => r.name == datos['rol'],
      orElse: () => RolUsuario.operario,
    );
    return Usuario(
      id: datos['id'] as int,
      organizacionId: datos['organizacion_id'] as int,
      nombre: datos['nombre'] as String,
      correo: datos['correo'] as String,
      rol: rol,
    );
  }

  @override
  Future<Usuario?> restaurarSesion() async => null;

  @override
  Future<void> cerrarSesion() => _cliente.logout();

  @override
  Future<Organizacion> organizacion() => _latencia(Semilla.organizacion, 120);

  @override
  Future<List<Parametro>> parametros() => _latencia(Semilla.parametros, 150);

  @override
  Future<List<Usuario>> usuarios() => _latencia(Semilla.usuarios, 140);

  @override
  Future<Usuario> guardarUsuario(Usuario usuario, {String? clave}) async =>
      usuario;

  @override
  Future<void> eliminarUsuario(int usuarioId) async {}

  @override
  Future<List<Zona>> zonas() =>
      _latencia(List<Zona>.unmodifiable(_zonas), 160);

  @override
  Future<Zona> guardarZona(Zona zona) async {
    final datos = await _cliente.guardarZona({
      'id': zona.id,
      'organizacion_id': zona.organizacionId,
      'nombre': zona.nombre,
      'descripcion': zona.descripcion,
      'activa': zona.activa,
    });

    final nombre = datos['nombre'] as String;
    if (zona.id == 0) {
      final creada = Zona(
        id: _siguienteZonaId++,
        organizacionId: zona.organizacionId,
        nombre: nombre,
        descripcion: zona.descripcion,
        activa: zona.activa,
      );
      _zonas = [..._zonas, creada];
      return creada;
    }

    final actualizada = zona.copyCon(nombre: nombre);
    _zonas = [
      for (final z in _zonas)
        if (z.id == zona.id) actualizada else z,
    ];
    return actualizada;
  }

  @override
  Future<void> eliminarZona(int zonaId) async {
    await _cliente.eliminarZona(zonaId);
    _zonas = _zonas.where((z) => z.id != zonaId).toList();
  }

  @override
  Future<List<PuntoMuestreo>> puntos() =>
      _latencia(List<PuntoMuestreo>.unmodifiable(_puntos), 200);

  @override
  Future<PuntoMuestreo> guardarPunto(PuntoMuestreo punto) async {
    final datos = await _cliente.guardarPunto({
      'id': punto.id,
      'organizacion_id': punto.organizacionId,
      'zona_id': punto.zonaId,
      'nombre': punto.nombre,
      'tipo': punto.tipo.name,
      'instrumentado': punto.instrumentado,
      'latitud': punto.latitud,
      'longitud': punto.longitud,
    });

    final nombre = datos['nombre'] as String;
    if (punto.id == 0) {
      final creado = PuntoMuestreo(
        id: _siguientePuntoId++,
        organizacionId: punto.organizacionId,
        zonaId: punto.zonaId,
        nombre: nombre,
        tipo: punto.tipo,
        instrumentado: punto.instrumentado,
        latitud: punto.latitud,
        longitud: punto.longitud,
      );
      _puntos = [..._puntos, creado];
      return creado;
    }

    final actualizado = punto.copyCon(nombre: nombre);
    _puntos = [
      for (final p in _puntos)
        if (p.id == punto.id) actualizado else p,
    ];
    return actualizado;
  }

  @override
  Future<void> eliminarPunto(int puntoId) async {
    await _cliente.eliminarPunto(puntoId);
    _puntos = _puntos.where((p) => p.id != puntoId).toList();
    _dispositivos = _dispositivos.where((d) => d.puntoId != puntoId).toList();
  }

  late List<Dispositivo> _dispositivos = Semilla.dispositivos();

  @override
  Future<List<Dispositivo>> dispositivos() =>
      _latencia(List<Dispositivo>.unmodifiable(_dispositivos), 200);

  @override
  Future<Dispositivo> guardarDispositivo(Dispositivo dispositivo) async =>
      dispositivo;

  @override
  Future<void> eliminarDispositivo(int dispositivoId) async {}

  @override
  Future<List<Muestra>> muestras() =>
      _latencia(List<Muestra>.unmodifiable(_muestras), 380);

  @override
  Future<List<Alerta>> alertas() =>
      _latencia(List<Alerta>.unmodifiable(_alertas), 180);

  @override
  Future<Muestra> guardarMuestra(Muestra muestra) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final guardada = Muestra(
      id: _siguienteMuestraId++,
      puntoId: muestra.puntoId,
      usuarioId: muestra.usuarioId,
      fechaHora: muestra.fechaHora,
      creadoEn: muestra.creadoEn,
      latitudCaptura: muestra.latitudCaptura,
      longitudCaptura: muestra.longitudCaptura,
      clasificacionGlobal: muestra.clasificacionGlobal,
      mediciones: muestra.mediciones,
      parametroLimitanteId: muestra.parametroLimitanteId,
      observaciones: muestra.observaciones,
    );
    _muestras = [guardada, ..._muestras];
    _alertas = [..._alertaDe(guardada), ..._alertas];
    return guardada;
  }

  @override
  Future<void> marcarAlertaAtendida(int alertaId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _alertas = [
      for (final a in _alertas)
        if (a.id == alertaId) a.copyCon(atendida: true) else a,
    ];
  }

  @override
  Future<Map<int, double>> leerSensores(int puntoId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final punto = _puntos.firstWhere((p) => p.id == puntoId);
    if (!punto.instrumentado) {
      throw const ErrorSincronizacion(
        'Este punto no tiene dispositivo instrumentado. Registre los valores '
        'de forma manual.',
      );
    }

    final previa = _muestras.where((m) => m.puntoId == puntoId).firstOrNull;
    final lectura = <int, double>{};

    for (final p in Semilla.parametros) {
      if (p.viaCaptura != ViaCaptura.sensor) continue;
      final base = previa?.medicionDe(p.id)?.valor ??
          ((p.limiteMin ?? 0) + (p.limiteMax ?? 1)) / 2;
      final amplitud = ((p.limiteMax ?? 10) - (p.limiteMin ?? 0)) * 0.10;
      final valor = max(0.0, base + (_azar.nextDouble() - 0.45) * amplitud);
      lectura[p.id] = _redondear(valor, p.unidad == 'uS/cm' ? 0 : 2);
    }
    return lectura;
  }

  @override
  Future<void> descargarCatalogo() async {}

  @override
  Future<List<RegistroAuditoria>> auditoria({int limite = 200}) async =>
      const [];

  @override
  Future<int> sincronizar() async {
    final pendientes = _muestras.where((m) => !m.sincronizada).toList();

    try {
      await _cliente.sincronizar([
        for (final m in pendientes) _serializar(m),
      ]);
    } on ErrorApi catch (e) {
      throw ErrorSincronizacion(e.mensaje);
    }

    final ahora = DateTime.now();
    var enviadas = 0;
    _muestras = [
      for (final m in _muestras)
        if (m.sincronizada)
          m
        else
          () {
            enviadas++;
            return m.copyCon(sincronizada: true, fechaSincronizacion: ahora);
          }(),
    ];
    return enviadas;
  }

  Map<String, dynamic> _serializar(Muestra m) => {
        'punto_id': m.puntoId,
        'usuario_id': m.usuarioId,
        'fecha_hora': m.fechaHora.toIso8601String(),
        'latitud_captura': m.latitudCaptura,
        'longitud_captura': m.longitudCaptura,
        'clasificacion_global': m.clasificacionGlobal.name,
        'parametro_limitante_id': m.parametroLimitanteId,
        'observaciones': m.observaciones,
        'mediciones': [
          for (final med in m.mediciones)
            {
              'parametro_id': med.parametroId,
              'valor': med.valor,
              'origen': med.origen.name,
              'clasificacion': med.clasificacion.name,
            },
        ],
      };

  List<Alerta> _derivarAlertas(List<Muestra> muestras) {
    final resultado = <Alerta>[];
    for (final m in muestras) {
      resultado.addAll(_alertaDe(m, atendida: resultado.length > 2));
    }
    return resultado;
  }

  List<Alerta> _alertaDe(Muestra muestra, {bool atendida = false}) {
    if (muestra.clasificacionGlobal == Clasificacion.apto) return const [];
    final limitante = muestra.parametroLimitanteId == null
        ? null
        : _motor.parametroPorId(muestra.parametroLimitanteId!);
    final valor = muestra.parametroLimitanteId == null
        ? null
        : muestra.medicionDe(muestra.parametroLimitanteId!)?.valor;

    return [
      Alerta(
        id: _siguienteAlertaId++,
        muestraId: muestra.id,
        puntoId: muestra.puntoId,
        tipo: muestra.clasificacionGlobal.etiqueta,
        detalle: limitante == null
            ? 'Muestra fuera de norma.'
            : '${limitante.nombre} en ${_formato(valor!)} ${limitante.unidad} '
                '(norma: ${limitante.rangoLegible}).',
        fecha: muestra.fechaHora,
        atendida: atendida,
      ),
    ];
  }

  static String _formato(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double _redondear(double v, int decimales) {
    final f = pow(10, decimales);
    return (v * f).round() / f;
  }
}

extension _PrimeroONulo<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
