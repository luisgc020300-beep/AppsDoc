// test/services/historial_service_test.dart
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/tipo_entidad_historial.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    HistorialService.debugFirestoreOverride = FakeFirebaseFirestore();
    HistorialService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  test('registrar() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/historial y streamHistorial() lo devuelve', () async {
    await HistorialService.registrar(
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'Proyecto creado: "REPARA"',
    );

    final eventos = await HistorialService.streamHistorial('p1').first;

    expect(eventos, hasLength(1));
    expect(eventos.single.entidad, TipoEntidadHistorial.proyecto);
    expect(eventos.single.accion, AccionHistorial.creado);
    expect(eventos.single.descripcion, 'Proyecto creado: "REPARA"');
  });

  test('streamHistorial() ordena por fecha descendente (lo más reciente primero)', () async {
    await HistorialService.registrar(
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'Primero',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await HistorialService.registrar(
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.tarea,
      accion: AccionHistorial.creado,
      descripcion: 'Segundo',
    );

    final eventos = await HistorialService.streamHistorial('p1').first;

    expect(eventos.map((e) => e.descripcion), ['Segundo', 'Primero']);
  });

  test('los eventos de un proyecto no aparecen en otro', () async {
    await HistorialService.registrar(
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'De p1',
    );
    await HistorialService.registrar(
      proyectoId: 'p2',
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'De p2',
    );

    expect((await HistorialService.streamHistorial('p1').first).map((e) => e.descripcion), ['De p1']);
    expect((await HistorialService.streamHistorial('p2').first).map((e) => e.descripcion), ['De p2']);
  });

  test('sin sesión (uid null), streamHistorial() devuelve vacío y registrar() no lanza ni escribe nada', () async {
    HistorialService.debugUidOverride = null;

    expect(await HistorialService.streamHistorial('p1').first, isEmpty);

    // No debe lanzar -- un evento de historial que no se pudo registrar
    // nunca debe tumbar la operación principal que lo disparó.
    await HistorialService.registrar(
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'X',
    );
  });
}
