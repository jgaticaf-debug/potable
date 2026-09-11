import 'package:flutter_test/flutter_test.dart';
import 'package:potable/datos/api/cliente_api.dart';
import 'package:potable/datos/api/mock_api.dart';
import 'package:potable/datos/estado_app.dart';
import 'package:potable/datos/local/base_datos.dart';
import 'package:potable/datos/repositorio_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late EstadoApp estado;

  setUp(() async {
    final db = await BaseDatosLocal.abrirEnMemoria();
    final repo = RepositorioSqlite(db, cliente: ClienteApi(MockApi()));
    await repo.sembrarSiEstaVacia();

    estado = EstadoApp(repo);
    await estado.iniciarSesion('admin@aguapura.gt', MockApi.claveDemo);
    await estado.cargarCatalogo(descargar: false);
  });

  test('cambiar el propio nombre se refleja en la sesion', () async {
    final yo = estado.usuario!;
    expect(yo.nombre, isNotEmpty);

    final error = await estado.guardarUsuario(
      yo.copyCon(nombre: 'Jason Gatica Flores'),
    );

    expect(error, isNull);
    expect(
      estado.usuario!.nombre,
      'Jason Gatica Flores',
      reason: 'el tablero lee de aqui, no de la lista de usuarios',
    );
    expect(estado.usuario!.id, yo.id);
  });

  test('editar a otro no cambia el usuario de la sesion', () async {
    final yo = estado.usuario!;
    final otro = estado.usuarios.firstWhere((u) => u.id != yo.id);

    await estado.guardarUsuario(otro.copyCon(nombre: 'Alguien Mas'));

    expect(estado.usuario!.id, yo.id);
    expect(estado.usuario!.nombre, yo.nombre);
  });

  test('recargar el catalogo tambien actualiza la sesion', () async {
    final yo = estado.usuario!;

    // Simula que otro administrador me renombro: el cambio entra por la
    // recarga, no por mi propia edicion.
    await estado.guardarUsuario(yo.copyCon(nombre: 'Nombre Desde Afuera'));
    await estado.cargarCatalogo(descargar: false);

    expect(estado.usuario!.nombre, 'Nombre Desde Afuera');
  });
}
