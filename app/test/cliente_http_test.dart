import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:potable/datos/api/cliente.dart';
import 'package:potable/datos/api/cliente_http.dart';

void main() {
  const base = 'http://localhost:9999';

  ClienteHttp conRespuesta(
    http.Response Function(http.Request) manejador,
  ) =>
      ClienteHttp(http_: MockClient((r) async => manejador(r)), baseUrl: base);

  test('el login guarda el token y devuelve el usuario', () async {
    late http.Request recibida;
    final cliente = conRespuesta((r) {
      recibida = r;
      return http.Response(
        jsonEncode({
          'token': 'abc.def.ghi',
          'usuario': {'id': 3, 'nombre': 'Marco', 'rol': 'administrador'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final usuario = await cliente.login('admin@aguapura.gt', 'agua2026');

    expect(recibida.method, 'POST');
    expect(recibida.url.path, '/auth/login');
    expect(jsonDecode(recibida.body)['correo'], 'admin@aguapura.gt');
    expect(usuario['nombre'], 'Marco');
    expect(cliente.token, 'abc.def.ghi');
    expect(cliente.haySesion, isTrue);
  });

  test('adjunta el token en el encabezado Authorization', () async {
    late http.Request recibida;
    final cliente = conRespuesta((r) {
      recibida = r;
      return http.Response('[]', 200);
    });
    cliente.restaurarToken('token-guardado');

    await cliente.listar('/zonas');

    expect(recibida.headers['Authorization'], 'Bearer token-guardado');
  });

  test('un 401 descarta el token y lanza SesionExpirada', () async {
    final cliente = conRespuesta(
      (r) => http.Response(jsonEncode({'mensaje': 'La sesion expiro.'}), 401),
    );
    cliente.restaurarToken('token-vencido');

    await expectLater(cliente.perfil(), throwsA(isA<SesionExpirada>()));
    expect(cliente.haySesion, isFalse,
        reason: 'no debe reintentar con un token que el servidor rechazo');
  });

  test('conserva el mensaje del servidor en los errores', () async {
    final cliente = conRespuesta(
      (r) => http.Response(
        jsonEncode({'mensaje': 'Ya existe una zona con ese nombre.'}),
        409,
      ),
    );

    try {
      await cliente.guardarZona({'id': 0, 'nombre': 'Plantacion 1'});
      fail('debio lanzar');
    } on ErrorApi catch (e) {
      expect(e.codigo, 409);
      expect(e.mensaje, 'Ya existe una zona con ese nombre.');
    }
  });

  test('sin red lanza SinConexion, no un error generico', () async {
    final cliente = ClienteHttp(
      http_: MockClient((r) => throw const SocketException('conexion rechazada')),
      baseUrl: base,
    );

    await expectLater(cliente.perfil(), throwsA(isA<SinConexion>()));
  });

  test('usa POST para crear y PUT para editar', () async {
    final metodos = <String>[];
    final cliente = conRespuesta((r) {
      metodos.add('${r.method} ${r.url.path}');
      return http.Response('{}', 200);
    });

    await cliente.guardarZona({'id': 0, 'nombre': 'Nueva'});
    await cliente.guardarZona({'id': 7, 'nombre': 'Editada'});
    await cliente.guardarPunto({'id': 0, 'nombre': 'Pozo 9'});
    await cliente.eliminarPunto(4);

    expect(metodos, [
      'POST /zonas',
      'PUT /zonas/7',
      'POST /puntos',
      'DELETE /puntos/4',
    ]);
  });

  test('la contrasena solo viaja cuando se definio una', () async {
    final cuerpos = <Map<String, dynamic>>[];
    final cliente = conRespuesta((r) {
      cuerpos.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response('{}', 200);
    });

    await cliente.guardarUsuario({'id': 5, 'nombre': 'Ana'});
    await cliente.guardarUsuario({'id': 5, 'nombre': 'Ana'}, clave: 'secreta1');

    expect(cuerpos[0].containsKey('clave'), isFalse);
    expect(cuerpos[1]['clave'], 'secreta1');
  });

  test('la sincronizacion envia la cola bajo la llave muestras', () async {
    late Map<String, dynamic> enviado;
    final cliente = conRespuesta((r) {
      enviado = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'recibidas': 1, 'repetidas': 0}), 201);
    });

    final respuesta = await cliente.sincronizar([
      {'id_local': 12, 'punto_id': 1, 'mediciones': []},
    ]);

    expect((enviado['muestras'] as List), hasLength(1));
    expect((enviado['muestras'] as List).first['id_local'], 12);
    expect(respuesta['recibidas'], 1);
  });
}
