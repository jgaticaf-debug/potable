import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import {
  CUENTAS,
  crearCliente,
  levantarServidor,
  prepararBase,
} from './ayuda.js';

let api;
let servidor;

before(async () => {
  await prepararBase();
  servidor = await levantarServidor();
  api = crearCliente(servidor.base);
});

after(async () => {
  await servidor?.cerrar();
  const { cerrar } = await import('../src/bd.js');
  await cerrar();
});

describe('autenticacion', () => {
  it('el login correcto devuelve token y usuario', async () => {
    const r = await api.post('/auth/login', {
      correo: CUENTAS.admin,
      clave: 'agua2026',
    });

    assert.equal(r.estado, 200);
    assert.equal(r.datos.usuario.rol, 'administrador');
    assert.ok(r.datos.token.split('.').length === 3);
    assert.ok(r.datos.expira_en > 0);
  });

  it('no distingue entre correo inexistente y clave incorrecta', async () => {
    const malaClave = await api.post('/auth/login', {
      correo: CUENTAS.admin,
      clave: 'incorrecta',
    });
    const sinCuenta = await api.post('/auth/login', {
      correo: 'nadie@aguapura.gt',
      clave: 'agua2026',
    });

    assert.equal(malaClave.estado, 401);
    assert.equal(sinCuenta.estado, 401);
    assert.equal(malaClave.datos.mensaje, sinCuenta.datos.mensaje);
  });

  it('las rutas protegidas exigen token', async () => {
    const anonimo = crearCliente(servidor.base);

    assert.equal((await anonimo.get('/zonas')).estado, 401);
    assert.equal((await anonimo.get('/auth/perfil')).estado, 401);

    anonimo.token = 'token.completamente.inventado';
    assert.equal((await anonimo.get('/zonas')).estado, 401);
  });

  it('el perfil responde con la cuenta del token', async () => {
    await api.entrarComo(CUENTAS.calidad);
    const r = await api.get('/auth/perfil');

    assert.equal(r.estado, 200);
    assert.equal(r.datos.correo, CUENTAS.calidad);
    assert.equal(r.datos.rol, 'calidad');
  });
});

describe('seguridad de la sesion', () => {
  it('cerrar sesion invalida el token de inmediato', async () => {
    const suyo = crearCliente(servidor.base);
    await suyo.entrarComo(CUENTAS.calidad);

    assert.equal((await suyo.get('/zonas')).estado, 200);

    assert.equal((await suyo.post('/auth/logout')).estado, 204);

    const despues = await suyo.get('/zonas');
    assert.equal(despues.estado, 401);
    assert.match(despues.datos.mensaje, /cerrada/i);
  });

  it('bloquea tras varios intentos fallidos seguidos', async () => {
    const atacante = crearCliente(servidor.base);
    const correo = 'objetivo@aguapura.gt';

    let ultimo = null;
    for (let i = 0; i < 12; i++) {
      ultimo = await atacante.post('/auth/login', {
        correo,
        clave: `intento-${i}`,
      });
      if (ultimo.estado === 429) break;
    }

    assert.equal(ultimo.estado, 429);
    assert.match(ultimo.datos.mensaje, /intentos/i);
  });

  it('el bloqueo no afecta a otra cuenta desde el mismo origen', async () => {
    const otro = crearCliente(servidor.base);
    const usuario = await otro.entrarComo(CUENTAS.admin);
    assert.equal(usuario.rol, 'administrador');
  });
});

describe('autorizacion por rol', () => {
  it('control de calidad no puede crear ni borrar zonas', async () => {
    const calidad = crearCliente(servidor.base);
    await calidad.entrarComo(CUENTAS.calidad);

    assert.equal((await calidad.post('/zonas', { nombre: 'X' })).estado, 403);
    assert.equal((await calidad.borrar('/zonas/1')).estado, 403);
    assert.equal((await calidad.post('/usuarios', {})).estado, 403);
  });

  it('control de calidad si puede consultar', async () => {
    const calidad = crearCliente(servidor.base);
    await calidad.entrarComo(CUENTAS.calidad);

    assert.equal((await calidad.get('/zonas')).estado, 200);
    assert.equal((await calidad.get('/muestras')).estado, 200);
  });
});

describe('catalogo normativo', () => {
  it('trae los siete parametros con sus limites', async () => {
    await api.entrarComo(CUENTAS.admin);
    const r = await api.get('/parametros');

    assert.equal(r.estado, 200);
    assert.equal(r.datos.length, 7);

    const ph = r.datos.find((p) => p.nombre === 'pH');
    assert.equal(ph.limite_min, 6);
    assert.equal(ph.limite_max, 8.5);
    assert.equal(ph.via_captura, 'sensor');

    const cloro = r.datos.find((p) => p.nombre === 'Cloro residual libre');
    assert.equal(cloro.critico, true);
  });
});

describe('zonas', () => {
  it('alta, edicion y baja', async () => {
    await api.entrarComo(CUENTAS.admin);

    const alta = await api.post('/zonas', {
      nombre: 'Plantacion 9',
      descripcion: 'de prueba',
    });
    assert.equal(alta.estado, 201);
    const id = alta.datos.id;

    const edicion = await api.put(`/zonas/${id}`, {
      nombre: 'Plantacion 9 renombrada',
      descripcion: 'editada',
      activa: true,
    });
    assert.equal(edicion.estado, 200);
    assert.equal(edicion.datos.nombre, 'Plantacion 9 renombrada');

    assert.equal((await api.borrar(`/zonas/${id}`)).estado, 204);
    assert.equal((await api.put(`/zonas/${id}`, { nombre: 'x' })).estado, 404);
  });

  it('rechaza nombres repetidos con un mensaje entendible', async () => {
    await api.entrarComo(CUENTAS.admin);
    const r = await api.post('/zonas', { nombre: 'Plantacion 1' });

    assert.equal(r.estado, 409);
    assert.match(r.datos.mensaje, /ya existe/i);
    assert.ok(!r.datos.mensaje.includes('constraint'));
  });

  it('rechaza el nombre vacio', async () => {
    await api.entrarComo(CUENTAS.admin);
    assert.equal((await api.post('/zonas', { nombre: '   ' })).estado, 422);
  });

  it('no elimina una zona que tiene puntos', async () => {
    await api.entrarComo(CUENTAS.admin);
    const zonas = await api.get('/zonas');
    const conPuntos = zonas.datos.find((z) => z.nombre === 'Plantacion 1');

    const r = await api.borrar(`/zonas/${conPuntos.id}`);
    assert.equal(r.estado, 409);
    assert.match(r.datos.mensaje, /punto/i);
  });
});

describe('usuarios', () => {
  it('crea una cuenta que puede iniciar sesion', async () => {
    await api.entrarComo(CUENTAS.admin);

    const alta = await api.post('/usuarios', {
      nombre: 'Ana Lopez',
      correo: 'ana@aguapura.gt',
      rol: 'calidad',
      clave: 'clave-de-prueba',
    });
    assert.equal(alta.estado, 201);
    assert.equal(alta.datos.clave_hash, undefined, 'el hash no debe salir');

    const nueva = crearCliente(servidor.base);
    const usuario = await nueva.entrarComo('ana@aguapura.gt', 'clave-de-prueba');
    assert.equal(usuario.rol, 'calidad');
  });

  it('exige una contrasena de al menos ocho caracteres', async () => {
    await api.entrarComo(CUENTAS.admin);
    const r = await api.post('/usuarios', {
      nombre: 'Corta',
      correo: 'corta@aguapura.gt',
      rol: 'operario',
      clave: 'abc',
    });

    assert.equal(r.estado, 422);
  });

  it('rechaza un correo repetido', async () => {
    await api.entrarComo(CUENTAS.admin);
    const r = await api.post('/usuarios', {
      nombre: 'Otro Marco',
      correo: CUENTAS.admin,
      rol: 'operario',
      clave: 'clave-de-prueba',
    });

    assert.equal(r.estado, 409);
    assert.match(r.datos.mensaje, /correo/i);
  });

  it('editar sin contrasena conserva la anterior', async () => {
    await api.entrarComo(CUENTAS.admin);
    const lista = await api.get('/usuarios');
    const ana = lista.datos.find((u) => u.correo === 'ana@aguapura.gt');

    const r = await api.put(`/usuarios/${ana.id}`, {
      nombre: 'Ana Lopez Ruiz',
      correo: ana.correo,
      rol: 'calidad',
      activo: true,
    });
    assert.equal(r.estado, 200);

    const suya = crearCliente(servidor.base);
    const usuario = await suya.entrarComo('ana@aguapura.gt', 'clave-de-prueba');
    assert.equal(usuario.nombre, 'Ana Lopez Ruiz');
  });

  it('una cuenta desactivada no puede entrar', async () => {
    await api.entrarComo(CUENTAS.admin);
    const lista = await api.get('/usuarios');
    const ana = lista.datos.find((u) => u.correo === 'ana@aguapura.gt');

    await api.put(`/usuarios/${ana.id}`, {
      nombre: ana.nombre,
      correo: ana.correo,
      rol: ana.rol,
      activo: false,
    });

    const intento = crearCliente(servidor.base);
    const r = await intento.post('/auth/login', {
      correo: 'ana@aguapura.gt',
      clave: 'clave-de-prueba',
    });
    assert.equal(r.estado, 403);
  });

  it('no puede eliminarse ni desactivarse a si mismo', async () => {
    const yo = await api.entrarComo(CUENTAS.admin);

    assert.equal((await api.borrar(`/usuarios/${yo.id}`)).estado, 409);

    const desactivarse = await api.put(`/usuarios/${yo.id}`, {
      nombre: yo.nombre,
      correo: yo.correo,
      rol: 'administrador',
      activo: false,
    });
    assert.equal(desactivarse.estado, 409);

    const degradarse = await api.put(`/usuarios/${yo.id}`, {
      nombre: yo.nombre,
      correo: yo.correo,
      rol: 'operario',
      activo: true,
    });
    assert.equal(degradarse.estado, 409);
  });
});

describe('sincronizacion', () => {
  const muestra = (idLocal, clasificacion = 'incumplimiento') => ({
    id_local: idLocal,
    punto_id: 1,
    fecha_hora: '2026-08-25T06:15:00Z',
    creado_en: '2026-08-25T11:40:00Z',
    clasificacion_global: clasificacion,
    parametro_limitante_id: clasificacion === 'apto' ? null : 3,
    observaciones: 'prueba',
    mediciones: [
      { parametro_id: 1, valor: 7.2, origen: 'sensor', clasificacion: 'apto' },
      {
        parametro_id: 3,
        valor: 0.05,
        origen: 'manual',
        clasificacion: clasificacion === 'apto' ? 'apto' : 'incumplimiento',
      },
    ],
  });

  it('recibe la cola y genera la alerta', async () => {
    const operario = crearCliente(servidor.base);
    await operario.entrarComo(CUENTAS.operario);

    const antes = (await operario.get('/alertas')).datos.length;

    const r = await operario.post('/sincronizacion', {
      muestras: [muestra(101)],
    });

    assert.equal(r.estado, 201);
    assert.equal(r.datos.recibidas, 1);
    assert.equal(r.datos.repetidas, 0);
    assert.equal(r.datos.asignaciones[0].id_local, 101);

    const despues = await operario.get('/alertas');
    assert.equal(despues.datos.length, antes + 1);
    assert.match(despues.datos[0].detalle, /cloro/i);
  });

  it('el reintento del mismo envio no duplica', async () => {
    const operario = crearCliente(servidor.base);
    await operario.entrarComo(CUENTAS.operario);

    const cola = { muestras: [muestra(202)] };

    const primera = await operario.post('/sincronizacion', cola);
    assert.equal(primera.datos.recibidas, 1);

    const reintento = await operario.post('/sincronizacion', cola);
    assert.equal(reintento.datos.recibidas, 0);
    assert.equal(reintento.datos.repetidas, 1);

    const muestras = await operario.get('/muestras');
    const conEseId = muestras.datos.filter(
      (m) => m.observaciones === 'prueba' && m.punto_id === 1,
    );
    assert.ok(conEseId.length >= 1);
  });

  it('la muestra guardada conserva sus tres marcas de tiempo', async () => {
    const operario = crearCliente(servidor.base);
    await operario.entrarComo(CUENTAS.operario);

    await operario.post('/sincronizacion', { muestras: [muestra(303, 'apto')] });

    const muestras = await operario.get('/muestras');
    const guardada = muestras.datos[0];

    assert.ok(guardada.fecha_hora);
    assert.ok(guardada.creado_en);
    assert.ok(guardada.recibido_en);
    assert.ok(
      new Date(guardada.creado_en) > new Date(guardada.fecha_hora),
      'la captura ocurre despues de la toma',
    );
    assert.equal(guardada.mediciones.length, 2);
  });

  it('rechaza una muestra sin mediciones', async () => {
    const operario = crearCliente(servidor.base);
    await operario.entrarComo(CUENTAS.operario);

    const r = await operario.post('/sincronizacion', {
      muestras: [{ ...muestra(404), mediciones: [] }],
    });

    assert.equal(r.estado, 422);
    assert.match(r.datos.mensaje, /mediciones/i);
  });

  it('rechaza un punto que no es de la organizacion', async () => {
    const operario = crearCliente(servidor.base);
    await operario.entrarComo(CUENTAS.operario);

    const r = await operario.post('/sincronizacion', {
      muestras: [{ ...muestra(505), punto_id: 99999 }],
    });

    assert.equal(r.estado, 422);
  });

  it('control de calidad no puede sincronizar', async () => {
    const calidad = crearCliente(servidor.base);
    await calidad.entrarComo(CUENTAS.calidad);

    const r = await calidad.post('/sincronizacion', {
      muestras: [muestra(606)],
    });
    assert.equal(r.estado, 403);
  });
});

describe('bitacora', () => {
  it('registra quien hizo que, con su rol del momento', async () => {
    await api.entrarComo(CUENTAS.admin);
    await api.post('/zonas', { nombre: 'Zona auditada' });

    const r = await api.get('/auditoria?limite=50');
    assert.equal(r.estado, 200);

    const alta = r.datos.find((x) => x.accion === 'altaZona');
    assert.equal(alta.usuario_nombre, 'Marco Chavarria');
    assert.equal(alta.rol, 'administrador');
    assert.equal(alta.detalle, 'Zona auditada');

    assert.ok(r.datos.some((x) => x.accion === 'inicioSesion'));
    assert.ok(r.datos.some((x) => x.accion === 'sincronizacion'));
  });
});
