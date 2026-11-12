// test/services/idea_service_test.dart
import 'package:appsdoc/models/estado_idea.dart';
import 'package:appsdoc/services/idea_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    IdeaService.debugFirestoreOverride = db;
    IdeaService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    IdeaService.debugFirestoreOverride = null;
    IdeaService.debugUidOverride = null;
  });

  test('crear() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/ideas y streamIdeas() lo devuelve', () async {
    final id = await IdeaService.crear(proyectoId: proyectoId, titulo: 'Widgets de pantalla de inicio', notas: 'aparcada antes');

    final lista = await IdeaService.streamIdeas(proyectoId).first;

    expect(lista, hasLength(1));
    expect(lista.single.id, id);
    expect(lista.single.titulo, 'Widgets de pantalla de inicio');
    expect(lista.single.notas, 'aparcada antes');
    expect(lista.single.estado, EstadoIdea.nueva);
  });

  test('crear() con el título vacío falla y no escribe nada', () async {
    await expectLater(IdeaService.crear(proyectoId: proyectoId, titulo: '   '), throwsArgumentError);

    expect(await IdeaService.streamIdeas(proyectoId).first, isEmpty);
  });

  test('actualizar() cambia solo los campos indicados', () async {
    final id = await IdeaService.crear(proyectoId: proyectoId, titulo: 'Original', descripcion: 'desc');

    await IdeaService.actualizar(proyectoId, id, estado: EstadoIdea.aceptada, notas: 'convencido');

    final i = (await IdeaService.streamIdeas(proyectoId).first).single;
    expect(i.titulo, 'Original');
    expect(i.descripcion, 'desc');
    expect(i.estado, EstadoIdea.aceptada);
    expect(i.notas, 'convencido');
  });

  test('actualizar() con título vacío falla sin tocar el documento', () async {
    final id = await IdeaService.crear(proyectoId: proyectoId, titulo: 'Original');

    await expectLater(IdeaService.actualizar(proyectoId, id, titulo: '   '), throwsArgumentError);

    final i = (await IdeaService.streamIdeas(proyectoId).first).single;
    expect(i.titulo, 'Original');
  });

  test('eliminar() quita la idea de la lista', () async {
    final id = await IdeaService.crear(proyectoId: proyectoId, titulo: 'A borrar');

    await IdeaService.eliminar(proyectoId, id);

    expect(await IdeaService.streamIdeas(proyectoId).first, isEmpty);
  });

  test('las ideas de un proyecto no aparecen en otro', () async {
    await IdeaService.crear(proyectoId: 'p1', titulo: 'De p1');
    await IdeaService.crear(proyectoId: 'p2', titulo: 'De p2');

    expect((await IdeaService.streamIdeas('p1').first).map((i) => i.titulo), ['De p1']);
    expect((await IdeaService.streamIdeas('p2').first).map((i) => i.titulo), ['De p2']);
  });

  test('sin sesión (uid null), streamIdeas() devuelve vacío y crear() lanza', () async {
    IdeaService.debugUidOverride = null;

    expect(await IdeaService.streamIdeas(proyectoId).first, isEmpty);
    await expectLater(IdeaService.crear(proyectoId: proyectoId, titulo: 'X'), throwsStateError);
  });
}
