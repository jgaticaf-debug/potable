import 'dotenv/config';

function entero(clave, porDefecto) {
  const valor = Number.parseInt(process.env[clave] ?? '', 10);
  return Number.isFinite(valor) ? valor : porDefecto;
}

function texto(clave, porDefecto) {
  const valor = (process.env[clave] ?? '').trim();
  return valor === '' ? porDefecto : valor;
}

// La red interna de Railway no habla TLS; el proxy publico si. Por eso el
// dominio decide, salvo que se fuerce con DATABASE_SSL.
function sslPara(url) {
  const forzado = (process.env.DATABASE_SSL ?? '').trim().toLowerCase();
  if (forzado === 'false') return false;
  if (forzado === 'true') return { rejectUnauthorized: false };
  return /\.internal(:|\/|$)/.test(url) ? false : { rejectUnauthorized: false };
}

export const config = {
  puerto: entero('PORT', 3000),
  entorno: texto('NODE_ENV', 'development'),

  get esProduccion() {
    return this.entorno === 'production';
  },

  // Railway y Render inyectan DATABASE_URL de una sola pieza. Si esta, manda
  // sobre las variables sueltas, que son las que uso en local.
  urlBd: texto('DATABASE_URL', ''),

  bd: {
    host: texto('PGHOST', 'localhost'),
    port: entero('PGPORT', 5432),
    database: texto('PGDATABASE', 'potable'),
    user: texto('PGUSER', 'postgres'),
    password: texto('PGPASSWORD', ''),
  },

  bdAdmin: texto('PGDATABASE_ADMIN', 'postgres'),

  get gestionada() {
    return this.urlBd !== '';
  },

  get conexionBd() {
    if (!this.gestionada) return { ...this.bd };
    return { connectionString: this.urlBd, ssl: sslPara(this.urlBd) };
  },

  jwt: {
    secreto: texto('JWT_SECRET', ''),
    vigenciaHoras: entero('JWT_VIGENCIA_HORAS', 8),
  },

  pbkdf2Iteraciones: entero('PBKDF2_ITERACIONES', 12000),
  claveDemo: texto('CLAVE_DEMO', 'agua2026'),

  corsOrigenes: texto('CORS_ORIGENES', '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),
};

export function validarConfig() {
  const faltantes = [];

  if (!config.jwt.secreto) faltantes.push('JWT_SECRET');
  if (!config.gestionada && !config.bd.password) faltantes.push('PGPASSWORD');

  if (faltantes.length > 0) {
    throw new Error(
      `Faltan variables de entorno: ${faltantes.join(', ')}. ` +
        'Copie .env.example a .env y complete los valores.',
    );
  }

  if (config.esProduccion) {
    if (config.jwt.secreto.length < 32) {
      throw new Error(
        'JWT_SECRET es demasiado corto para produccion. Use al menos 32 ' +
          'caracteres aleatorios.',
      );
    }
    if (config.jwt.secreto.includes('cambie')) {
      throw new Error('JWT_SECRET sigue siendo el valor de plantilla.');
    }
    if (config.corsOrigenes.length === 0) {
      throw new Error(
        'Defina CORS_ORIGENES en produccion. Dejarlo vacio abre el API a ' +
          'cualquier sitio.',
      );
    }
  }
}
