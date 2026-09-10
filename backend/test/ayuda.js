import { execFile } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const ejecutar = promisify(execFile);
const raiz = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

export const BASE_DE_PRUEBAS = 'potable_test';

process.env.PGDATABASE = BASE_DE_PRUEBAS;
process.env.NODE_ENV = 'test';

async function correrScript(script, argumentos = []) {
  const { stdout, stderr } = await ejecutar(
    process.execPath,
    [path.join(raiz, 'scripts', script), ...argumentos],
    { cwd: raiz, env: { ...process.env, PGDATABASE: BASE_DE_PRUEBAS } },
  );
  if (stderr.trim()) console.error(stderr);
  return stdout;
}

export async function prepararBase() {
  await correrScript('migrar.js', ['--reiniciar']);
  await correrScript('sembrar.js');
}

export async function levantarServidor() {
  const { app } = await import('../src/index.js');

  return new Promise((resolver) => {
    const servidor = app.listen(0, () => {
      const { port } = servidor.address();
      resolver({
        servidor,
        base: `http://127.0.0.1:${port}`,
        cerrar: () =>
          new Promise((listo) => servidor.close(listo)),
      });
    });
  });
}

export function crearCliente(base) {
  let token = null;

  async function pedir(metodo, ruta, cuerpo) {
    const respuesta = await fetch(`${base}${ruta}`, {
      method: metodo,
      headers: {
        'Content-Type': 'application/json',
        Connection: 'close',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });

    const texto = await respuesta.text();
    let datos = null;
    if (texto.trim()) {
      try {
        datos = JSON.parse(texto);
      } catch {
        datos = { mensaje: texto };
      }
    }

    return { estado: respuesta.status, datos };
  }

  return {
    get token() {
      return token;
    },
    set token(valor) {
      token = valor;
    },

    get: (ruta) => pedir('GET', ruta),
    post: (ruta, cuerpo) => pedir('POST', ruta, cuerpo ?? {}),
    put: (ruta, cuerpo) => pedir('PUT', ruta, cuerpo ?? {}),
    borrar: (ruta) => pedir('DELETE', ruta),

    async entrarComo(correo, clave = 'agua2026') {
      const r = await pedir('POST', '/auth/login', { correo, clave });
      if (r.estado !== 200) {
        throw new Error(`No se pudo entrar como ${correo}: ${r.datos?.mensaje}`);
      }
      token = r.datos.token;
      return r.datos.usuario;
    },
  };
}

export const CUENTAS = {
  operario: 'operario@aguapura.gt',
  calidad: 'calidad@aguapura.gt',
  admin: 'admin@aguapura.gt',
};
