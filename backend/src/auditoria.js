import { consultar } from './bd.js';

export const Accion = {
  inicioSesion: 'inicioSesion',
  sesionReanudada: 'sesionReanudada',
  cierreSesion: 'cierreSesion',
  registroMuestra: 'registroMuestra',
  sincronizacion: 'sincronizacion',
  altaZona: 'altaZona',
  edicionZona: 'edicionZona',
  bajaZona: 'bajaZona',
  altaPunto: 'altaPunto',
  edicionPunto: 'edicionPunto',
  bajaPunto: 'bajaPunto',
  altaUsuario: 'altaUsuario',
  edicionUsuario: 'edicionUsuario',
  bajaUsuario: 'bajaUsuario',
  altaDispositivo: 'altaDispositivo',
  edicionDispositivo: 'edicionDispositivo',
  bajaDispositivo: 'bajaDispositivo',
  atencionAlerta: 'atencionAlerta',
};

export async function auditar(
  { usuario, ip },
  accion,
  { entidadId = null, detalle = '', cliente = null } = {},
) {
  if (!usuario) return;

  const sql = `
    INSERT INTO auditoria
      (usuario_id, usuario_nombre, rol, accion, entidad_id, detalle, origen_ip)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
  `;
  const valores = [
    usuario.id,
    usuario.nombre,
    usuario.rol,
    accion,
    entidadId,
    detalle,
    ip ?? null,
  ];

  if (cliente) await cliente.query(sql, valores);
  else await consultar(sql, valores);
}

export const contexto = (req) => ({
  usuario: req.usuario,
  ip: req.ip,
});
