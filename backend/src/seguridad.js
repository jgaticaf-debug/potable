import crypto from 'node:crypto';

import jwt from 'jsonwebtoken';

import { config } from './config.js';

const ALGORITMO = 'pbkdf2_sha256';
const LONGITUD_SAL = 16;
const LONGITUD_CLAVE = 32;
const DIGEST = 'sha256';

function derivar(clave, sal, iteraciones) {
  // La sal va decodificada a bytes, igual que en Dart. Si se pasa como
  // texto los hashes no coinciden entre los dos lados.
  const salBytes = Buffer.from(sal, 'base64url');
  return crypto
    .pbkdf2Sync(clave, salBytes, iteraciones, LONGITUD_CLAVE, DIGEST)
    .toString('base64url');
}

export function hashearClave(clave) {
  const iteraciones = config.pbkdf2Iteraciones;
  const sal = crypto.randomBytes(LONGITUD_SAL).toString('base64url');
  return `${ALGORITMO}$${iteraciones}$${sal}$${derivar(clave, sal, iteraciones)}`;
}

export function verificarClave(clave, almacenado) {
  const partes = String(almacenado ?? '').split('$');
  if (partes.length !== 4 || partes[0] !== ALGORITMO) return false;

  const iteraciones = Number.parseInt(partes[1], 10);
  if (!Number.isFinite(iteraciones) || iteraciones < 1) return false;

  const esperado = Buffer.from(partes[3]);
  const obtenido = Buffer.from(derivar(clave, partes[2], iteraciones));

  if (esperado.length !== obtenido.length) return false;
  return crypto.timingSafeEqual(esperado, obtenido);
}

export function firmarToken(reclamos) {
  // El jti hace unico cada token. Sin el, dos logins del mismo usuario
  // en el mismo segundo salen identicos y revocar uno revoca los dos.
  return jwt.sign({ ...reclamos, jti: crypto.randomUUID() }, config.jwt.secreto, {
    algorithm: 'HS256',
    expiresIn: `${config.jwt.vigenciaHoras}h`,
  });
}

export function verificarToken(token) {
  try {
    return jwt.verify(token, config.jwt.secreto, { algorithms: ['HS256'] });
  } catch {
    return null;
  }
}

export const vigenciaSegundos = () => config.jwt.vigenciaHoras * 3600;
