import 'package:flutter/foundation.dart';

import '../dominio/modelos.dart';
import '../dominio/motor_evaluacion.dart';
import 'api/cliente_api.dart';
import 'repositorio.dart';
import 'semilla.dart';

class EstadoApp extends ChangeNotifier {
  EstadoApp(this._repositorio);

  final Repositorio _repositorio;
  Repositorio get repositorio => _repositorio;

  Usuario? _usuario;
  Usuario? get usuario => _usuario;
  bool get autenticado => _usuario != null;

  Organizacion? _organizacion;
  Organizacion? get organizacion => _organizacion;

  List<Parametro> _parametros = const [];
  List<Parametro> get parametros => _parametros;

  List<Zona> _zonas = const [];
  List<Zona> get zonas => _zonas;

  List<Zona> get zonasActivas => _zonas.where((z) => z.activa).toList();

  List<PuntoMuestreo> _puntos = const [];
  List<PuntoMuestreo> get puntos => _puntos;

  List<Dispositivo> _dispositivos = const [];
  List<Dispositivo> get dispositivos => _dispositivos;

  List<Muestra> _muestras = const [];
  List<Muestra> get muestras => _muestras;

  List<Alerta> _alertas = const [];
  List<Alerta> get alertas => _alertas;

  bool _cargando = false;
  bool get cargando => _cargando;

  bool _sincronizando = false;
  bool get sincronizando => _sincronizando;

  String? _errorSincronizacion;
  String? get errorSincronizacion => _errorSincronizacion;

  MotorEvaluacion get motor => MotorEvaluacion(_parametros);

  Future<String?> iniciarSesion(String correo, String clave) async {
    try {
      _usuario = await _repositorio.autenticar(correo, clave);
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
    notifyListeners();
    await cargarCatalogo();
    return null;
  }

  Future<void> cerrarSesion() async {
    await _repositorio.cerrarSesion();
    _usuario = null;
    _muestras = const [];
    _alertas = const [];
    _sesionExpirada = null;
    notifyListeners();
  }

  String? _sesionExpirada;
  String? get sesionExpirada => _sesionExpirada;

  Duration? get vigenciaRestante => _repositorio.vigenciaRestante;

  Map<String, dynamic>? get reclamosToken => _repositorio.reclamosToken;

  bool get puedeAdministrar => _usuario?.rol == RolUsuario.administrador;

  bool get puedeCapturar =>
      _usuario?.rol == RolUsuario.operario ||
      _usuario?.rol == RolUsuario.administrador;

  void _forzarCierrePorSesion(String mensaje) {
    _usuario = null;
    _muestras = const [];
    _alertas = const [];
    _sesionExpirada = mensaje;
    notifyListeners();
  }

  Future<void> cargarCatalogo() async {
    _cargando = true;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        _repositorio.organizacion(),
        _repositorio.parametros(),
        _repositorio.zonas(),
        _repositorio.puntos(),
        _repositorio.dispositivos(),
        _repositorio.muestras(),
        _repositorio.alertas(),
      ]);
      _organizacion = resultados[0] as Organizacion;
      _parametros = resultados[1] as List<Parametro>;
      _zonas = resultados[2] as List<Zona>;
      _puntos = resultados[3] as List<PuntoMuestreo>;
      _dispositivos = resultados[4] as List<Dispositivo>;
      _muestras = resultados[5] as List<Muestra>;
      _alertas = resultados[6] as List<Alerta>;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<Muestra> registrarMuestra({
    required int puntoId,
    required Map<int, double> valores,
    required Map<int, ViaCaptura> origenes,
    String observaciones = '',
  }) async {
    final punto = puntoPorId(puntoId)!;
    final evaluacion = motor.evaluarMuestra(valores, origenes: origenes);

    final borrador = Muestra(
      id: 0,
      puntoId: puntoId,
      usuarioId: _usuario!.id,
      fechaHora: DateTime.now(),
      latitudCaptura: punto.latitud,
      longitudCaptura: punto.longitud,
      clasificacionGlobal: evaluacion.clasificacion,
      mediciones: evaluacion.mediciones,
      parametroLimitanteId: evaluacion.parametroLimitanteId,
      observaciones: observaciones,
    );

    final guardada = await _repositorio.guardarMuestra(borrador);
    _muestras = await _repositorio.muestras();
    _alertas = await _repositorio.alertas();
    notifyListeners();
    return guardada;
  }

  Future<Map<int, double>> leerSensores(int puntoId) =>
      _repositorio.leerSensores(puntoId);

  List<Muestra> get pendientes =>
      _muestras.where((m) => !m.sincronizada).toList();

  Future<int?> sincronizar() async {
    _sincronizando = true;
    _errorSincronizacion = null;
    notifyListeners();
    try {
      final enviadas = await _repositorio.sincronizar();
      _muestras = await _repositorio.muestras();
      return enviadas;
    } on SesionExpirada catch (e) {
      _forzarCierrePorSesion(e.mensaje);
      return null;
    } on ErrorSincronizacion catch (e) {
      _errorSincronizacion = e.mensaje;
      return null;
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  List<RegistroAuditoria> _bitacora = const [];
  List<RegistroAuditoria> get bitacora => _bitacora;

  Future<void> cargarBitacora() async {
    _bitacora = await _repositorio.auditoria();
    notifyListeners();
  }

  Future<void> atenderAlerta(int alertaId) async {
    await _repositorio.marcarAlertaAtendida(alertaId);
    _alertas = await _repositorio.alertas();
    notifyListeners();
  }

  PuntoMuestreo? puntoPorId(int id) {
    for (final p in _puntos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Parametro? parametroPorId(int id) {
    for (final p in _parametros) {
      if (p.id == id) return p;
    }
    return null;
  }

  Usuario? usuarioPorId(int id) {
    for (final u in Semilla.usuarios) {
      if (u.id == id) return u;
    }
    return null;
  }

  List<Dispositivo> dispositivosDe(int puntoId) =>
      _dispositivos.where((d) => d.puntoId == puntoId).toList();

  List<Muestra> muestrasDe(int puntoId) =>
      _muestras.where((m) => m.puntoId == puntoId).toList();

  Muestra? ultimaMuestraDe(int puntoId) {
    for (final m in _muestras) {
      if (m.puntoId == puntoId) return m;
    }
    return null;
  }

  Zona? zonaPorId(int id) {
    for (final z in _zonas) {
      if (z.id == id) return z;
    }
    return null;
  }

  String nombreZonaDe(PuntoMuestreo punto) =>
      zonaPorId(punto.zonaId)?.nombre ?? 'Sin zona';

  List<PuntoMuestreo> puntosDeZona(int zonaId) =>
      _puntos.where((p) => p.zonaId == zonaId).toList();

  List<Muestra> muestrasDeZona(int zonaId) {
    final ids = puntosDeZona(zonaId).map((p) => p.id).toSet();
    return _muestras.where((m) => ids.contains(m.puntoId)).toList();
  }

  List<PuntoMuestreo> get puntosDisponibles {
    final activas = zonasActivas.map((z) => z.id).toSet();
    return _puntos.where((p) => activas.contains(p.zonaId)).toList()
      ..sort((a, b) {
        final zona = (zonaPorId(a.zonaId)?.nombre ?? '')
            .compareTo(zonaPorId(b.zonaId)?.nombre ?? '');
        return zona != 0 ? zona : a.nombre.compareTo(b.nombre);
      });
  }

  List<Zona> get zonasConPuntos =>
      zonasActivas.where((z) => puntosDeZona(z.id).isNotEmpty).toList();

  Future<String?> guardarZona(Zona zona) async {
    try {
      await _repositorio.guardarZona(zona);
      _zonas = await _repositorio.zonas();
      notifyListeners();
      return null;
    } on SesionExpirada catch (e) {
      _forzarCierrePorSesion(e.mensaje);
      return e.mensaje;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  Future<String?> eliminarZona(int zonaId) async {
    if (puntosDeZona(zonaId).isNotEmpty) {
      return 'La zona tiene puntos asignados. Muevalos o eliminelos primero.';
    }
    try {
      await _repositorio.eliminarZona(zonaId);
      _zonas = await _repositorio.zonas();
      notifyListeners();
      return null;
    } on SesionExpirada catch (e) {
      _forzarCierrePorSesion(e.mensaje);
      return e.mensaje;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  Future<String?> guardarPunto(PuntoMuestreo punto) async {
    try {
      await _repositorio.guardarPunto(punto);
      _puntos = await _repositorio.puntos();
      notifyListeners();
      return null;
    } on SesionExpirada catch (e) {
      _forzarCierrePorSesion(e.mensaje);
      return e.mensaje;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  Future<String?> eliminarPunto(int puntoId) async {
    if (muestrasDe(puntoId).isNotEmpty) {
      return 'El punto tiene muestras registradas y no puede eliminarse.';
    }
    try {
      await _repositorio.eliminarPunto(puntoId);
      _puntos = await _repositorio.puntos();
      _dispositivos = await _repositorio.dispositivos();
      notifyListeners();
      return null;
    } on SesionExpirada catch (e) {
      _forzarCierrePorSesion(e.mensaje);
      return e.mensaje;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  int get alertasAbiertas => _alertas.where((a) => !a.atendida).length;

  double get conformidadGlobal =>
      MotorEvaluacion.porcentajeConformidad(_muestras);

  Map<Clasificacion, int> get resumenClasificacion {
    final mapa = {for (final c in Clasificacion.values) c: 0};
    for (final m in _muestras) {
      mapa[m.clasificacionGlobal] = mapa[m.clasificacionGlobal]! + 1;
    }
    return mapa;
  }
}
