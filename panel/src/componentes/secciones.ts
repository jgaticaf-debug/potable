import type { Rol } from '../api/tipos';

export interface Seccion {
  ruta: string;
  texto: string;
  soloAdmin: boolean;
}

export const SECCIONES: Seccion[] = [
  { ruta: '/muestras', texto: 'Muestras', soloAdmin: false },
  { ruta: '/alertas', texto: 'Alertas', soloAdmin: false },
  { ruta: '/zonas', texto: 'Zonas', soloAdmin: false },
  { ruta: '/puntos', texto: 'Puntos de muestreo', soloAdmin: false },
  { ruta: '/usuarios', texto: 'Usuarios', soloAdmin: true },
  { ruta: '/bitacora', texto: 'Bitacora', soloAdmin: false },
];

// El menu, las rutas y el redirect de arranque leen todos esto. Si no, a
// calidad lo mandaba a Usuarios, que es la unica pantalla que no puede ver.
export const seccionesDe = (rol: Rol | undefined): Seccion[] =>
  SECCIONES.filter((s) => !s.soloAdmin || rol === 'administrador');
