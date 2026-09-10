import { cerrar, enTransaccion, una } from '../src/bd.js';
import { config, validarConfig } from '../src/config.js';
import { hashearClave } from '../src/seguridad.js';

const ORGANIZACION = { nombre: 'Agroindustria del Valle, S.A.', nit: '4521896-7' };

const USUARIOS = [
  { nombre: 'Jason Gatica', correo: 'operario@aguapura.gt', rol: 'operario' },
  { nombre: 'Lucia Ramirez', correo: 'calidad@aguapura.gt', rol: 'calidad' },
  { nombre: 'Marco Chavarria', correo: 'admin@aguapura.gt', rol: 'administrador' },
];

const PARAMETROS = [
  {
    nombre: 'pH', unidad: 'uds pH', via: 'sensor',
    lmin: 6.0, lmax: 8.5, amin: 6.5, amax: 8.0, critico: false,
    descripcion: 'Acidez o alcalinidad. Fuera de rango el agua corroe la '
      + 'tuberia y el cloro pierde eficacia.',
  },
  {
    nombre: 'Turbidez', unidad: 'UNT', via: 'sensor',
    lmin: 0, lmax: 5, amin: null, amax: 1, critico: false,
    descripcion: 'Particulas en suspension. La norma admite hasta 5 UNT, pero '
      + 'arriba de 1 UNT ya se compromete la desinfeccion.',
  },
  {
    nombre: 'Cloro residual libre', unidad: 'mg/L', via: 'manual',
    lmin: 0.2, lmax: 1.0, amin: 0.3, amax: 0.9, critico: true,
    descripcion: 'Desinfeccion activa en el punto. Por debajo del minimo el '
      + 'cloro se agoto; por encima aparecen subproductos.',
  },
  {
    nombre: 'Conductividad', unidad: 'uS/cm', via: 'sensor',
    lmin: 0, lmax: 750, amin: null, amax: 600, critico: false,
    descripcion: 'No dice que hay en el agua, pero delata cambios respecto a '
      + 'la linea base. Funciona como alerta temprana.',
  },
  {
    nombre: 'Nitratos', unidad: 'mg/L', via: 'manual',
    lmin: 0, lmax: 50, amin: null, amax: 35, critico: false,
    descripcion: 'Senal de contaminacion agricola o residual.',
  },
  {
    nombre: 'Coliformes totales', unidad: 'NMP/100 mL', via: 'manual',
    lmin: 0, lmax: 0, amin: null, amax: 0, critico: true,
    descripcion: 'Contaminacion fecal reciente. La norma exige ausencia en '
      + '100 mL.',
  },
  {
    nombre: 'Temperatura', unidad: 'C', via: 'sensor',
    lmin: 10, lmax: 32, amin: 15, amax: 28, critico: false,
    descripcion: 'Interpreta a los demas: a mayor temperatura el cloro se '
      + 'degrada mas rapido.',
  },
];

const ZONAS = [
  { nombre: 'Plantacion 1', descripcion: 'Bloque norte. Riego por goteo y consumo de personal.' },
  { nombre: 'Plantacion 2', descripcion: 'Bloque sur. Abastecida por pozo propio.' },
  { nombre: 'Plantacion 3', descripcion: 'Bloque de expansion. Aun sin instrumentacion.' },
  { nombre: 'Planta de proceso', descripcion: 'Lavado, empaque y agua de consumo humano.' },
];

const PUNTOS = [
  { zona: 'Plantacion 1', nombre: 'Pozo 1', tipo: 'pozo', sensor: true },
  { zona: 'Plantacion 1', nombre: 'Tanque elevado norte', tipo: 'tanque', sensor: true },
  { zona: 'Plantacion 2', nombre: 'Pozo 2', tipo: 'pozo', sensor: true },
  { zona: 'Plantacion 2', nombre: 'Linea de riego sur', tipo: 'linea', sensor: false },
  { zona: 'Plantacion 3', nombre: 'Toma provisional', tipo: 'linea', sensor: false },
  { zona: 'Planta de proceso', nombre: 'Salida de filtros', tipo: 'tratamiento', sensor: true },
  { zona: 'Planta de proceso', nombre: 'Comedor de personal', tipo: 'consumo', sensor: false },
];

const DISPOSITIVOS = [
  { punto: 'Pozo 1', id: 'ESP32-POZO1', dias: 21 },
  { punto: 'Tanque elevado norte', id: 'ESP32-TANQN', dias: 64 },
  { punto: 'Pozo 2', id: 'ESP32-POZO2', dias: 118 },
  { punto: 'Salida de filtros', id: 'ESP32-FILTR', dias: 9 },
];

const haceDias = (dias) =>
  new Date(Date.now() - dias * 86_400_000).toISOString().slice(0, 10);

async function principal() {
  validarConfig();

  const ya = await una('SELECT COUNT(*)::int AS total FROM organizaciones');
  if (ya.total > 0) {
    console.log('[sembrar] la base ya tiene datos, no se toca nada');
    return;
  }

  const claveHash = hashearClave(config.claveDemo);

  await enTransaccion(async (cliente) => {
    const org = await cliente.query(
      'INSERT INTO organizaciones (nombre, nit) VALUES ($1, $2) RETURNING id',
      [ORGANIZACION.nombre, ORGANIZACION.nit],
    );
    const orgId = org.rows[0].id;

    for (const u of USUARIOS) {
      await cliente.query(
        `INSERT INTO usuarios
           (organizacion_id, nombre, correo, clave_hash, rol)
         VALUES ($1, $2, $3, $4, $5)`,
        [orgId, u.nombre, u.correo, claveHash, u.rol],
      );
    }

    for (const p of PARAMETROS) {
      await cliente.query(
        `INSERT INTO parametros
           (nombre, unidad, via_captura, limite_min, limite_max,
            alerta_min, alerta_max, critico, descripcion)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [p.nombre, p.unidad, p.via, p.lmin, p.lmax, p.amin, p.amax,
          p.critico, p.descripcion],
      );
    }

    const idZona = new Map();
    for (const z of ZONAS) {
      const fila = await cliente.query(
        `INSERT INTO zonas (organizacion_id, nombre, descripcion)
         VALUES ($1, $2, $3) RETURNING id`,
        [orgId, z.nombre, z.descripcion],
      );
      idZona.set(z.nombre, fila.rows[0].id);
    }

    const idPunto = new Map();
    for (const p of PUNTOS) {
      const fila = await cliente.query(
        `INSERT INTO puntos
           (organizacion_id, zona_id, nombre, tipo, instrumentado)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [orgId, idZona.get(p.zona), p.nombre, p.tipo, p.sensor],
      );
      idPunto.set(p.nombre, fila.rows[0].id);
    }

    for (const d of DISPOSITIVOS) {
      await cliente.query(
        `INSERT INTO dispositivos
           (punto_id, identificador, tipo_sensor, ultima_calibracion)
         VALUES ($1, $2, $3, $4)`,
        [
          idPunto.get(d.punto),
          d.id,
          'pH / turbidez / TDS / temperatura',
          haceDias(d.dias),
        ],
      );
    }
  });

  console.log(
    `[sembrar] listo: ${USUARIOS.length} cuentas, ${PARAMETROS.length} ` +
      `parametros, ${ZONAS.length} zonas, ${PUNTOS.length} puntos`,
  );
  console.log(`[sembrar] clave de las cuentas: ${config.claveDemo}`);
}

principal()
  .catch((error) => {
    console.error('[sembrar] fallo:', error.message);
    process.exitCode = 1;
  })
  .finally(cerrar);
