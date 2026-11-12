// test/services/proyecto_service_test.dart
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
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

  // crear() de ProyectoService siempre dispara recalcularProgreso(), que a
  // su vez lee las cuatro subcolecciones -- todos los servicios implicados
  // necesitan su propio seam de test apuntando al mismo Firestore falso.
  setUp(() {
    db = FakeFirebaseFirestore();
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-1';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-1';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-1';
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-1';
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-1';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
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

  test('crear() también registra un evento de creación en el historial', () async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    final historial = await HistorialService.streamHistorial(id).first;

    expect(historial, hasLength(1));
    expect(historial.single.accion, AccionHistorial.creado);
    expect(historial.single.descripcion, contains('REPARA'));
  });

  test('actualizar() también registra un evento de actualización en el historial, listando los campos cambiados', () async {
    final id = await ProyectoService.crear(nombre: 'Original');
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await ProyectoService.actualizar(id, estado: EstadoProyecto.lanzado);

    final historial = await HistorialService.streamHistorial(id).first;
    expect(historial, hasLength(2), reason: 'crear() + actualizar()');
    expect(historial.first.accion, AccionHistorial.actualizado);
    expect(historial.first.descripcion, contains('estado'));
  });

  test('actualizar() sin ningún campo no registra un evento nuevo en el historial', () async {
    final id = await ProyectoService.crear(nombre: 'Original');

    await ProyectoService.actualizar(id);

    final historial = await HistorialService.streamHistorial(id).first;
    expect(historial, hasLength(1), reason: 'solo el de crear()');
  });

  group('progresoPorcentaje (recalcularProgreso)', () {
    test('crear() ya calcula un progreso real, no 0 a secas', () async {
      final id = await ProyectoService.crear(nombre: 'REPARA');

      final proyecto = await ProyectoService.streamProyecto(id).first;

      // Sin funcionalidades/tareas/documentos/auditorías: 0 (funcionalidades)
      // + 30 (sin hallazgos críticos) + 15 (sin tareas vencidas) + 0 (sin
      // documentación base) = 45.
      expect(proyecto!.progresoPorcentaje, 45);
    });

    test('crear una funcionalidad completada sube el progreso del proyecto', () async {
      final id = await ProyectoService.crear(nombre: 'REPARA');

      await FuncionalidadService.crear(proyectoId: id, nombre: 'Login', estado: EstadoFuncionalidad.completada);

      final proyecto = await ProyectoService.streamProyecto(id).first;
      expect(proyecto!.progresoPorcentaje, 85); // 45 + 40 (100% de 1/1 completada)
    });

    test('actualizar() de nombre/descripción/estado del proyecto no recalcula el progreso', () async {
      final id = await ProyectoService.crear(nombre: 'REPARA');
      final inicial = (await ProyectoService.streamProyecto(id).first)!.progresoPorcentaje;

      await ProyectoService.actualizar(id, estado: EstadoProyecto.lanzado);

      final actualizado = await ProyectoService.streamProyecto(id).first;
      expect(actualizado!.progresoPorcentaje, inicial);
    });

    test('no hay ningún parámetro para fijar progresoPorcentaje a mano en crear() ni en actualizar()', () async {
      // Documentado como prueba, no solo como comentario: si alguien añade
      // ese parámetro más adelante, este test obliga a revisar la
      // decisión explícitamente ("no permitir modificar manualmente el
      // porcentaje").
      final id = await ProyectoService.crear(nombre: 'REPARA');
      await FuncionalidadService.crear(proyectoId: id, nombre: 'X', estado: EstadoFuncionalidad.completada);
      final antesDeActualizar = (await ProyectoService.streamProyecto(id).first)!.progresoPorcentaje;

      await ProyectoService.actualizar(id, nombre: 'Otro nombre');

      final despues = await ProyectoService.streamProyecto(id).first;
      expect(despues!.progresoPorcentaje, antesDeActualizar);
    });
  });
}
