import type { Clasificacion, Parametro } from '../api/tipos';

export const numero = (v: string | number | null | undefined): number =>
  typeof v === 'number' ? v : Number(v ?? 0);

export function fecha(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${d.getFullYear()} ${hh}:${mi}`;
}

export const CLASIFICACION: Record<Clasificacion, string> = {
  apto: 'Apto',
  riesgo: 'En riesgo',
  incumplimiento: 'Incumple',
};

// Los limites vienen sueltos y cualquiera de los dos puede faltar: hay
// parametros con solo maximo, como turbidez o coliformes.
export function rango(p: Parametro): string {
  const { limite_min: min, limite_max: max } = p;
  // Coliformes tiene min y max en cero: la norma pide ausencia, no un rango.
  if (min !== null && max !== null && min === max) {
    return `Debe ser ${max} ${p.unidad}`;
  }
  if (min !== null && max !== null) return `${min} – ${max} ${p.unidad}`;
  if (max !== null) return `Máx. ${max} ${p.unidad}`;
  if (min !== null) return `Mín. ${min} ${p.unidad}`;
  return 'Sin límite normado';
}

const ACCIONES: Record<string, string> = {
  inicioSesion: 'Inicio de sesion',
  sesionReanudada: 'Sesion reanudada',
  cierreSesion: 'Cierre de sesion',
  registroMuestra: 'Registro de muestra',
  sincronizacion: 'Sincronizacion',
  altaZona: 'Alta de zona',
  edicionZona: 'Edicion de zona',
  bajaZona: 'Baja de zona',
  altaPunto: 'Alta de punto',
  edicionPunto: 'Edicion de punto',
  bajaPunto: 'Baja de punto',
  altaUsuario: 'Alta de usuario',
  edicionUsuario: 'Edicion de usuario',
  bajaUsuario: 'Baja de usuario',
  altaDispositivo: 'Alta de equipo',
  edicionDispositivo: 'Edicion de equipo',
  bajaDispositivo: 'Baja de equipo',
  atencionAlerta: 'Atencion de alerta',
};

export const accion = (clave: string) => ACCIONES[clave] ?? clave;
