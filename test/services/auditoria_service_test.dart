// test/services/auditoria_service_test.dart
import 'package:appsdoc/models/estado_hallazgo.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/origen_auditoria.dart';
import 'package:appsdoc/models/resultado_auditoria.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-1';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  test('crear() guarda bajo usuarios/{uid}/proyectos/{proyectoId}/auditorias y streamAuditorias() lo devuelve', () async {
    final fecha = DateTime(2026, 11, 10);
    final id = await AuditoriaService.crear(
      proyectoId: proyectoId,
      fecha: fecha,
      origen: OrigenAuditoria.claude,
      resumen: 'Resumen pegado desde Claude',
      resultado: ResultadoAuditoria.rechazado,
    );

    final lista = await AuditoriaService.streamAuditorias(proyectoId).first;

    expect(lista, hasLength(1));
    expect(lista.single.id, id);
    expect(lista.single.fecha, fecha);
    expect(lista.single.origen, OrigenAuditoria.claude);
    expect(lista.single.resumen, 'Resumen pegado desde Claude');
    expect(lista.single.resultado, ResultadoAuditoria.rechazado);
    expect(lista.single.hallazgos, isEmpty);
  });

  test('crear() con el resumen vacío falla y no escribe nada', () async {
    await expectLater(
      AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: '   '),
      throwsArgumentError,
    );

    expect(await AuditoriaService.streamAuditorias(proyectoId).first, isEmpty);
  });

  test('crear() también registra un evento en el historial', () async {
    await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');

    final historial = await HistorialService.streamHistorial(proyectoId).first;

    expect(historial, hasLength(1));
    expect(historial.single.descripcion, contains('Auditoría creada'));
  });

  test('eliminar() quita la auditoría de la lista', () async {
    final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'A borrar');

    await AuditoriaService.eliminar(proyectoId, id);

    expect(await AuditoriaService.streamAuditorias(proyectoId).first, isEmpty);
  });

  group('hallazgos', () {
    test('agregarHallazgo() lo añade con estado "abierto" por defecto', () async {
      final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');

      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Falta validación', gravedad: GravedadHallazgo.alta);

      final auditoria = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      expect(auditoria.hallazgos, hasLength(1));
      expect(auditoria.hallazgos.single.titulo, 'Falta validación');
      expect(auditoria.hallazgos.single.gravedad, GravedadHallazgo.alta);
      expect(auditoria.hallazgos.single.estado, EstadoHallazgo.abierto);
    });

    test('agregarHallazgo() con título vacío falla y no añade nada', () async {
      final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');

      await expectLater(
        AuditoriaService.agregarHallazgo(proyectoId, id, titulo: '   '),
        throwsArgumentError,
      );

      final auditoria = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      expect(auditoria.hallazgos, isEmpty);
    });

    test('agregarHallazgo() también registra un evento en el historial', () async {
      final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');
      await Future<void>.delayed(const Duration(milliseconds: 2));

      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Nuevo hallazgo');

      final historial = await HistorialService.streamHistorial(proyectoId).first;
      expect(historial, hasLength(2), reason: 'crear() + agregarHallazgo()');
      expect(historial.first.descripcion, contains('nuevo hallazgo'));
    });

    test('actualizarEstadoHallazgo() cambia solo el hallazgo indicado', () async {
      final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');
      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Uno');
      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Dos');
      final auditoria = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      final hallazgoUno = auditoria.hallazgos.firstWhere((h) => h.titulo == 'Uno');

      await AuditoriaService.actualizarEstadoHallazgo(proyectoId, id, hallazgoUno.id, EstadoHallazgo.resuelto);

      final actualizada = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      final uno = actualizada.hallazgos.firstWhere((h) => h.titulo == 'Uno');
      final dos = actualizada.hallazgos.firstWhere((h) => h.titulo == 'Dos');
      expect(uno.estado, EstadoHallazgo.resuelto);
      expect(dos.estado, EstadoHallazgo.abierto);
    });

    test('eliminarHallazgo() quita solo ese hallazgo', () async {
      final id = await AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X');
      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Uno');
      await AuditoriaService.agregarHallazgo(proyectoId, id, titulo: 'Dos');
      final auditoria = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      final hallazgoUno = auditoria.hallazgos.firstWhere((h) => h.titulo == 'Uno');

      await AuditoriaService.eliminarHallazgo(proyectoId, id, hallazgoUno.id);

      final actualizada = (await AuditoriaService.streamAuditorias(proyectoId).first).single;
      expect(actualizada.hallazgos.map((h) => h.titulo), ['Dos']);
    });
  });

  test('sin sesión (uid null), streamAuditorias() devuelve vacío y crear() lanza', () async {
    AuditoriaService.debugUidOverride = null;

    expect(await AuditoriaService.streamAuditorias(proyectoId).first, isEmpty);
    await expectLater(
      AuditoriaService.crear(proyectoId: proyectoId, fecha: DateTime.now(), resumen: 'X'),
      throwsStateError,
    );
  });
}
