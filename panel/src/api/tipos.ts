export type Rol = 'operario' | 'calidad' | 'administrador';
export type TipoPunto =
  | 'pozo'
  | 'tanque'
  | 'linea'
  | 'tratamiento'
  | 'consumo';
export type ViaCaptura = 'manual' | 'sensor';
export type Clasificacion = 'apto' | 'riesgo' | 'incumplimiento';

export interface Usuario {
  id: number;
  organizacion_id: number;
  nombre: string;
  correo: string;
  rol: Rol;
  activo: boolean;
}

export interface Organizacion {
  id: number;
  nombre: string;
  nit: string;
  activa: boolean;
}

export interface Zona {
  id: number;
  organizacion_id: number;
  nombre: string;
  descripcion: string;
  activa: boolean;
}

export interface Punto {
  id: number;
  organizacion_id: number;
  zona_id: number;
  nombre: string;
  tipo: TipoPunto;
  instrumentado: boolean;
  latitud: number | null;
  longitud: number | null;
}

export interface Dispositivo {
  id: number;
  punto_id: number;
  identificador: string;
  tipo_sensor: string;
  ultima_calibracion: string;
}

export interface Parametro {
  id: number;
  nombre: string;
  unidad: string;
  via_captura: ViaCaptura;
  limite_min: number | null;
  limite_max: number | null;
  alerta_min: number | null;
  alerta_max: number | null;
  critico: boolean;
  version_norma: string;
  // Con texto, el parametro se mide y se guarda pero no decide. Turbidez.
  nota_indicativa: string | null;
  descripcion: string;
}

export interface Medicion {
  muestra_id: number;
  parametro_id: number;
  valor: string | number;
  origen: ViaCaptura;
  clasificacion: Clasificacion;
}

export interface Muestra {
  id: number;
  punto_id: number;
  usuario_id: number;
  parametro_limitante_id: number | null;
  fecha_hora: string;
  creado_en: string;
  recibido_en: string;
  latitud_captura: number | null;
  longitud_captura: number | null;
  clasificacion_global: Clasificacion;
  observaciones: string;
  mediciones: Medicion[];
}

export interface Alerta {
  id: number;
  muestra_id: number;
  punto_id: number;
  tipo: Clasificacion;
  detalle: string;
  fecha: string;
  atendida: boolean;
}

export interface RegistroAuditoria {
  id: number;
  fecha: string;
  usuario_id: number;
  usuario_nombre: string;
  rol: Rol;
  accion: string;
  entidad_id: number | null;
  detalle: string;
}

export interface RespuestaLogin {
  token: string;
  tipo: string;
  expira_en: number;
  usuario: Usuario;
}
