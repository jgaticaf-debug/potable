import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { config } from '../src/config.js';
import {
  firmarToken,
  hashearClave,
  verificarClave,
  verificarToken,
} from '../src/seguridad.js';

describe('hash de contrasenas', () => {
  it('produce el formato documentado', () => {
    const hash = hashearClave('agua2026');
    const partes = hash.split('$');

    assert.equal(partes.length, 4);
    assert.equal(partes[0], 'pbkdf2_sha256');
    assert.equal(Number(partes[1]), config.pbkdf2Iteraciones);
    assert.ok(partes[2].length > 0, 'la sal no puede ir vacia');
    assert.ok(partes[3].length > 0, 'la derivada no puede ir vacia');
  });

  it('acepta la contrasena correcta y rechaza la incorrecta', () => {
    const hash = hashearClave('agua2026');

    assert.equal(verificarClave('agua2026', hash), true);
    assert.equal(verificarClave('agua2027', hash), false);
    assert.equal(verificarClave('', hash), false);
  });

  it('nunca guarda la contrasena en claro', () => {
    const hash = hashearClave('agua2026');
    assert.ok(!hash.includes('agua2026'));
  });

  it('dos hashes de la misma contrasena son distintos', () => {
    const a = hashearClave('agua2026');
    const b = hashearClave('agua2026');

    assert.notEqual(a, b, 'la sal debe ser aleatoria por cuenta');
    assert.equal(verificarClave('agua2026', a), true);
    assert.equal(verificarClave('agua2026', b), true);
  });

  it('un hash viejo sigue validando aunque suban las iteraciones', () => {
    const original = config.pbkdf2Iteraciones;
    const hash = hashearClave('agua2026');

    config.pbkdf2Iteraciones = original * 4;
    try {
      assert.equal(verificarClave('agua2026', hash), true);

      const nuevo = hashearClave('agua2026');
      assert.equal(Number(nuevo.split('$')[1]), original * 4);
      assert.equal(verificarClave('agua2026', nuevo), true);
    } finally {
      config.pbkdf2Iteraciones = original;
    }
  });

  it('rechaza hashes malformados sin lanzar excepcion', () => {
    for (const basura of [
      '',
      'no-es-un-hash',
      'pbkdf2_sha256$12000$solo-tres-partes',
      'md5$12000$sal$derivada',
      'pbkdf2_sha256$abc$sal$derivada',
      null,
      undefined,
    ]) {
      assert.equal(verificarClave('agua2026', basura), false);
    }
  });

  it('valida un hash generado por la implementacion de Flutter', () => {
    const deDart =
      'pbkdf2_sha256$12000$k3JmQ1p2X0hEZmFz$' +
      'ri1WJouP-X6smxj4BJqr9bcQbn9FzjTRMiePxlnCYaA';

    assert.equal(verificarClave('agua2026', deDart), true);
    assert.equal(verificarClave('incorrecta', deDart), false);
  });
});

describe('tokens JWT', () => {
  it('firma y verifica de ida y vuelta', () => {
    const token = firmarToken({ sub: 3, rol: 'administrador', org: 1 });
    const reclamos = verificarToken(token);

    assert.equal(reclamos.sub, 3);
    assert.equal(reclamos.rol, 'administrador');
    assert.ok(reclamos.exp > reclamos.iat);
  });

  it('rechaza un token alterado', () => {
    const token = firmarToken({ sub: 1, rol: 'operario' });
    const [cabecera, cuerpo, firma] = token.split('.');

    const cuerpoFalso = Buffer.from(
      JSON.stringify({ sub: 1, rol: 'administrador', exp: 9999999999 }),
    ).toString('base64url');

    assert.equal(verificarToken(`${cabecera}.${cuerpoFalso}.${firma}`), null);
    assert.equal(verificarToken(`${cabecera}.${cuerpo}.firmaInventada`), null);
    assert.equal(verificarToken('cualquier.cosa.aqui'), null);
    assert.equal(verificarToken(''), null);
  });

  it('rechaza un token vencido', () => {
    const original = config.jwt.vigenciaHoras;
    config.jwt.vigenciaHoras = -1;
    try {
      const vencido = firmarToken({ sub: 1, rol: 'operario' });
      assert.equal(verificarToken(vencido), null);
    } finally {
      config.jwt.vigenciaHoras = original;
    }
  });

  it('rechaza un token firmado con otro secreto', () => {
    const token = firmarToken({ sub: 1, rol: 'administrador' });
    const original = config.jwt.secreto;

    config.jwt.secreto = 'otro-secreto-completamente-distinto';
    try {
      assert.equal(verificarToken(token), null);
    } finally {
      config.jwt.secreto = original;
    }
  });
});
