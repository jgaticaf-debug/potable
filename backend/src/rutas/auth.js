import { Router } from 'express';

import { auditar, Accion, contexto } from '../auditoria.js';
import { una } from '../bd.js';
import {
  asincrona,
  ErrorHttp,
  invalido,
  noAutorizado,
  prohibido,
} from '../errores.js';
import { requiereSesion } from '../middleware/auth.js';
import { firmarToken, verificarClave, vigenciaSegundos } from '../seguridad.js';
import {
  estaBloqueado,
  limpiarIntentos,
  minutosDeBloqueo,
  registrarIntentoFallido,
  revocar,
} from '../sesiones.js';

export const rutasAuth = Router();

rutasAuth.post(
  '/login',
  asincrona(async (req, res) => {
    const correo = String(req.body?.correo ?? '').trim().toLowerCase();
    const clave = String(req.body?.clave ?? '');

    if (!correo || !clave) {
      throw invalido('Correo y contrasena son obligatorios.');
    }

    // Limite por origen + correo. Solo por IP dejaria fuera a toda una
    // oficina que comparte salida a internet.
    const clavelimite = `${req.ip}|${correo}`;
    if (estaBloqueado(clavelimite)) {
      throw new ErrorHttp(
        429,
        `Demasiados intentos fallidos. Espere ${minutosDeBloqueo()} minutos.`,
      );
    }

    const cuenta = await una(
      `SELECT id, organizacion_id, nombre, correo, clave_hash, rol, activo
       FROM usuarios WHERE correo = $1`,
      [correo],
    );

    // Mismo mensaje si el correo no existe o si la clave esta mal.
    // Distinguirlos le diria a quien prueba cuales correos son validos.
    if (!cuenta || !verificarClave(clave, cuenta.clave_hash)) {
      registrarIntentoFallido(clavelimite);
      throw noAutorizado('Correo o contrasena incorrectos.');
    }
    if (!cuenta.activo) {
      throw prohibido('La cuenta esta desactivada. Consulte al administrador.');
    }

    limpiarIntentos(clavelimite);

    const token = firmarToken({
      sub: cuenta.id,
      correo: cuenta.correo,
      nombre: cuenta.nombre,
      rol: cuenta.rol,
      org: cuenta.organizacion_id,
    });

    const usuario = {
      id: cuenta.id,
      nombre: cuenta.nombre,
      correo: cuenta.correo,
      rol: cuenta.rol,
      organizacion_id: cuenta.organizacion_id,
    };

    await auditar({ usuario: { ...usuario, rol: cuenta.rol }, ip: req.ip },
      Accion.inicioSesion, { detalle: cuenta.correo });

    res.json({
      token,
      tipo: 'Bearer',
      expira_en: vigenciaSegundos(),
      usuario,
    });
  }),
);

rutasAuth.get(
  '/perfil',
  requiereSesion,
  asincrona(async (req, res) => {
    const cuenta = await una(
      `SELECT id, organizacion_id, nombre, correo, rol, activo
       FROM usuarios WHERE id = $1`,
      [req.usuario.id],
    );

    if (!cuenta || !cuenta.activo) {
      throw noAutorizado('La cuenta ya no esta activa.');
    }

    res.json({
      id: cuenta.id,
      nombre: cuenta.nombre,
      correo: cuenta.correo,
      rol: cuenta.rol,
      organizacion_id: cuenta.organizacion_id,
    });
  }),
);

rutasAuth.post(
  '/logout',
  requiereSesion,
  asincrona(async (req, res) => {
    const encabezado = req.get('authorization') ?? '';
    if (encabezado.startsWith('Bearer ')) {
      revocar(encabezado.slice(7).trim());
    }

    await auditar(contexto(req), Accion.cierreSesion);
    res.status(204).end();
  }),
);
