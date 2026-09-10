import type {
  Alerta,
  Dispositivo,
  Muestra,
  Organizacion,
  Parametro,
  Punto,
  RegistroAuditoria,
  RespuestaLogin,
  Usuario,
  Zona,
} from './tipos';

const BASE = (import.meta.env.VITE_API_URL ?? 'http://localhost:3000').replace(
  /\/+$/,
  '',
);

const LLAVE_TOKEN = 'potable.token';

export class ErrorApi extends Error {
  constructor(
    readonly estado: number,
    mensaje: string,
  ) {
    super(mensaje);
  }
}

export class SesionExpirada extends ErrorApi {
  constructor(mensaje: string) {
    super(401, mensaje);
  }
}

export class SinConexion extends Error {}

let token: string | null = localStorage.getItem(LLAVE_TOKEN);
let alExpirar: (() => void) | null = null;

export function guardarToken(nuevo: string | null) {
  token = nuevo;
  if (nuevo) localStorage.setItem(LLAVE_TOKEN, nuevo);
  else localStorage.removeItem(LLAVE_TOKEN);
}

export const hayToken = () => token !== null;

export function alPerderSesion(accion: () => void) {
  alExpirar = accion;
}

type Metodo = 'GET' | 'POST' | 'PUT' | 'DELETE';

async function pedir<T>(
  metodo: Metodo,
  ruta: string,
  cuerpo?: unknown,
): Promise<T> {
  let respuesta: Response;

  try {
    respuesta = await fetch(`${BASE}${ruta}`, {
      method: metodo,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });
  } catch {
    throw new SinConexion(
      `No se pudo contactar el servidor en ${BASE}. Revise que este arriba.`,
    );
  }

  const texto = await respuesta.text();
  const datos = texto.trim() ? JSON.parse(texto) : null;

  if (respuesta.ok) return datos as T;

  const mensaje =
    (datos && typeof datos === 'object' && 'mensaje' in datos
      ? String(datos.mensaje)
      : null) ?? `Error ${respuesta.status}`;

  // Un 401 fuera del login siempre es sesion vencida o revocada. Aviso al
  // contexto para que saque al usuario en vez de dejar la pantalla trabada.
  if (respuesta.status === 401) {
    guardarToken(null);
    alExpirar?.();
    throw new SesionExpirada(mensaje);
  }

  throw new ErrorApi(respuesta.status, mensaje);
}

export const api = {
  async login(correo: string, clave: string): Promise<RespuestaLogin> {
    const datos = await pedir<RespuestaLogin>('POST', '/auth/login', {
      correo,
      clave,
    });
    guardarToken(datos.token);
    return datos;
  },

  async logout(): Promise<void> {
    try {
      await pedir<void>('POST', '/auth/logout');
    } catch {
      // Si el servidor no responde igual cierro de este lado.
    } finally {
      guardarToken(null);
    }
  },

  perfil: () => pedir<Usuario>('GET', '/auth/perfil'),
  organizacion: () => pedir<Organizacion>('GET', '/organizacion'),
  parametros: () => pedir<Parametro[]>('GET', '/parametros'),

  usuarios: () => pedir<Usuario[]>('GET', '/usuarios'),
  crearUsuario: (u: Partial<Usuario> & { clave: string }) =>
    pedir<Usuario>('POST', '/usuarios', u),
  editarUsuario: (id: number, u: Partial<Usuario> & { clave?: string }) =>
    pedir<Usuario>('PUT', `/usuarios/${id}`, u),
  eliminarUsuario: (id: number) => pedir<void>('DELETE', `/usuarios/${id}`),

  zonas: () => pedir<Zona[]>('GET', '/zonas'),
  crearZona: (z: Partial<Zona>) => pedir<Zona>('POST', '/zonas', z),
  editarZona: (id: number, z: Partial<Zona>) =>
    pedir<Zona>('PUT', `/zonas/${id}`, z),
  eliminarZona: (id: number) => pedir<void>('DELETE', `/zonas/${id}`),

  puntos: () => pedir<Punto[]>('GET', '/puntos'),
  crearPunto: (p: Partial<Punto>) => pedir<Punto>('POST', '/puntos', p),
  editarPunto: (id: number, p: Partial<Punto>) =>
    pedir<Punto>('PUT', `/puntos/${id}`, p),
  eliminarPunto: (id: number) => pedir<void>('DELETE', `/puntos/${id}`),

  dispositivos: () => pedir<Dispositivo[]>('GET', '/dispositivos'),
  crearDispositivo: (d: Partial<Dispositivo>) =>
    pedir<Dispositivo>('POST', '/dispositivos', d),
  editarDispositivo: (id: number, d: Partial<Dispositivo>) =>
    pedir<Dispositivo>('PUT', `/dispositivos/${id}`, d),
  eliminarDispositivo: (id: number) =>
    pedir<void>('DELETE', `/dispositivos/${id}`),

  muestras: (limite = 500) =>
    pedir<Muestra[]>('GET', `/muestras?limite=${limite}`),
  alertas: () => pedir<Alerta[]>('GET', '/alertas'),
  atenderAlerta: (id: number) =>
    pedir<void>('POST', `/alertas/${id}/atender`),
  auditoria: (limite = 200) =>
    pedir<RegistroAuditoria[]>('GET', `/auditoria?limite=${limite}`),
};
