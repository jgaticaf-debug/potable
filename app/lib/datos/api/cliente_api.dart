import '../semilla.dart';
import 'cliente.dart';
import 'mock_api.dart';

export 'cliente.dart';

class ClienteApi with SesionEnToken implements Cliente {
  ClienteApi(this._api);

  final MockApi _api;

  @override
  Future<Map<String, dynamic>> login(String correo, String clave) async {
    final r = await _api.postLogin(correo: correo, clave: clave);
    if (!r.exitosa) {
      throw ErrorApi(r.codigo, r.mensaje);
    }
    tokenActual = r.cuerpo['token'] as String;
    return r.cuerpo['usuario'] as Map<String, dynamic>;
  }

  @override
  Future<void> logout() async {
    await _api.postLogout(encabezado);
    tokenActual = null;
  }

  @override
  Future<Map<String, dynamic>> perfil() async =>
      _desempaquetar(await _api.getPerfil(encabezado));

  @override
  Future<CatalogoRemoto> catalogo() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return CatalogoRemoto(
      organizacion: {
        'id': Semilla.organizacion.id,
        'nombre': Semilla.organizacion.nombre,
        'nit': Semilla.organizacion.nit,
        'activa': Semilla.organizacion.activa,
      },
      parametros: [
        for (final p in Semilla.parametros)
          {
            'id': p.id,
            'nombre': p.nombre,
            'unidad': p.unidad,
            'via_captura': p.viaCaptura.name,
            'limite_min': p.limiteMin,
            'limite_max': p.limiteMax,
            'alerta_min': p.alertaMin,
            'alerta_max': p.alertaMax,
            'critico': p.critico,
            'version_norma': p.versionNorma,
            'nota_indicativa': p.notaIndicativa,
            'descripcion': p.descripcion,
          },
      ],
      zonas: [
        for (final z in Semilla.zonas)
          {
            'id': z.id,
            'organizacion_id': z.organizacionId,
            'nombre': z.nombre,
            'descripcion': z.descripcion,
            'activa': z.activa,
          },
      ],
      puntos: [
        for (final p in Semilla.puntos)
          {
            'id': p.id,
            'organizacion_id': p.organizacionId,
            'zona_id': p.zonaId,
            'nombre': p.nombre,
            'tipo': p.tipo.name,
            'instrumentado': p.instrumentado,
            'latitud': p.latitud,
            'longitud': p.longitud,
          },
      ],
      dispositivos: [
        for (final d in Semilla.dispositivos())
          {
            'id': d.id,
            'punto_id': d.puntoId,
            'identificador': d.identificador,
            'tipo_sensor': d.tipoSensor,
            'ultima_calibracion': d.ultimaCalibracion.toIso8601String(),
          },
      ],
      usuarios: [
        for (final u in Semilla.usuarios)
          {
            'id': u.id,
            'organizacion_id': u.organizacionId,
            'nombre': u.nombre,
            'correo': u.correo,
            'rol': u.rol.name,
            'activo': u.activo,
          },
      ],
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> muestrasRemotas({int limite = 1000}) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>?> alertasRemotas() async => null;

  @override
  Future<void> atenderAlerta(int alertaId) async {}

  @override
  Future<Map<String, dynamic>> sincronizar(
    List<Map<String, dynamic>> muestras,
  ) async =>
      _desempaquetar(await _api.postSincronizacion(encabezado, muestras));

  @override
  Future<Map<String, dynamic>> guardarDispositivo(
    Map<String, dynamic> dispositivo,
  ) async =>
      _desempaquetar(await _api.guardarDispositivo(encabezado, dispositivo));

  @override
  Future<void> eliminarDispositivo(int dispositivoId) async =>
      _desempaquetar(await _api.eliminarDispositivo(encabezado, dispositivoId));

  @override
  Future<Map<String, dynamic>> guardarUsuario(
    Map<String, dynamic> usuario, {
    String? clave,
  }) async =>
      _desempaquetar(
        await _api.guardarUsuario(encabezado, usuario, clave: clave),
      );

  @override
  Future<void> eliminarUsuario(int usuarioId) async =>
      _desempaquetar(await _api.eliminarUsuario(encabezado, usuarioId));

  @override
  Future<Map<String, dynamic>> guardarZona(Map<String, dynamic> zona) async =>
      _desempaquetar(await _api.guardarZona(encabezado, zona));

  @override
  Future<void> eliminarZona(int zonaId) async =>
      _desempaquetar(await _api.eliminarZona(encabezado, zonaId));

  @override
  Future<Map<String, dynamic>> guardarPunto(
    Map<String, dynamic> punto,
  ) async =>
      _desempaquetar(await _api.guardarPunto(encabezado, punto));

  @override
  Future<void> eliminarPunto(int puntoId) async =>
      _desempaquetar(await _api.eliminarPunto(encabezado, puntoId));

  Map<String, dynamic> _desempaquetar(RespuestaHttp r) {
    if (r.exitosa) return r.cuerpo;
    if (r.codigo == 401) {
      tokenActual = null;
      throw SesionExpirada(r.mensaje);
    }
    throw ErrorApi(r.codigo, r.mensaje);
  }
}
