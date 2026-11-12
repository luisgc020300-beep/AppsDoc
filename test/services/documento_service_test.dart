// test/services/documento_service_test.dart
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/categoria_documento.dart';
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
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-1';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-1';
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-1';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-1';
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-1';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
  });

  test('crear() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/documentos y streamDocumentos() lo devuelve', () async {
    final id = await DocumentoService.crear(proyectoId: proyectoId, titulo: 'Decisión inicial', contenido: 'por qué Firestore');

    final lista = await DocumentoService.streamDocumentos(proyectoId).first;

    expect(lista, hasLength(1));
    expect(lista.single.id, id);
    expect(lista.single.proyectoId, proyectoId);
    expect(lista.single.titulo, 'Decisión inicial');
    expect(lista.single.contenido, 'por qué Firestore');
    expect(lista.single.categoria, CategoriaDocumento.nota);
  });

  test('crear() con el título vacío falla y no escribe nada', () async {
    await expectLater(DocumentoService.crear(proyectoId: proyectoId, titulo: '   '), throwsArgumentError);

    expect(await DocumentoService.streamDocumentos(proyectoId).first, isEmpty);
  });

  test('actualizar() cambia solo los campos indicados', () async {
    final id = await DocumentoService.crear(proyectoId: proyectoId, titulo: 'Original', contenido: 'texto original');

    await DocumentoService.actualizar(proyectoId, id, categoria: CategoriaDocumento.arquitectura);

    final d = (await DocumentoService.streamDocumentos(proyectoId).first).single;
    expect(d.titulo, 'Original');
    expect(d.contenido, 'texto original');
    expect(d.categoria, CategoriaDocumento.arquitectura);
  });

  test('actualizar() con título vacío falla sin tocar el documento', () async {
    final id = await DocumentoService.crear(proyectoId: proyectoId, titulo: 'Original');

    await expectLater(DocumentoService.actualizar(proyectoId, id, titulo: '   '), throwsArgumentError);

    final d = (await DocumentoService.streamDocumentos(proyectoId).first).single;
    expect(d.titulo, 'Original');
  });

  test('eliminar() quita el documento de la lista', () async {
    final id = await DocumentoService.crear(proyectoId: proyectoId, titulo: 'A borrar');

    await DocumentoService.eliminar(proyectoId, id);

    expect(await DocumentoService.streamDocumentos(proyectoId).first, isEmpty);
  });

  test('los documentos de un proyecto no aparecen en otro', () async {
    await DocumentoService.crear(proyectoId: 'p1', titulo: 'De p1');
    await DocumentoService.crear(proyectoId: 'p2', titulo: 'De p2');

    expect((await DocumentoService.streamDocumentos('p1').first).map((d) => d.titulo), ['De p1']);
    expect((await DocumentoService.streamDocumentos('p2').first).map((d) => d.titulo), ['De p2']);
  });

  test('sin sesión (uid null), streamDocumentos() devuelve vacío y crear() lanza', () async {
    DocumentoService.debugUidOverride = null;

    expect(await DocumentoService.streamDocumentos(proyectoId).first, isEmpty);
    await expectLater(DocumentoService.crear(proyectoId: proyectoId, titulo: 'X'), throwsStateError);
  });

  test('crear() también registra un evento de creación en el historial', () async {
    await DocumentoService.crear(proyectoId: proyectoId, titulo: 'Decisión inicial');

    final historial = await HistorialService.streamHistorial(proyectoId).first;

    expect(historial, hasLength(1));
    expect(historial.single.accion, AccionHistorial.creado);
    expect(historial.single.descripcion, contains('Decisión inicial'));
  });

  test('actualizar() también registra un evento de actualización en el historial', () async {
    final id = await DocumentoService.crear(proyectoId: proyectoId, titulo: 'Original');
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await DocumentoService.actualizar(proyectoId, id, categoria: CategoriaDocumento.arquitectura);

    final historial = await HistorialService.streamHistorial(proyectoId).first;
    expect(historial, hasLength(2), reason: 'crear() + actualizar()');
    expect(historial.first.accion, AccionHistorial.actualizado);
    expect(historial.first.descripcion, contains('categoría'));
  });
}
