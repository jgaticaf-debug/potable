export class ErrorHttp extends Error {
  constructor(codigo, mensaje, detalles) {
    super(mensaje);
    this.name = 'ErrorHttp';
    this.codigo = codigo;
    this.detalles = detalles;
  }
}

export const noAutorizado = (m = 'Credenciales invalidas.') =>
  new ErrorHttp(401, m);
export const prohibido = (m = 'Su rol no tiene permiso para esta operacion.') =>
  new ErrorHttp(403, m);
export const noEncontrado = (m = 'El recurso no existe.') =>
  new ErrorHttp(404, m);
export const conflicto = (m) => new ErrorHttp(409, m);
export const invalido = (m, detalles) => new ErrorHttp(422, m, detalles);

const PORCONSTRAINT = {
  zonas_nombre_unico: 'Ya existe una zona con ese nombre.',
  usuarios_correo_key: 'Ya existe una cuenta con ese correo.',
  dispositivos_identificador_key: 'Ya existe un dispositivo con ese codigo.',
  muestras_sin_duplicar: 'Esa muestra ya fue recibida.',
  mediciones_una_por_parametro:
    'La muestra trae el mismo parametro dos veces.',
};

export function manejadorDeErrores(error, req, res, _next) {
  if (error instanceof ErrorHttp) {
    return res
      .status(error.codigo)
      .json({ mensaje: error.message, detalles: error.detalles });
  }

  if (error?.code === '23505') {
    const mensaje =
      PORCONSTRAINT[error.constraint] ?? 'El registro ya existe.';
    return res.status(409).json({ mensaje });
  }
  if (error?.code === '23503') {
    return res.status(409).json({
      mensaje: 'El registro esta referenciado por otros datos y no puede '
        + 'eliminarse.',
    });
  }

  console.error('[api] error no controlado:', error);
  return res.status(500).json({ mensaje: 'Error interno del servidor.' });
}

export const asincrona = (manejador) => (req, res, next) =>
  Promise.resolve(manejador(req, res, next)).catch(next);
