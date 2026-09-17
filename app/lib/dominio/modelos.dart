enum Clasificacion {
  apto('Apto'),
  riesgo('En riesgo'),
  incumplimiento('Incumplimiento');

  const Clasificacion(this.etiqueta);
  final String etiqueta;

  int get severidad => index;

  static Clasificacion peorDe(Iterable<Clasificacion> valores) {
    var peor = Clasificacion.apto;
    for (final v in valores) {
      if (v.severidad > peor.severidad) peor = v;
    }
    return peor;
  }
}

enum ViaCaptura {
  sensor('Sensor'),
  manual('Manual');

  const ViaCaptura(this.etiqueta);
  final String etiqueta;
}

enum RolUsuario {
  operario('Operario de campo'),
  calidad('Control de calidad'),
  administrador('Administrador');

  const RolUsuario(this.etiqueta);
  final String etiqueta;
}

class Organizacion {
  const Organizacion({
    required this.id,
    required this.nombre,
    required this.nit,
    this.activa = true,
  });

  final int id;
  final String nombre;
  final String nit;
  final bool activa;
}

class Usuario {
  const Usuario({
    required this.id,
    required this.organizacionId,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.activo = true,
  });

  final int id;
  final int organizacionId;
  final String nombre;
  final String correo;
  final RolUsuario rol;
  final bool activo;

  Usuario copyCon({
    String? nombre,
    String? correo,
    RolUsuario? rol,
    bool? activo,
  }) =>
      Usuario(
        id: id,
        organizacionId: organizacionId,
        nombre: nombre ?? this.nombre,
        correo: correo ?? this.correo,
        rol: rol ?? this.rol,
        activo: activo ?? this.activo,
      );

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }
}

class Zona {
  const Zona({
    required this.id,
    required this.organizacionId,
    required this.nombre,
    this.descripcion = '',
    this.activa = true,
  });

  final int id;
  final int organizacionId;
  final String nombre;
  final String descripcion;
  final bool activa;

  Zona copyCon({String? nombre, String? descripcion, bool? activa}) => Zona(
        id: id,
        organizacionId: organizacionId,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        activa: activa ?? this.activa,
      );
}

enum TipoPunto {
  pozo('Pozo'),
  tanque('Tanque de almacenamiento'),
  linea('Linea de distribucion'),
  tratamiento('Equipo de tratamiento'),
  consumo('Punto de consumo');

  const TipoPunto(this.etiqueta);
  final String etiqueta;
}

class PuntoMuestreo {
  const PuntoMuestreo({
    required this.id,
    required this.organizacionId,
    required this.zonaId,
    required this.nombre,
    required this.tipo,
    required this.instrumentado,
    this.latitud,
    this.longitud,
  });

  final int id;
  final int organizacionId;

  final int zonaId;

  final String nombre;
  final TipoPunto tipo;

  final bool instrumentado;

  final double? latitud;
  final double? longitud;

  bool get tieneCoordenadas => latitud != null && longitud != null;

  PuntoMuestreo copyCon({
    int? zonaId,
    String? nombre,
    TipoPunto? tipo,
    bool? instrumentado,
    double? latitud,
    double? longitud,
  }) =>
      PuntoMuestreo(
        id: id,
        organizacionId: organizacionId,
        zonaId: zonaId ?? this.zonaId,
        nombre: nombre ?? this.nombre,
        tipo: tipo ?? this.tipo,
        instrumentado: instrumentado ?? this.instrumentado,
        latitud: latitud ?? this.latitud,
        longitud: longitud ?? this.longitud,
      );
}

class Dispositivo {
  const Dispositivo({
    required this.id,
    required this.puntoId,
    required this.identificador,
    required this.tipoSensor,
    required this.ultimaCalibracion,
  });

  final int id;
  final int puntoId;
  final String identificador;
  final String tipoSensor;
  final DateTime ultimaCalibracion;

  bool get calibracionVencida =>
      DateTime.now().difference(ultimaCalibracion).inDays > 90;
}

class Parametro {
  const Parametro({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.viaCaptura,
    this.limiteMin,
    this.limiteMax,
    this.alertaMin,
    this.alertaMax,
    this.critico = false,
    this.versionNorma = 'COGUANOR NTG 29001',
    this.notaIndicativa,
    required this.descripcion,
  });

  final int id;
  final String nombre;
  final String unidad;
  final ViaCaptura viaCaptura;
  final double? limiteMin;
  final double? limiteMax;
  final double? alertaMin;
  final double? alertaMax;

  final bool critico;
  final String versionNorma;

  // Se mide y se guarda, pero no alcanza para declarar cumplimiento. Con el
  // porque adentro, para que no quede uno marcado sin decir la razon.
  final String? notaIndicativa;
  bool get indicativo => notaIndicativa != null;

  final String descripcion;

  String get rangoLegible {
    if (limiteMin != null && limiteMax != null) {
      if (limiteMax == 0) return 'Ausencia';
      return '${_num(limiteMin!)} - ${_num(limiteMax!)} $unidad';
    }
    if (limiteMax != null) return '<= ${_num(limiteMax!)} $unidad';
    if (limiteMin != null) return '>= ${_num(limiteMin!)} $unidad';
    return 'Sin limite normado';
  }

  String get bandaAlertaLegible {
    if (alertaMin != null && alertaMax != null) {
      if (alertaMax == 0) return 'Ausencia';
      return '${_num(alertaMin!)} - ${_num(alertaMax!)}';
    }
    if (alertaMax != null) {
      return alertaMax == 0 ? 'Ausencia' : '<= ${_num(alertaMax!)}';
    }
    if (alertaMin != null) return '>= ${_num(alertaMin!)}';
    return 'Sin banda';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class Medicion {
  const Medicion({
    required this.parametroId,
    required this.valor,
    required this.origen,
    required this.clasificacion,
  });

  final int parametroId;
  final double valor;
  final ViaCaptura origen;
  final Clasificacion clasificacion;
}

class Muestra {
  const Muestra({
    required this.id,
    required this.puntoId,
    required this.usuarioId,
    required this.fechaHora,
    required this.creadoEn,
    this.latitudCaptura,
    this.longitudCaptura,
    required this.clasificacionGlobal,
    required this.mediciones,
    this.parametroLimitanteId,
    this.sincronizada = false,
    this.fechaSincronizacion,
    this.observaciones = '',
  });

  final int id;
  final int puntoId;
  final int usuarioId;
  final DateTime fechaHora;

  final DateTime creadoEn;

  final double? latitudCaptura;
  final double? longitudCaptura;
  final Clasificacion clasificacionGlobal;
  final List<Medicion> mediciones;

  final int? parametroLimitanteId;
  final bool sincronizada;
  final DateTime? fechaSincronizacion;
  final String observaciones;

  Muestra copyCon({int? id, bool? sincronizada, DateTime? fechaSincronizacion}) {
    return Muestra(
      id: id ?? this.id,
      puntoId: puntoId,
      usuarioId: usuarioId,
      fechaHora: fechaHora,
      creadoEn: creadoEn,
      latitudCaptura: latitudCaptura,
      longitudCaptura: longitudCaptura,
      clasificacionGlobal: clasificacionGlobal,
      mediciones: mediciones,
      parametroLimitanteId: parametroLimitanteId,
      sincronizada: sincronizada ?? this.sincronizada,
      fechaSincronizacion: fechaSincronizacion ?? this.fechaSincronizacion,
      observaciones: observaciones,
    );
  }

  Medicion? medicionDe(int parametroId) {
    for (final m in mediciones) {
      if (m.parametroId == parametroId) return m;
    }
    return null;
  }
}

class Alerta {
  const Alerta({
    required this.id,
    required this.muestraId,
    required this.puntoId,
    required this.tipo,
    required this.detalle,
    required this.fecha,
    this.atendida = false,
  });

  final int id;
  final int muestraId;
  final int puntoId;
  final String tipo;
  final String detalle;
  final DateTime fecha;
  final bool atendida;

  Alerta copyCon({bool? atendida}) => Alerta(
        id: id,
        muestraId: muestraId,
        puntoId: puntoId,
        tipo: tipo,
        detalle: detalle,
        fecha: fecha,
        atendida: atendida ?? this.atendida,
      );
}

enum AccionAuditoria {
  inicioSesion('Inicio de sesion', 'sesion'),
  sesionReanudada('Sesion reanudada', 'sesion'),
  cierreSesion('Cierre de sesion', 'sesion'),
  registroMuestra('Registro de muestra', 'muestra'),
  lecturaSensor('Lectura de sensor', 'muestra'),
  sincronizacion('Sincronizacion con el servidor', 'sistema'),
  altaZona('Alta de zona', 'zona'),
  edicionZona('Edicion de zona', 'zona'),
  bajaZona('Baja de zona', 'zona'),
  altaDispositivo('Alta de equipo', 'equipo'),
  edicionDispositivo('Edicion de equipo', 'equipo'),
  bajaDispositivo('Baja de equipo', 'equipo'),
  altaUsuario('Alta de usuario', 'usuario'),
  edicionUsuario('Edicion de usuario', 'usuario'),
  bajaUsuario('Baja de usuario', 'usuario'),
  altaPunto('Alta de punto', 'punto'),
  edicionPunto('Edicion de punto', 'punto'),
  bajaPunto('Baja de punto', 'punto'),
  atencionAlerta('Alerta atendida', 'alerta');

  const AccionAuditoria(this.etiqueta, this.entidad);
  final String etiqueta;
  final String entidad;
}

class RegistroAuditoria {
  const RegistroAuditoria({
    required this.id,
    required this.fecha,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.rol,
    required this.accion,
    this.entidadId,
    this.detalle = '',
  });

  final int id;
  final DateTime fecha;
  final int usuarioId;

  final String usuarioNombre;
  final String rol;

  final AccionAuditoria accion;
  final int? entidadId;
  final String detalle;
}
