import { Router } from 'express';

import { auditar, Accion, contexto } from '../auditoria.js';
import { enTransaccion, todas, una } from '../bd.js';
import { asincrona, invalido, noEncontrado } from '../errores.js';
import { puedeCapturar, requiereSesion } from '../middleware/auth.js';

export const rutasMuestras = Router();

rutasMuestras.use(requiereSesion);

const org = (req) => req.usuario.organizacionId;

rutasMuestras.get(
  '/muestras',
  asincrona(async (req, res) => {
    const limite = Math.min(Number(req.query.limite) || 500, 5000);

    const muestras = await todas(
      `SELECT m.id, m.punto_id, m.usuario_id, m.parametro_limitante_id,
              m.fecha_hora, m.creado_en, m.recibido_en,
              m.latitud_captura, m.longitud_captura,
              m.clasificacion_global, m.observaciones
       FROM muestras m
       JOIN puntos p ON p.id = m.punto_id
       WHERE p.organizacion_id = $1
       ORDER BY m.fecha_hora DESC
       LIMIT $2`,
      [org(req), limite],
    );

    if (muestras.length === 0) return res.json([]);

    const mediciones = await todas(
      `SELECT muestra_id, parametro_id, valor, origen, clasificacion
       FROM mediciones WHERE muestra_id = ANY($1::bigint[])`,
      [muestras.map((m) => m.id)],
    );

    const porMuestra = new Map();
    for (const med of mediciones) {
      const lista = porMuestra.get(med.muestra_id) ?? [];
      lista.push(med);
      porMuestra.set(med.muestra_id, lista);
    }

    res.json(
      muestras.map((m) => ({
        ...m,
        mediciones: porMuestra.get(m.id) ?? [],
      })),
    );
  }),
);

function validarMuestra(cruda, indice) {
  const faltan = [];
  if (!cruda?.punto_id) faltan.push('punto_id');
  if (!cruda?.fecha_hora) faltan.push('fecha_hora');
  if (!cruda?.clasificacion_global) faltan.push('clasificacion_global');
  if (!Array.isArray(cruda?.mediciones) || cruda.mediciones.length === 0) {
    faltan.push('mediciones');
  }
  if (faltan.length > 0) {
    throw invalido(
      `La muestra ${indice + 1} viene incompleta: falta ${faltan.join(', ')}.`,
    );
  }
}

rutasMuestras.post(
  '/sincronizacion',
  puedeCapturar,
  asincrona(async (req, res) => {
    const entrantes = req.body?.muestras;
    if (!Array.isArray(entrantes)) {
      throw invalido('Se esperaba un arreglo en el campo "muestras".');
    }
    entrantes.forEach(validarMuestra);

    const resultado = await enTransaccion(async (cliente) => {
      const aceptadas = [];
      const repetidas = [];

      for (const cruda of entrantes) {
        const punto = await cliente.query(
          'SELECT id FROM puntos WHERE id = $1 AND organizacion_id = $2',
          [cruda.punto_id, org(req)],
        );
        if (punto.rows.length === 0) {
          throw invalido(
            `El punto ${cruda.punto_id} no pertenece a su organizacion.`,
          );
        }

        // ON CONFLICT: si se corta la red despues de guardar pero antes de
        // responder, el reintento no duplica la muestra.
        const insercion = await cliente.query(
          `INSERT INTO muestras
             (punto_id, usuario_id, parametro_limitante_id, fecha_hora,
              creado_en, latitud_captura, longitud_captura,
              clasificacion_global, observaciones, id_local)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (usuario_id, id_local) DO NOTHING
           RETURNING id`,
          [
            cruda.punto_id,
            req.usuario.id,
            cruda.parametro_limitante_id ?? null,
            cruda.fecha_hora,
            cruda.creado_en ?? cruda.fecha_hora,
            cruda.latitud_captura ?? null,
            cruda.longitud_captura ?? null,
            cruda.clasificacion_global,
            cruda.observaciones ?? '',
            cruda.id_local ?? null,
          ],
        );

        if (insercion.rows.length === 0) {
          repetidas.push(cruda.id_local);
          continue;
        }

        const id = insercion.rows[0].id;

        for (const med of cruda.mediciones) {
          await cliente.query(
            `INSERT INTO mediciones
               (muestra_id, parametro_id, valor, origen, clasificacion)
             VALUES ($1, $2, $3, $4, $5)`,
            [
              id,
              med.parametro_id,
              med.valor,
              med.origen ?? 'manual',
              med.clasificacion,
            ],
          );
        }

        // La alerta la levanta el servidor, no el telefono: asi la regla
        // vive en un solo lugar aunque haya varias versiones de la app.
        if (cruda.clasificacion_global !== 'apto') {
          const limitante = cruda.parametro_limitante_id
            ? await cliente.query(
                'SELECT nombre, unidad FROM parametros WHERE id = $1',
                [cruda.parametro_limitante_id],
              )
            : { rows: [] };

          const medicion = cruda.mediciones.find(
            (m) => m.parametro_id === cruda.parametro_limitante_id,
          );

          const detalle = limitante.rows.length
            ? `${limitante.rows[0].nombre} en ${medicion?.valor ?? '?'} ` +
              `${limitante.rows[0].unidad}.`
            : 'Muestra fuera de norma.';

          await cliente.query(
            `INSERT INTO alertas (muestra_id, punto_id, tipo, detalle, fecha)
             VALUES ($1, $2, $3, $4, $5)`,
            [
              id,
              cruda.punto_id,
              cruda.clasificacion_global,
              detalle,
              cruda.fecha_hora,
            ],
          );
        }

        aceptadas.push({ id_local: cruda.id_local, id_servidor: id });
      }

      await auditar(contexto(req), Accion.sincronizacion, {
        detalle:
          `${aceptadas.length} recibida(s), ${repetidas.length} repetida(s)`,
        cliente,
      });

      return { aceptadas, repetidas };
    });

    res.status(201).json({
      recibidas: resultado.aceptadas.length,
      repetidas: resultado.repetidas.length,
      asignaciones: resultado.aceptadas,
      servidor: new Date().toISOString(),
    });
  }),
);

rutasMuestras.get(
  '/alertas',
  asincrona(async (req, res) => {
    res.json(
      await todas(
        `SELECT a.id, a.muestra_id, a.punto_id, a.tipo, a.detalle, a.fecha,
                a.atendida
         FROM alertas a
         JOIN puntos p ON p.id = a.punto_id
         WHERE p.organizacion_id = $1
         ORDER BY a.fecha DESC`,
        [org(req)],
      ),
    );
  }),
);

rutasMuestras.post(
  '/alertas/:id/atender',
  asincrona(async (req, res) => {
    const fila = await una(
      `UPDATE alertas
       SET atendida = TRUE, atendida_por = $1, atendida_en = now()
       WHERE id = $2
       RETURNING id, detalle`,
      [req.usuario.id, req.params.id],
    );
    if (!fila) throw noEncontrado('La alerta no existe.');

    await auditar(contexto(req), Accion.atencionAlerta, {
      entidadId: fila.id,
      detalle: fila.detalle,
    });
    res.status(204).end();
  }),
);
