// test/services/proyecto_service_test.dart
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
  });

  test('crear() guarda el proyecto bajo usuarios/{uid}/proyectos y streamProyectos() lo devuelve', () async {
    final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');

    final proyectos = await ProyectoService.streamProyectos().first;

    expect(proyectos, hasLength(1));
    expect(proyectos.single.id, id);
    expect(proyectos.single.nombre, 'REPARA');
    expect(proyectos.single.descripcion, 'Mantenimiento del hogar');
    expect(proyectos.single.estado, EstadoProyecto.idea);
  });

  test('crear() con el nombre vacío (o solo espacios) falla y no escribe nada', () async {
    await expectLater(ProyectoService.crear(nombre: '   '), throwsArgumentError);

    final proyectos = await ProyectoService.streamProyectos().first;
    expect(proyectos, isEmpty);
  });

  test('crear() recorta espacios sueltos de nombre y descripción', () async {
    await ProyectoService.crear(nombre: '  Convive  ', descripcion: '  piso compartido  ');

    final proyecto = (await ProyectoService.streamProyectos().first).single;

    expect(proyecto.nombre, 'Convive');
    expect(proyecto.descripcion, 'piso compartido');
  });

  test('actualizar() cambia solo los campos indicados', () async {
    final id = await ProyectoService.crear(nombre: 'Original', descripcion: 'desc original');

    await ProyectoService.actualizar(id, estado: EstadoProyecto.enDesarrollo);

    final proyecto = (await ProyectoService.streamProyectos().first).single;
    expect(proyecto.nombre, 'Original');
    expect(proyecto.descripcion, 'desc original');
    expect(proyecto.estado, EstadoProyecto.enDesarrollo);
  });

  test('actualizar() con nombre vacío falla sin tocar el documento', () async {
    final id = await ProyectoService.crear(nombre: 'Original');

    await expectLater(ProyectoService.actualizar(id, nombre: '   '), throwsArgumentError);

    final proyecto = (await ProyectoService.streamProyectos().first).single;
    expect(proyecto.nombre, 'Original');
  });

  test('eliminar() quita el proyecto de la lista', () async {
    final id = await ProyectoService.crear(nombre: 'A borrar');

    await ProyectoService.eliminar(id);

    final proyectos = await ProyectoService.streamProyectos().first;
    expect(proyectos, isEmpty);
  });

  test('streamProyectos() solo devuelve los proyectos del uid actual', () async {
    await ProyectoService.crear(nombre: 'Mío');

    ProyectoService.debugUidOverride = 'uid-2';
    final proyectosDeOtro = await ProyectoService.streamProyectos().first;

    expect(proyectosDeOtro, isEmpty);
  });

  test('sin sesión (uid null), streamProyectos() devuelve vacío y crear() lanza', () async {
    ProyectoService.debugUidOverride = null;

    final proyectos = await ProyectoService.streamProyectos().first;
    expect(proyectos, isEmpty);

    await expectLater(ProyectoService.crear(nombre: 'X'), throwsStateError);
  });

  test('streamProyectos() ordena por updatedAt descendente', () async {
    final idViejo = await ProyectoService.crear(nombre: 'Viejo');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final idNuevo = await ProyectoService.crear(nombre: 'Nuevo');

    final proyectos = await ProyectoService.streamProyectos().first;

    expect(proyectos.map((p) => p.id), [idNuevo, idViejo]);
  });

  test('streamProyecto(id) devuelve ese proyecto concreto', () async {
    final id = await ProyectoService.crear(nombre: 'Uno', descripcion: 'd');
    await ProyectoService.crear(nombre: 'Otro');

    final proyecto = await ProyectoService.streamProyecto(id).first;

    expect(proyecto, isNotNull);
    expect(proyecto!.nombre, 'Uno');
  });

  test('streamProyecto(id) devuelve null si no existe (o ya se eliminó)', () async {
    final id = await ProyectoService.crear(nombre: 'Efímero');
    await ProyectoService.eliminar(id);

    final proyecto = await ProyectoService.streamProyecto(id).first;

    expect(proyecto, isNull);
  });

  test('streamProyecto(id) devuelve null sin sesión', () async {
    ProyectoService.debugUidOverride = null;

    expect(await ProyectoService.streamProyecto('cualquiera').first, isNull);
  });
}
