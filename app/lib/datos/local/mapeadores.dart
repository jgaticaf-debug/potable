import '../../dominio/modelos.dart';

typedef Fila = Map<String, Object?>;

bool _bool(Object? v) => v == 1 || v == true;
int _int(bool v) => v ? 1 : 0;
double? _real(Object? v) => v == null ? null : (v as num).toDouble();
DateTime _fecha(Object? v) => DateTime.parse(v! as String);
DateTime? _fechaOpcional(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

T _porNombre<T extends Enum>(List<T> valores, Object? nombre, T porDefecto) {
  for (final v in valores) {
    if (v.name == nombre) return v;
  }
  return porDefecto;
}

class Mapeadores {
  static Organizacion organizacion(Fila f) => Organizacion(
        id: f['id']! as int,
        nombre: f['nombre']! as String,
        nit: f['nit']! as String,
        activa: _bool(f['activa']),
      );

  static Fila deOrganizacion(Organizacion o) => {
        'id': o.id,
        'nombre': o.nombre,
        'nit': o.nit,
        'activa': _int(o.activa),
      };

  static Usuario usuario(Fila f) => Usuario(
        id: f['id']! as int,
        organizacionId: f['organizacion_id']! as int,
        nombre: f['nombre']! as String,
        correo: f['correo']! as String,
        rol: _porNombre(RolUsuario.values, f['rol'], RolUsuario.operario),
        activo: _bool(f['activo']),
      );

  static Fila deUsuario(Usuario u) => {
        'id': u.id,
        'organizacion_id': u.organizacionId,
        'nombre': u.nombre,
        'correo': u.correo,
        'rol': u.rol.name,
        'activo': _int(u.activo),
      };

  static Zona zona(Fila f) => Zona(
        id: f['id']! as int,
        organizacionId: f['organizacion_id']! as int,
        nombre: f['nombre']! as String,
        descripcion: f['descripcion'] as String? ?? '',
        activa: _bool(f['activa']),
      );

  static Fila deZona(Zona z, {bool conId = true}) => {
        if (conId) 'id': z.id,
        'organizacion_id': z.organizacionId,
        'nombre': z.nombre,
        'descripcion': z.descripcion,
        'activa': _int(z.activa),
      };

  static PuntoMuestreo punto(Fila f) => PuntoMuestreo(
        id: f['id']! as int,
        organizacionId: f['organizacion_id']! as int,
        zonaId: f['zona_id']! as int,
        nombre: f['nombre']! as String,
        tipo: _porNombre(TipoPunto.values, f['tipo'], TipoPunto.pozo),
        instrumentado: _bool(f['instrumentado']),
        latitud: _real(f['latitud']),
        longitud: _real(f['longitud']),
      );

  static Fila dePunto(PuntoMuestreo p, {bool conId = true}) => {
        if (conId) 'id': p.id,
        'organizacion_id': p.organizacionId,
        'zona_id': p.zonaId,
        'nombre': p.nombre,
        'tipo': p.tipo.name,
        'instrumentado': _int(p.instrumentado),
        'latitud': p.latitud,
        'longitud': p.longitud,
      };

  static Dispositivo dispositivo(Fila f) => Dispositivo(
        id: f['id']! as int,
        puntoId: f['punto_id']! as int,
        identificador: f['identificador']! as String,
        tipoSensor: f['tipo_sensor']! as String,
        ultimaCalibracion: _fecha(f['ultima_calibracion']),
      );

  static Fila deDispositivo(Dispositivo d) => {
        'id': d.id,
        'punto_id': d.puntoId,
        'identificador': d.identificador,
        'tipo_sensor': d.tipoSensor,
        'ultima_calibracion': d.ultimaCalibracion.toIso8601String(),
      };

  static Parametro parametro(Fila f) => Parametro(
        id: f['id']! as int,
        nombre: f['nombre']! as String,
        unidad: f['unidad']! as String,
        viaCaptura:
            _porNombre(ViaCaptura.values, f['via_captura'], ViaCaptura.manual),
        limiteMin: _real(f['limite_min']),
        limiteMax: _real(f['limite_max']),
        alertaMin: _real(f['alerta_min']),
        alertaMax: _real(f['alerta_max']),
        critico: _bool(f['critico']),
        versionNorma: f['version_norma']! as String,
        descripcion: f['descripcion'] as String? ?? '',
      );

  static Fila deParametro(Parametro p) => {
        'id': p.id,
        'nombre': p.nombre,
        'unidad': p.unidad,
        'via_captura': p.viaCaptura.name,
        'limite_min': p.limiteMin,
        'limite_max': p.limiteMax,
        'alerta_min': p.alertaMin,
        'alerta_max': p.alertaMax,
        'critico': _int(p.critico),
        'version_norma': p.versionNorma,
        'descripcion': p.descripcion,
      };

  static Muestra muestra(Fila f, List<Medicion> mediciones) => Muestra(
        id: f['id']! as int,
        puntoId: f['punto_id']! as int,
        usuarioId: f['usuario_id']! as int,
        fechaHora: _fecha(f['fecha_hora']),
        creadoEn: _fechaOpcional(f['creado_en']),
        latitudCaptura: _real(f['latitud_captura']),
        longitudCaptura: _real(f['longitud_captura']),
        clasificacionGlobal: _porNombre(
          Clasificacion.values,
          f['clasificacion_global'],
          Clasificacion.apto,
        ),
        mediciones: mediciones,
        parametroLimitanteId: f['parametro_limitante_id'] as int?,
        observaciones: f['observaciones'] as String? ?? '',
        sincronizada: _bool(f['sincronizada']),
        fechaSincronizacion: _fechaOpcional(f['fecha_sincronizacion']),
      );

  static Fila deMuestra(Muestra m, {bool conId = true}) => {
        if (conId) 'id': m.id,
        'punto_id': m.puntoId,
        'usuario_id': m.usuarioId,
        'fecha_hora': m.fechaHora.toIso8601String(),
        'creado_en': m.creadoEn.toIso8601String(),
        'latitud_captura': m.latitudCaptura,
        'longitud_captura': m.longitudCaptura,
        'clasificacion_global': m.clasificacionGlobal.name,
        'parametro_limitante_id': m.parametroLimitanteId,
        'observaciones': m.observaciones,
        'sincronizada': _int(m.sincronizada),
        'fecha_sincronizacion': m.fechaSincronizacion?.toIso8601String(),
      };

  static Medicion medicion(Fila f) => Medicion(
        parametroId: f['parametro_id']! as int,
        valor: (f['valor']! as num).toDouble(),
        origen: _porNombre(ViaCaptura.values, f['origen'], ViaCaptura.manual),
        clasificacion: _porNombre(
          Clasificacion.values,
          f['clasificacion'],
          Clasificacion.apto,
        ),
      );

  static Fila deMedicion(Medicion m, int muestraId) => {
        'muestra_id': muestraId,
        'parametro_id': m.parametroId,
        'valor': m.valor,
        'origen': m.origen.name,
        'clasificacion': m.clasificacion.name,
      };

  static Alerta alerta(Fila f) => Alerta(
        id: f['id']! as int,
        muestraId: f['muestra_id']! as int,
        puntoId: f['punto_id']! as int,
        tipo: f['tipo']! as String,
        detalle: f['detalle']! as String,
        fecha: _fecha(f['fecha']),
        atendida: _bool(f['atendida']),
      );

  static Fila deAlerta(Alerta a, {bool conId = true}) => {
        if (conId) 'id': a.id,
        'muestra_id': a.muestraId,
        'punto_id': a.puntoId,
        'tipo': a.tipo,
        'detalle': a.detalle,
        'fecha': a.fecha.toIso8601String(),
        'atendida': _int(a.atendida),
      };

  static RegistroAuditoria auditoria(Fila f) => RegistroAuditoria(
        id: f['id']! as int,
        fecha: _fecha(f['fecha']),
        usuarioId: f['usuario_id']! as int,
        usuarioNombre: f['usuario_nombre']! as String,
        rol: f['rol']! as String,
        accion: _porNombre(
          AccionAuditoria.values,
          f['accion'],
          AccionAuditoria.registroMuestra,
        ),
        entidadId: f['entidad_id'] as int?,
        detalle: f['detalle'] as String? ?? '',
      );
}
