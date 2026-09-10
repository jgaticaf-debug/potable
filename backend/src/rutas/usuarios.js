import { Router } from 'express';

import { auditar, Accion, contexto } from '../auditoria.js';
import { una } from '../bd.js';
import {
  asincrona,
  conflicto,
  invalido,
  noEncontrado,
} from '../errores.js';
import { requiereSesion, soloAdministrador } from '../middleware/auth.js';
import { hashearClave } from '../seguridad.js';

export const rutasUsuarios = Router();

rutasUsuarios.use(requiereSesion, soloAdministrador);

const ROLES = ['operario', 'calidad', 'administrador'];
const LONGITUD_MINIMA_CLAVE = 8;

const publico = (fila) => ({
  id: fila.id,
  organizacion_id: fila.organizacion_id,
  nombre: fila.nombre,
  correo: fila.correo,
  rol: fila.rol,
  activo: fila.activo,
});

function validar({ nombre, correo, rol }) {
  if (!nombre) throw invalido('El nombre es obligatorio.');
  if (!correo.includes('@')) throw invalido('Ingrese un correo valido.');
  if (!ROLES.includes(rol)) throw invalido('El rol indicado no existe.');
}

rutasUsuarios.post(
  '/',
  asincrona(async (req, res) => {
    const nombre = String(req.body?.nombre ?? '').trim();
    const correo = String(req.body?.correo ?? '').trim().toLowerCase();
    const rol = req.body?.rol ?? 'operario';
    const clave = String(req.body?.clave ?? '');

    validar({ nombre, correo, rol });
    if (clave.length < LONGITUD_MINIMA_CLAVE) {
      throw invalido(
        `La contrasena debe tener al menos ${LONGITUD_MINIMA_CLAVE} caracteres.`,
      );
    }

    const fila = await una(
      `INSERT INTO usuarios
         (organizacion_id, nombre, correo, clave_hash, rol, activo)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, organizacion_id, nombre, correo, rol, activo`,
      [
        req.usuario.organizacionId,
        nombre,
        correo,
        hashearClave(clave),
        rol,
        req.body?.activo ?? true,
      ],
    );

    await auditar(contexto(req), Accion.altaUsuario, {
      entidadId: fila.id,
      detalle: `${fila.nombre} (${fila.rol})`,
    });
    res.status(201).json(publico(fila));
  }),
);

rutasUsuarios.put(
  '/:id',
  asincrona(async (req, res) => {
    const nombre = String(req.body?.nombre ?? '').trim();
    const correo = String(req.body?.correo ?? '').trim().toLowerCase();
    const rol = req.body?.rol ?? 'operario';
    const clave = String(req.body?.clave ?? '');

    validar({ nombre, correo, rol });

    if (clave && clave.length < LONGITUD_MINIMA_CLAVE) {
      throw invalido(
        `La contrasena debe tener al menos ${LONGITUD_MINIMA_CLAVE} caracteres.`,
      );
    }

    const esUstedMismo = Number(req.params.id) === req.usuario.id;
    if (esUstedMismo && req.body?.activo === false) {
      throw conflicto('No puede desactivar su propia cuenta.');
    }
    if (esUstedMismo && rol !== 'administrador') {
      throw conflicto(
        'No puede quitarse a si mismo el rol de administrador: quedaria sin '
          + 'poder revertirlo.',
      );
    }

    const fila = await una(
      `UPDATE usuarios
       SET nombre = $1,
           correo = $2,
           rol = $3,
           activo = $4,
           clave_hash = COALESCE($5, clave_hash)
       WHERE id = $6 AND organizacion_id = $7
       RETURNING id, organizacion_id, nombre, correo, rol, activo`,
      [
        nombre,
        correo,
        rol,
        req.body?.activo ?? true,
        clave ? hashearClave(clave) : null,
        req.params.id,
        req.usuario.organizacionId,
      ],
    );
    if (!fila) throw noEncontrado('El usuario no existe.');

    await auditar(contexto(req), Accion.edicionUsuario, {
      entidadId: fila.id,
      detalle: `${fila.nombre} (${fila.rol})`,
    });
    res.json(publico(fila));
  }),
);

rutasUsuarios.delete(
  '/:id',
  asincrona(async (req, res) => {
    if (Number(req.params.id) === req.usuario.id) {
      throw conflicto('No puede eliminar su propia cuenta.');
    }

    const muestras = await una(
      'SELECT COUNT(*)::int AS total FROM muestras WHERE usuario_id = $1',
      [req.params.id],
    );
    if (muestras.total > 0) {
      throw conflicto(
        `Tiene ${muestras.total} muestra(s) registradas. Desactive la cuenta ` +
          'en vez de eliminarla, para no perder la trazabilidad.',
      );
    }

    const fila = await una(
      `DELETE FROM usuarios WHERE id = $1 AND organizacion_id = $2
       RETURNING nombre`,
      [req.params.id, req.usuario.organizacionId],
    );
    if (!fila) throw noEncontrado('El usuario no existe.');

    await auditar(contexto(req), Accion.bajaUsuario, {
      entidadId: Number(req.params.id),
      detalle: fila.nombre,
    });
    res.status(204).end();
  }),
);
