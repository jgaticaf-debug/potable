import crypto from 'node:crypto';

import { verificarToken } from './seguridad.js';

const revocados = new Map();

const huella = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

// Un JWT vale hasta que vence, aunque el usuario cierre sesion. Esta
// lista corta esa ventana.
export function revocar(token) {
  const reclamos = verificarToken(token);
  if (!reclamos?.exp) return;
  revocados.set(huella(token), reclamos.exp * 1000);
}

export function estaRevocado(token) {
  limpiar();
  return revocados.has(huella(token));
}

function limpiar() {
  const ahora = Date.now();
  for (const [clave, vence] of revocados) {
    if (vence <= ahora) revocados.delete(clave);
  }
}

export const totalRevocados = () => revocados.size;

const intentos = new Map();

const VENTANA_MS = 15 * 60 * 1000;
const MAXIMO = 8;

export function registrarIntentoFallido(clave) {
  const ahora = Date.now();
  const previo = intentos.get(clave);

  if (!previo || ahora - previo.desde > VENTANA_MS) {
    intentos.set(clave, { desde: ahora, veces: 1 });
    return;
  }
  previo.veces += 1;
}

export function limpiarIntentos(clave) {
  intentos.delete(clave);
}

export function estaBloqueado(clave) {
  const previo = intentos.get(clave);
  if (!previo) return false;

  if (Date.now() - previo.desde > VENTANA_MS) {
    intentos.delete(clave);
    return false;
  }
  return previo.veces >= MAXIMO;
}

export const minutosDeBloqueo = () => Math.round(VENTANA_MS / 60000);

export function reiniciarParaPruebas() {
  revocados.clear();
  intentos.clear();
}
