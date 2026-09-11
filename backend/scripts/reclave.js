import { cerrar, todas, una } from '../src/bd.js';
import { config, validarConfig } from '../src/config.js';
import { hashearClave } from '../src/seguridad.js';

const CUENTAS_DEMO = [
  'operario@aguapura.gt',
  'calidad@aguapura.gt',
  'admin@aguapura.gt',
];

// La semilla no vuelve a tocar una base que ya tiene datos, asi que si
// CLAVE_DEMO cambia despues del primer arranque las cuentas se quedan con la
// clave vieja. Esto rehace los hashes sin borrar nada mas.
async function principal() {
  validarConfig();

  const correos = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  const objetivo = correos.length > 0 ? correos : CUENTAS_DEMO;

  if (!process.argv.includes('--confirmar')) {
    console.log('[reclave] Se cambiaria la contrasena de:');
    for (const c of objetivo) console.log(`           ${c}`);
    console.log(
      `[reclave] Quedarian con el valor de CLAVE_DEMO (${config.claveDemo.length} caracteres).`,
    );
    console.log('[reclave] Vuelva a correrlo con --confirmar para aplicarlo.');
    return;
  }

  const hash = hashearClave(config.claveDemo);
  let cambiadas = 0;

  for (const correo of objetivo) {
    const fila = await una(
      `UPDATE usuarios SET clave_hash = $1
       WHERE correo = $2
       RETURNING correo, rol`,
      [hash, correo.trim().toLowerCase()],
    );

    if (fila) {
      console.log(`[reclave] ${fila.correo} (${fila.rol}) actualizada`);
      cambiadas++;
    } else {
      console.log(`[reclave] ${correo} no existe, se omite`);
    }
  }

  if (cambiadas === 0) {
    const cuantas = await todas('SELECT correo FROM usuarios ORDER BY correo');
    console.log(
      cuantas.length === 0
        ? '[reclave] La base no tiene ninguna cuenta. Corra la semilla primero.'
        : `[reclave] Cuentas existentes: ${cuantas.map((c) => c.correo).join(', ')}`,
    );
  } else {
    console.log(`[reclave] listo: ${cambiadas} cuenta(s)`);
  }
}

principal()
  .catch((error) => {
    console.error('[reclave] fallo:', error?.message || error);
    process.exitCode = 1;
  })
  .finally(cerrar);
