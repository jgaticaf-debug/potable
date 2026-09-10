import { pathToFileURL } from 'node:url';

import cors from 'cors';
import express from 'express';

import { cerrar, una } from './bd.js';
import { config, validarConfig } from './config.js';
import { manejadorDeErrores } from './errores.js';
import { rutasAuth } from './rutas/auth.js';
import { rutasCatalogo } from './rutas/catalogo.js';
import { rutasMuestras } from './rutas/muestras.js';
import { rutasUsuarios } from './rutas/usuarios.js';

validarConfig();

const app = express();

app.set('trust proxy', 1);
app.disable('x-powered-by');

app.use(
  cors({
    origin: config.corsOrigenes.length > 0 ? config.corsOrigenes : true,
  }),
);
app.use(express.json({ limit: '2mb' }));

app.get('/salud', async (req, res) => {
  try {
    await una('SELECT 1');
    res.json({ estado: 'ok', bd: 'conectada', entorno: config.entorno });
  } catch (error) {
    res.status(503).json({ estado: 'degradado', bd: error.message });
  }
});

app.use('/auth', rutasAuth);
app.use('/usuarios', rutasUsuarios);
app.use('/', rutasCatalogo);
app.use('/', rutasMuestras);

app.use((req, res) => {
  res.status(404).json({ mensaje: `No existe ${req.method} ${req.path}` });
});

app.use(manejadorDeErrores);

export function arrancar(puerto = config.puerto) {
  const servidor = app.listen(puerto, () => {
    console.log(
      `[api] Potable escuchando en http://localhost:${servidor.address().port} ` +
        `(${config.entorno})`,
    );
  });

  for (const senal of ['SIGINT', 'SIGTERM']) {
    process.on(senal, () => {
      console.log(`\n[api] ${senal} recibida, cerrando...`);
      servidor.close(async () => {
        await cerrar();
        process.exit(0);
      });
    });
  }

  return servidor;
}

const ejecutadoDirectamente =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (ejecutadoDirectamente) arrancar();

export { app };
