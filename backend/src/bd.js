import pg from 'pg';

import { config } from './config.js';

pg.types.setTypeParser(pg.types.builtins.NUMERIC, (v) =>
  v === null ? null : Number.parseFloat(v),
);
pg.types.setTypeParser(pg.types.builtins.INT8, (v) =>
  v === null ? null : Number.parseInt(v, 10),
);

export const pool = new pg.Pool({
  ...config.conexionBd,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

pool.on('error', (error) => {
  console.error('[bd] conexion inactiva perdida:', error.message);
});

export function consultar(texto, parametros = []) {
  return pool.query(texto, parametros);
}

export async function una(texto, parametros = []) {
  const { rows } = await pool.query(texto, parametros);
  return rows[0] ?? null;
}

export async function todas(texto, parametros = []) {
  const { rows } = await pool.query(texto, parametros);
  return rows;
}

export async function enTransaccion(trabajo) {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const resultado = await trabajo(cliente);
    await cliente.query('COMMIT');
    return resultado;
  } catch (error) {
    await cliente.query('ROLLBACK');
    throw error;
  } finally {
    cliente.release();
  }
}

export async function cerrar() {
  await pool.end();
}
