import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import pg from 'pg';

import { config, validarConfig } from '../src/config.js';

const aqui = path.dirname(fileURLToPath(import.meta.url));
const carpetaSql = path.join(aqui, '..', 'src', 'sql');

async function conectarAdmin() {
  const cliente = new pg.Client({ ...config.bd, database: config.bdAdmin });
  await cliente.connect();
  return cliente;
}

async function baseExiste(cliente) {
  const { rows } = await cliente.query(
    'SELECT 1 FROM pg_database WHERE datname = $1',
    [config.bd.database],
  );
  return rows.length > 0;
}

async function reiniciarBase() {
  const admin = await conectarAdmin();
  try {
    await admin.query(
      `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
       WHERE datname = $1 AND pid <> pg_backend_pid()`,
      [config.bd.database],
    );
    await admin.query(`DROP DATABASE IF EXISTS "${config.bd.database}"`);
    console.log(`[migrar] base "${config.bd.database}" eliminada`);
  } finally {
    await admin.end();
  }
}

async function crearBaseSiFalta() {
  const admin = await conectarAdmin();
  try {
    if (await baseExiste(admin)) return false;
    await admin.query(`CREATE DATABASE "${config.bd.database}"`);
    console.log(`[migrar] base "${config.bd.database}" creada`);
    return true;
  } finally {
    await admin.end();
  }
}

async function asegurarRegistro(cliente) {
  await cliente.query(`
    CREATE TABLE IF NOT EXISTS migraciones (
      archivo  TEXT PRIMARY KEY,
      aplicada TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function principal() {
  validarConfig();

  // En Railway la base ya viene creada y no tengo permiso de superusuario
  // para CREATE DATABASE. Solo aplico las migraciones.
  if (config.gestionada) {
    if (process.argv.includes('--reiniciar')) {
      throw new Error(
        'No se permite --reiniciar contra una base gestionada. Borrela desde ' +
          'el panel del proveedor si de verdad quiere empezar de cero.',
      );
    }
  } else {
    if (process.argv.includes('--reiniciar')) {
      await reiniciarBase();
    }
    await crearBaseSiFalta();
  }

  const cliente = new pg.Client(config.conexionBd);
  await cliente.connect();

  try {
    await asegurarRegistro(cliente);

    const { rows } = await cliente.query('SELECT archivo FROM migraciones');
    const aplicadas = new Set(rows.map((r) => r.archivo));

    const archivos = (await readdir(carpetaSql))
      .filter((a) => a.endsWith('.sql'))
      .sort();

    let corridas = 0;
    for (const archivo of archivos) {
      if (aplicadas.has(archivo)) continue;

      const sql = await readFile(path.join(carpetaSql, archivo), 'utf8');
      process.stdout.write(`[migrar] ${archivo} ... `);
      await cliente.query(sql);
      await cliente.query('INSERT INTO migraciones (archivo) VALUES ($1)', [
        archivo,
      ]);
      console.log('ok');
      corridas++;
    }

    console.log(
      corridas === 0
        ? '[migrar] la base ya estaba al dia'
        : `[migrar] ${corridas} migracion(es) aplicadas`,
    );
  } finally {
    await cliente.end();
  }
}

principal().catch((error) => {
  console.error('[migrar] fallo:', error.message);
  process.exitCode = 1;
});
