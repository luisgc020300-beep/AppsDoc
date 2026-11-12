// test/services/funcionalidad_service_test.dart
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
  });

  test('crear() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/funcionalidades y streamFuncionalidades() lo devuelve', () async {
    final id = await FuncionalidadService.crear(proyectoId: proyectoId, nombre: 'Login', notas: 'con Google');

    final lista = await FuncionalidadService.streamFuncionalidades(proyectoId).first;

    expect(lista, hasLength(1));
    expect(lista.single.id, id);
    expect(lista.single.proyectoId, proyectoId);
    expect(lista.single.nombre, 'Login');
    expect(lista.single.notas, 'con Google');
    expect(lista.single.estado, EstadoFuncionalidad.planificada);
  });

  test('crear() con el nombre vacío falla y no escribe nada', () async {
    await expectLater(FuncionalidadService.crear(proyectoId: proyectoId, nombre: '   '), throwsArgumentError);

    final lista = await FuncionalidadService.streamFuncionalidades(proyectoId).first;
    expect(lista, isEmpty);
  });

  test('actualizar() cambia solo los campos indicados', () async {
    final id = await FuncionalidadService.crear(proyectoId: proyectoId, nombre: 'Original', descripcion: 'desc');

    await FuncionalidadService.actualizar(proyectoId, id, estado: EstadoFuncionalidad.completada, notas: 'ya probado');

    final f = (await FuncionalidadService.streamFuncionalidades(proyectoId).first).single;
    expect(f.nombre, 'Original');
    expect(f.descripcion, 'desc');
    expect(f.estado, EstadoFuncionalidad.completada);
    expect(f.notas, 'ya probado');
  });

  test('eliminar() quita la funcionalidad de la lista', () async {
    final id = await FuncionalidadService.crear(proyectoId: proyectoId, nombre: 'A borrar');

    await FuncionalidadService.eliminar(proyectoId, id);

    expect(await FuncionalidadService.streamFuncionalidades(proyectoId).first, isEmpty);
  });

  test('las funcionalidades de un proyecto no aparecen en otro', () async {
    await FuncionalidadService.crear(proyectoId: 'p1', nombre: 'De p1');
    await FuncionalidadService.crear(proyectoId: 'p2', nombre: 'De p2');

    final deP1 = await FuncionalidadService.streamFuncionalidades('p1').first;
    final deP2 = await FuncionalidadService.streamFuncionalidades('p2').first;

    expect(deP1.map((f) => f.nombre), ['De p1']);
    expect(deP2.map((f) => f.nombre), ['De p2']);
  });

  test('sin sesión (uid null), streamFuncionalidades() devuelve vacío y crear() lanza', () async {
    FuncionalidadService.debugUidOverride = null;

    expect(await FuncionalidadService.streamFuncionalidades(proyectoId).first, isEmpty);
    await expectLater(FuncionalidadService.crear(proyectoId: proyectoId, nombre: 'X'), throwsStateError);
  });
}
