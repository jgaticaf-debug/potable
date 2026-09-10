import { noAutorizado, prohibido } from '../errores.js';
import { verificarToken } from '../seguridad.js';
import { estaRevocado } from '../sesiones.js';

export function requiereSesion(req, res, next) {
  const encabezado = req.get('authorization') ?? '';
  if (!encabezado.startsWith('Bearer ')) {
    return next(noAutorizado('Falta el encabezado Authorization.'));
  }

  const token = encabezado.slice(7).trim();

  const reclamos = verificarToken(token);
  if (!reclamos) {
    return next(noAutorizado('La sesion expiro o el token no es valido.'));
  }

  if (estaRevocado(token)) {
    return next(noAutorizado('La sesion fue cerrada.'));
  }

  req.usuario = {
    id: reclamos.sub,
    correo: reclamos.correo,
    nombre: reclamos.nombre,
    rol: reclamos.rol,
    organizacionId: reclamos.org,
  };
  return next();
}

export const requiereRol =
  (...roles) =>
  (req, res, next) =>
    roles.includes(req.usuario?.rol) ? next() : next(prohibido());

export const soloAdministrador = requiereRol('administrador');

export const puedeCapturar = requiereRol('operario', 'administrador');
