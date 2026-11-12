// test/services/tarea_service_test.dart
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/models/prioridad_tarea.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  // crear()/actualizar()/eliminar() disparan recalcularProgreso(), que lee
  // las otras tres subcolecciones y escribe en ProyectoService -- todos
  // necesitan su seam de test apuntando al mismo Firestore falso.
  setUp(() {
    db = FakeFirebaseFirestore();
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-1';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-1';
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-1';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-1';
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-1';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
  });

  test('crear() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/tareas y streamTareas() lo devuelve', () async {
    final limite = DateTime(2026, 12, 1);
    final id = await TareaService.crear(
      proyectoId: proyectoId,
      titulo: 'Escribir tests',
      prioridad: PrioridadTarea.alta,
      fechaLimite: limite,
    );

    final lista = await TareaService.streamTareas(proyectoId).first;

    expect(lista, hasLength(1));
    expect(lista.single.id, id);
    expect(lista.single.titulo, 'Escribir tests');
    expect(lista.single.prioridad, PrioridadTarea.alta);
    expect(lista.single.estado, EstadoTarea.pendiente);
    expect(lista.single.fechaLimite, limite);
  });

  test('crear() con el título vacío falla y no escribe nada', () async {
    await expectLater(TareaService.crear(proyectoId: proyectoId, titulo: '   '), throwsArgumentError);

    expect(await TareaService.streamTareas(proyectoId).first, isEmpty);
  });

  test('actualizar() cambia solo los campos indicados', () async {
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'Original');

    await TareaService.actualizar(proyectoId, id, estado: EstadoTarea.completada);

    final t = (await TareaService.streamTareas(proyectoId).first).single;
    expect(t.titulo, 'Original');
    expect(t.estado, EstadoTarea.completada);
    expect(t.prioridad, PrioridadTarea.media);
  });

  test('actualizar() con quitarFechaLimite=true borra la fecha ya puesta', () async {
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'X', fechaLimite: DateTime(2026, 12, 1));

    await TareaService.actualizar(proyectoId, id, quitarFechaLimite: true);

    final t = (await TareaService.streamTareas(proyectoId).first).single;
    expect(t.fechaLimite, isNull);
  });

  test('actualizar() sin tocar la fecha límite la conserva', () async {
    final limite = DateTime(2026, 12, 1);
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'X', fechaLimite: limite);

    await TareaService.actualizar(proyectoId, id, estado: EstadoTarea.enProgreso);

    final t = (await TareaService.streamTareas(proyectoId).first).single;
    expect(t.fechaLimite, limite);
  });

  test('cambiar solo el estado (como desde la lista) no toca el resto de campos', () async {
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'Original', descripcion: 'desc', prioridad: PrioridadTarea.alta);

    await TareaService.actualizar(proyectoId, id, estado: EstadoTarea.completada);

    final t = (await TareaService.streamTareas(proyectoId).first).single;
    expect(t.titulo, 'Original');
    expect(t.descripcion, 'desc');
    expect(t.prioridad, PrioridadTarea.alta);
    expect(t.estado, EstadoTarea.completada);
  });

  test('eliminar() quita la tarea de la lista', () async {
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'A borrar');

    await TareaService.eliminar(proyectoId, id);

    expect(await TareaService.streamTareas(proyectoId).first, isEmpty);
  });

  test('las tareas de un proyecto no aparecen en otro', () async {
    await TareaService.crear(proyectoId: 'p1', titulo: 'De p1');
    await TareaService.crear(proyectoId: 'p2', titulo: 'De p2');

    expect((await TareaService.streamTareas('p1').first).map((t) => t.titulo), ['De p1']);
    expect((await TareaService.streamTareas('p2').first).map((t) => t.titulo), ['De p2']);
  });

  test('sin sesión (uid null), streamTareas() devuelve vacío y crear() lanza', () async {
    TareaService.debugUidOverride = null;

    expect(await TareaService.streamTareas(proyectoId).first, isEmpty);
    await expectLater(TareaService.crear(proyectoId: proyectoId, titulo: 'X'), throwsStateError);
  });

  test('crear() también registra un evento de creación en el historial', () async {
    await TareaService.crear(proyectoId: proyectoId, titulo: 'Escribir tests');

    final historial = await HistorialService.streamHistorial(proyectoId).first;

    expect(historial, hasLength(1));
    expect(historial.single.accion, AccionHistorial.creado);
    expect(historial.single.descripcion, contains('Escribir tests'));
  });

  test('actualizar() también registra un evento de actualización en el historial', () async {
    final id = await TareaService.crear(proyectoId: proyectoId, titulo: 'Original');
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await TareaService.actualizar(proyectoId, id, estado: EstadoTarea.completada);

    final historial = await HistorialService.streamHistorial(proyectoId).first;
    expect(historial, hasLength(2), reason: 'crear() + actualizar()');
    expect(historial.first.accion, AccionHistorial.actualizado);
    expect(historial.first.descripcion, contains('estado'));
  });
}
