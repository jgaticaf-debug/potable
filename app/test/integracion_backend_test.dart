import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/api/cliente.dart';
import 'package:potable/datos/api/cliente_http.dart';

const _base = 'http://localhost:3000';

void main() {
  late ClienteHttp cliente;
  var servidorArriba = false;

  setUpAll(() async {
    cliente = ClienteHttp(baseUrl: _base);
    servidorArriba = await cliente.disponible();
    if (!servidorArriba) {
      // ignore: avoid_print
      print(
        'Backend no disponible en $_base. Levantelo con "npm run dev" en '
        'potable/backend para ejecutar estas pruebas.',
      );
    }
  });

  tearDownAll(() => cliente.cerrar());

  bool omitir() => !servidorArriba;

  test('el login devuelve un JWT que el cliente puede leer', () async {
    if (omitir()) return;

    final usuario = await cliente.login('admin@aguapura.gt', 'agua2026');

    expect(usuario['rol'], 'administrador');
    expect(cliente.haySesion, isTrue);
    expect(cliente.reclamos!['rol'], 'administrador');
    expect(cliente.tiempoRestante!.inHours, greaterThan(0));
  }, skip: false);

  test('una clave incorrecta no abre sesion', () async {
    if (omitir()) return;

    final otro = ClienteHttp(baseUrl: _base);
    await expectLater(
      otro.login('admin@aguapura.gt', 'incorrecta'),
      throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', 401)),
    );
    expect(otro.haySesion, isFalse);
    otro.cerrar();
  });

  test('el catalogo llega completo', () async {
    if (omitir()) return;
    await cliente.login('admin@aguapura.gt', 'agua2026');

    expect(await cliente.listar('/parametros'), hasLength(7));
    expect((await cliente.listar('/puntos')).length, greaterThanOrEqualTo(7));
    expect((await cliente.listar('/zonas')).length, greaterThanOrEqualTo(4));
  });

  test('el servidor asigna el id al crear una zona, y rechaza duplicados',
      () async {
    if (omitir()) return;
    await cliente.login('admin@aguapura.gt', 'agua2026');

    final nombre = 'Zona de prueba ${DateTime.now().microsecondsSinceEpoch}';
    final creada = await cliente.guardarZona({'id': 0, 'nombre': nombre});

    expect(creada['id'], isA<int>());
    expect(creada['id'], greaterThan(0));

    await expectLater(
      cliente.guardarZona({'id': 0, 'nombre': nombre}),
      throwsA(
        isA<ErrorApi>().having((e) => e.codigo, 'codigo', 409),
      ),
    );

    await cliente.eliminarZona(creada['id'] as int);
  });

  test('el rol calidad no puede administrar', () async {
    if (omitir()) return;

    final calidad = ClienteHttp(baseUrl: _base);
    await calidad.login('calidad@aguapura.gt', 'agua2026');

    await expectLater(
      calidad.guardarZona({'id': 0, 'nombre': 'No permitida'}),
      throwsA(
        isA<ErrorApi>().having((e) => e.codigo, 'codigo', 403),
      ),
    );
    calidad.cerrar();
  });

  test('la sincronizacion es idempotente', () async {
    if (omitir()) return;

    final operario = ClienteHttp(baseUrl: _base);
    await operario.login('operario@aguapura.gt', 'agua2026');

    final idLocal = DateTime.now().millisecondsSinceEpoch % 1000000;
    final cola = [
      {
        'id_local': idLocal,
        'punto_id': 1,
        'fecha_hora': '2026-08-25T06:15:00Z',
        'creado_en': '2026-08-25T11:40:00Z',
        'clasificacion_global': 'incumplimiento',
        'parametro_limitante_id': 3,
        'observaciones': 'enviada desde el cliente Flutter',
        'mediciones': [
          {
            'parametro_id': 3,
            'valor': 0.05,
            'origen': 'manual',
            'clasificacion': 'incumplimiento',
          },
        ],
      },
    ];

    final primera = await operario.sincronizar(cola);
    expect(primera['recibidas'], 1);

    final reintento = await operario.sincronizar(cola);
    expect(reintento['recibidas'], 0);
    expect(reintento['repetidas'], 1,
        reason: 'un reintento tras un corte de red no debe duplicar muestras');

    operario.cerrar();
  });

  test('el token queda invalido tras cerrar sesion', () async {
    if (omitir()) return;

    final otro = ClienteHttp(baseUrl: _base);
    await otro.login('admin@aguapura.gt', 'agua2026');
    expect(otro.haySesion, isTrue);

    await otro.logout();
    expect(otro.haySesion, isFalse);
    otro.cerrar();
  });
}
