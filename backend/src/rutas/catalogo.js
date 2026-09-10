import { Router } from 'express';

import { auditar, Accion, contexto } from '../auditoria.js';
import { consultar, todas, una } from '../bd.js';
import {
  asincrona,
  conflicto,
  invalido,
  noEncontrado,
} from '../errores.js';
import { requiereSesion, soloAdministrador } from '../middleware/auth.js';

export const rutasCatalogo = Router();

rutasCatalogo.use(requiereSesion);

const org = (req) => req.usuario.organizacionId;

const texto = (v) => String(v ?? '').trim();
const numeroOpcional = (v) => {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

rutasCatalogo.get(
  '/parametros',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT id, nombre, unidad, via_captura, limite_min, limite_max,
                alerta_min, alerta_max, critico, version_norma, descripcion
         FROM parametros ORDER BY id`,
      ),
    );
  }),
);

rutasCatalogo.get(
  '/organizacion',
  asincrona(async (req, res) => {
    const fila = await una(
      'SELECT id, nombre, nit, activa FROM organizaciones WHERE id = $1',
      [org(req)],
    );
    if (!fila) throw noEncontrado('La organizacion no existe.');
    res.json(fila);
  }),
);

rutasCatalogo.get(
  '/zonas',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT id, organizacion_id, nombre, descripcion, activa
         FROM zonas WHERE organizacion_id = $1 ORDER BY nombre`,
        [org(req)],
      ),
    );
  }),
);

rutasCatalogo.post(
  '/zonas',
  soloAdministrador,
  asincrona(async (req, res) => {
    const nombre = texto(req.body?.nombre);
    if (!nombre) throw invalido('El nombre de la zona es obligatorio.');

    const fila = await una(
      `INSERT INTO zonas (organizacion_id, nombre, descripcion, activa)
       VALUES ($1, $2, $3, $4)
       RETURNING id, organizacion_id, nombre, descripcion, activa`,
      [org(req), nombre, texto(req.body?.descripcion), req.body?.activa ?? true],
    );

    await auditar(contexto(req), Accion.altaZona, {
      entidadId: fila.id,
      detalle: fila.nombre,
    });
    res.status(201).json(fila);
  }),
);

rutasCatalogo.put(
  '/zonas/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const nombre = texto(req.body?.nombre);
    if (!nombre) throw invalido('El nombre de la zona es obligatorio.');

    const fila = await una(
      `UPDATE zonas SET nombre = $1, descripcion = $2, activa = $3
       WHERE id = $4 AND organizacion_id = $5
       RETURNING id, organizacion_id, nombre, descripcion, activa`,
      [
        nombre,
        texto(req.body?.descripcion),
        req.body?.activa ?? true,
        req.params.id,
        org(req),
      ],
    );
    if (!fila) throw noEncontrado('La zona no existe.');

    await auditar(contexto(req), Accion.edicionZona, {
      entidadId: fila.id,
      detalle: fila.nombre,
    });
    res.json(fila);
  }),
);

rutasCatalogo.delete(
  '/zonas/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const puntos = await una(
      'SELECT COUNT(*)::int AS total FROM puntos WHERE zona_id = $1',
      [req.params.id],
    );
    if (puntos.total > 0) {
      throw conflicto(
        `La zona tiene ${puntos.total} punto(s) asignados. Muevalos o ` +
          'eliminelos primero.',
      );
    }

    const fila = await una(
      `DELETE FROM zonas WHERE id = $1 AND organizacion_id = $2
       RETURNING nombre`,
      [req.params.id, org(req)],
    );
    if (!fila) throw noEncontrado('La zona no existe.');

    await auditar(contexto(req), Accion.bajaZona, {
      entidadId: Number(req.params.id),
      detalle: fila.nombre,
    });
    res.status(204).end();
  }),
);

rutasCatalogo.get(
  '/puntos',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT id, organizacion_id, zona_id, nombre, tipo, instrumentado,
                latitud, longitud
         FROM puntos WHERE organizacion_id = $1 ORDER BY zona_id, nombre`,
        [org(req)],
      ),
    );
  }),
);

rutasCatalogo.post(
  '/puntos',
  soloAdministrador,
  asincrona(async (req, res) => {
    const nombre = texto(req.body?.nombre);
    if (!nombre) throw invalido('El nombre del punto es obligatorio.');

    const zona = await una(
      'SELECT id FROM zonas WHERE id = $1 AND organizacion_id = $2',
      [req.body?.zona_id, org(req)],
    );
    if (!zona) throw invalido('La zona indicada no existe.');

    const fila = await una(
      `INSERT INTO puntos
         (organizacion_id, zona_id, nombre, tipo, instrumentado,
          latitud, longitud)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, organizacion_id, zona_id, nombre, tipo, instrumentado,
                 latitud, longitud`,
      [
        org(req),
        req.body.zona_id,
        nombre,
        req.body?.tipo ?? 'pozo',
        req.body?.instrumentado ?? false,
        numeroOpcional(req.body?.latitud),
        numeroOpcional(req.body?.longitud),
      ],
    );

    await auditar(contexto(req), Accion.altaPunto, {
      entidadId: fila.id,
      detalle: fila.nombre,
    });
    res.status(201).json(fila);
  }),
);

rutasCatalogo.put(
  '/puntos/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const nombre = texto(req.body?.nombre);
    if (!nombre) throw invalido('El nombre del punto es obligatorio.');

    const fila = await una(
      `UPDATE puntos
       SET zona_id = $1, nombre = $2, tipo = $3, instrumentado = $4,
           latitud = $5, longitud = $6
       WHERE id = $7 AND organizacion_id = $8
       RETURNING id, organizacion_id, zona_id, nombre, tipo, instrumentado,
                 latitud, longitud`,
      [
        req.body?.zona_id,
        nombre,
        req.body?.tipo ?? 'pozo',
        req.body?.instrumentado ?? false,
        numeroOpcional(req.body?.latitud),
        numeroOpcional(req.body?.longitud),
        req.params.id,
        org(req),
      ],
    );
    if (!fila) throw noEncontrado('El punto no existe.');

    await auditar(contexto(req), Accion.edicionPunto, {
      entidadId: fila.id,
      detalle: fila.nombre,
    });
    res.json(fila);
  }),
);

rutasCatalogo.delete(
  '/puntos/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const muestras = await una(
      'SELECT COUNT(*)::int AS total FROM muestras WHERE punto_id = $1',
      [req.params.id],
    );
    if (muestras.total > 0) {
      throw conflicto(
        `El punto tiene ${muestras.total} muestra(s) registradas y no puede ` +
          'eliminarse.',
      );
    }

    const fila = await una(
      `DELETE FROM puntos WHERE id = $1 AND organizacion_id = $2
       RETURNING nombre`,
      [req.params.id, org(req)],
    );
    if (!fila) throw noEncontrado('El punto no existe.');

    await auditar(contexto(req), Accion.bajaPunto, {
      entidadId: Number(req.params.id),
      detalle: fila.nombre,
    });
    res.status(204).end();
  }),
);

rutasCatalogo.get(
  '/dispositivos',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT d.id, d.punto_id, d.identificador, d.tipo_sensor,
                d.ultima_calibracion
         FROM dispositivos d
         JOIN puntos p ON p.id = d.punto_id
         WHERE p.organizacion_id = $1
         ORDER BY d.identificador`,
        [org(req)],
      ),
    );
  }),
);

rutasCatalogo.post(
  '/dispositivos',
  soloAdministrador,
  asincrona(async (req, res) => {
    const identificador = texto(req.body?.identificador);
    if (!identificador) throw invalido('El codigo del equipo es obligatorio.');

    const fila = await una(
      `INSERT INTO dispositivos
         (punto_id, identificador, tipo_sensor, ultima_calibracion)
       VALUES ($1, $2, $3, $4)
       RETURNING id, punto_id, identificador, tipo_sensor, ultima_calibracion`,
      [
        req.body?.punto_id,
        identificador,
        texto(req.body?.tipo_sensor),
        req.body?.ultima_calibracion ?? new Date().toISOString().slice(0, 10),
      ],
    );

    await auditar(contexto(req), Accion.altaDispositivo, {
      entidadId: fila.id,
      detalle: fila.identificador,
    });
    res.status(201).json(fila);
  }),
);

rutasCatalogo.put(
  '/dispositivos/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const fila = await una(
      `UPDATE dispositivos
       SET punto_id = $1, identificador = $2, tipo_sensor = $3,
           ultima_calibracion = $4
       WHERE id = $5
       RETURNING id, punto_id, identificador, tipo_sensor, ultima_calibracion`,
      [
        req.body?.punto_id,
        texto(req.body?.identificador),
        texto(req.body?.tipo_sensor),
        req.body?.ultima_calibracion,
        req.params.id,
      ],
    );
    if (!fila) throw noEncontrado('El dispositivo no existe.');

    await auditar(contexto(req), Accion.edicionDispositivo, {
      entidadId: fila.id,
      detalle: fila.identificador,
    });
    res.json(fila);
  }),
);

rutasCatalogo.delete(
  '/dispositivos/:id',
  soloAdministrador,
  asincrona(async (req, res) => {
    const fila = await una(
      'DELETE FROM dispositivos WHERE id = $1 RETURNING identificador',
      [req.params.id],
    );
    if (!fila) throw noEncontrado('El dispositivo no existe.');

    await auditar(contexto(req), Accion.bajaDispositivo, {
      entidadId: Number(req.params.id),
      detalle: fila.identificador,
    });
    res.status(204).end();
  }),
);

rutasCatalogo.get(
  '/usuarios',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT id, organizacion_id, nombre, correo, rol, activo
         FROM usuarios WHERE organizacion_id = $1 ORDER BY nombre`,
        [org(req)],
      ),
    );
  }),
);

rutasCatalogo.get(
  '/auditoria',
  asincrona(async (req, res) => {
    const limite = Math.min(Number(req.query.limite) || 200, 1000);
    res.json(
      await todas(
        `SELECT id, fecha, usuario_id, usuario_nombre, rol, accion,
                entidad_id, detalle
         FROM auditoria ORDER BY fecha DESC, id DESC LIMIT $1`,
        [limite],
      ),
    );
  }),
);
