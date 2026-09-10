@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:potable/core/config.dart';
import 'package:potable/datos/api/cliente.dart';
import 'package:potable/datos/api/cliente_http.dart';

void main() {
  const base = 'http://localhost:3000';

  Config.cargarDesdeMapa({'API_BASE_URL': base, 'API_TIMEOUT_MS': '5000'});

  late ClienteHttp cliente;
  var servidorArriba = false;

  setUpAll(() async {
    cliente = ClienteHttp(baseUrl: base);
    servidorArriba = await cliente.disponible();
    if (!servidorArriba) {
      // ignore: avoid_print
      print('AVISO: el backend no responde en $base, se omiten las pruebas.');
    }
  });

  tearDownAll(() => cliente.cerrar());

  void requiereServidor() {
    if (!servidorArriba) {
      markTestSkipped('El backend no esta corriendo en $base');
    }
  }

  group('autenticacion', () {
    test('el login devuelve un token y el usuario', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final usuario = await cliente.login('admin@aguapura.gt', 'agua2026');

      expect(usuario['correo'], 'admin@aguapura.gt');
      expect(usuario['rol'], 'administrador');
      expect(cliente.haySesion, isTrue);

      expect(cliente.reclamos?['rol'], 'administrador');
      expect(cliente.tiempoRestante!.inMinutes, greaterThan(0));
    });

    test('una clave incorrecta devuelve 401', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final otro = ClienteHttp(baseUrl: base);
      await expectLater(
        otro.login('admin@aguapura.gt', 'incorrecta'),
        throwsA(isA<ErrorApi>()),
      );
      otro.cerrar();
    });

    test('sin token, una ruta protegida rechaza la sesion', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final anonimo = ClienteHttp(baseUrl: base);
      await expectLater(
        anonimo.perfil(),
        throwsA(isA<SesionExpirada>()),
      );
      anonimo.cerrar();
    });

    test('el perfil valida el token contra el servidor', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');
      final perfil = await cliente.perfil();
      expect(perfil['correo'], 'admin@aguapura.gt');
    });

    test('un token alterado se rechaza', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final falso = ClienteHttp(baseUrl: base)
        ..restaurarToken('eyJhbGciOiJIUzI1NiJ9.falsificado.firma-invalida');

      await expectLater(falso.perfil(), throwsA(isA<SesionExpirada>()));
      falso.cerrar();
    });
  });

  group('catalogo', () {
    test('trae los siete parametros normados', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');
      final parametros = await cliente.listar('/parametros');

      expect(parametros, hasLength(7));

      final ph = parametros.firstWhere((p) => p['nombre'] == 'pH');
      expect(ph['limite_min'], 6);
      expect(ph['limite_max'], 8.5);
      expect(ph['via_captura'], 'sensor');

      final cloro =
          parametros.firstWhere((p) => p['nombre'] == 'Cloro residual libre');
      expect(cloro['critico'], isTrue);
    });

    test('las zonas traen los puntos de la organizacion', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');
      expect(await cliente.listar('/zonas'), isNotEmpty);
      expect(await cliente.listar('/puntos'), isNotEmpty);
    });
  });

  group('autorizacion por rol', () {
    test('control de calidad no puede crear zonas', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final calidad = ClienteHttp(baseUrl: base);
      await calidad.login('calidad@aguapura.gt', 'agua2026');

      await expectLater(
        calidad.guardarZona({'id': 0, 'nombre': 'No permitida'}),
        throwsA(
          isA<ErrorApi>().having((e) => e.codigo, 'codigo', 403),
        ),
      );
      calidad.cerrar();
    });

    test('el administrador si puede, y no admite nombres repetidos', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');
      final nombre = 'Zona de prueba ${DateTime.now().microsecondsSinceEpoch}';

      final creada = await cliente.guardarZona({'id': 0, 'nombre': nombre});
      expect(creada['id'], isA<int>());

      await expectLater(
        cliente.guardarZona({'id': 0, 'nombre': nombre}),
        throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', 409)),
      );

      await cliente.eliminarZona(creada['id'] as int);
    });
  });

  group('sincronizacion', () {
    Map<String, dynamic> muestraDePrueba(int idLocal) => {
          'id_local': idLocal,
          'punto_id': 1,
          'fecha_hora': '2026-08-25T06:15:00Z',
          'creado_en': '2026-08-25T11:40:00Z',
          'clasificacion_global': 'incumplimiento',
          'parametro_limitante_id': 3,
          'observaciones': 'prueba de integracion',
          'mediciones': [
            {
              'parametro_id': 1,
              'valor': 7.2,
              'origen': 'sensor',
              'clasificacion': 'apto',
            },
            {
              'parametro_id': 3,
              'valor': 0.05,
              'origen': 'manual',
              'clasificacion': 'incumplimiento',
            },
          ],
        };

    test('envia la cola y el reintento no duplica', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final operario = ClienteHttp(baseUrl: base);
      await operario.login('operario@aguapura.gt', 'agua2026');

      final idLocal = DateTime.now().millisecondsSinceEpoch % 1000000;
      final cola = [muestraDePrueba(idLocal)];

      final primera = await operario.sincronizar(cola);
      expect(primera['recibidas'], 1);
      expect(primera['repetidas'], 0);

      final reintento = await operario.sincronizar(cola);
      expect(reintento['recibidas'], 0);
      expect(reintento['repetidas'], 1);

      operario.cerrar();
    });

    test('rechaza una muestra sin mediciones', () async {
      requiereServidor();
      if (!servidorArriba) return;

      final operario = ClienteHttp(baseUrl: base);
      await operario.login('operario@aguapura.gt', 'agua2026');

      await expectLater(
        operario.sincronizar([
          {
            'id_local': 999999,
            'punto_id': 1,
            'fecha_hora': '2026-08-25T06:15:00Z',
            'clasificacion_global': 'apto',
            'mediciones': <Map<String, dynamic>>[],
          },
        ]),
        throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', 422)),
      );
      operario.cerrar();
    });
  });

  group('descarga del catalogo', () {
    test('trae del servidor lo que otro dispositivo creo', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');

      final nombre = 'Zona remota ${DateTime.now().microsecondsSinceEpoch}';
      final creada = await cliente.guardarZona({'id': 0, 'nombre': nombre});

      final catalogo = await cliente.catalogo();

      expect(
        catalogo.zonas.any((z) => z['nombre'] == nombre),
        isTrue,
        reason: 'la zona nueva debe llegar en el catalogo',
      );
      expect(catalogo.parametros, hasLength(7));
      expect(catalogo.puntos, isNotEmpty);
      expect(catalogo.usuarios, isNotEmpty);
      expect(catalogo.organizacion['nombre'], isNotEmpty);

      await cliente.eliminarZona(creada['id'] as int);
    });

    test('el catalogo no expone hashes de contrasena', () async {
      requiereServidor();
      if (!servidorArriba) return;

      await cliente.login('admin@aguapura.gt', 'agua2026');
      final catalogo = await cliente.catalogo();

      for (final u in catalogo.usuarios) {
        expect(u.containsKey('clave_hash'), isFalse);
        expect(u['correo'], isNotEmpty);
        expect(u['rol'], isNotEmpty);
      }
    });
  });

  test('un servidor inexistente lanza SinConexion, no un error crudo',
      () async {
    final perdido = ClienteHttp(
      baseUrl: 'http://localhost:59999',
      timeout: const Duration(seconds: 2),
    );
    await expectLater(
      perdido.login('admin@aguapura.gt', 'agua2026'),
      throwsA(isA<SinConexion>()),
    );
    perdido.cerrar();
  });
}
