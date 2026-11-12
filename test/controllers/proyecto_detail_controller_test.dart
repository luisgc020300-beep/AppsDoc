// test/controllers/proyecto_detail_controller_test.dart
import 'dart:async';

import 'package:appsdoc/controllers/proyecto_detail_controller.dart';
import 'package:appsdoc/models/documento.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/funcionalidad.dart';
import 'package:appsdoc/models/idea.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/models/tarea.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto() {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: 'p1', nombre: 'Demo', estado: EstadoProyecto.idea, createdAt: ahora, updatedAt: ahora);
}

void main() {
  test('empieza con proyectoCargando=true y las listas en null', () {
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: StreamController<Proyecto?>().stream,
      funcionalidadesStream: StreamController<List<Funcionalidad>>().stream,
      documentosStream: StreamController<List<Documento>>().stream,
      tareasStream: StreamController<List<Tarea>>().stream,
      ideasStream: StreamController<List<Idea>>().stream,
    );

    expect(controller.proyectoCargando, true);
    expect(controller.proyecto, isNull);
    expect(controller.funcionalidades, isNull);
    expect(controller.documentos, isNull);
    expect(controller.tareas, isNull);
    expect(controller.ideas, isNull);
  });

  test('cada stream actualiza su propio dato de forma independiente', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final funcionalidadesCtrl = StreamController<List<Funcionalidad>>();
    final documentosCtrl = StreamController<List<Documento>>();
    final tareasCtrl = StreamController<List<Tarea>>();
    final ideasCtrl = StreamController<List<Idea>>();
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: proyectoCtrl.stream,
      funcionalidadesStream: funcionalidadesCtrl.stream,
      documentosStream: documentosCtrl.stream,
      tareasStream: tareasCtrl.stream,
      ideasStream: ideasCtrl.stream,
    );

    proyectoCtrl.add(_proyecto());
    await Future<void>.delayed(Duration.zero);
    expect(controller.proyectoCargando, false);
    expect(controller.proyecto!.nombre, 'Demo');
    expect(controller.funcionalidades, isNull, reason: 'las funcionalidades todavía no han emitido nada');

    funcionalidadesCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.funcionalidades, isEmpty);
    expect(controller.documentos, isNull);

    documentosCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.documentos, isEmpty);
    expect(controller.tareas, isNull);

    tareasCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.tareas, isEmpty);
    expect(controller.ideas, isNull);

    ideasCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.ideas, isEmpty);

    await proyectoCtrl.close();
    await funcionalidadesCtrl.close();
    await documentosCtrl.close();
    await tareasCtrl.close();
    await ideasCtrl.close();
  });

  test('si el proyecto se elimina, el stream emite null y deja de estar "cargando"', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: proyectoCtrl.stream,
      funcionalidadesStream: const Stream.empty(),
      documentosStream: const Stream.empty(),
      tareasStream: const Stream.empty(),
      ideasStream: const Stream.empty(),
    );

    proyectoCtrl.add(_proyecto());
    await Future<void>.delayed(Duration.zero);
    expect(controller.proyecto, isNotNull);

    proyectoCtrl.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.proyecto, isNull);
    expect(controller.proyectoCargando, false);

    await proyectoCtrl.close();
  });

  test('un error en cualquiera de los streams se expone en error', () async {
    final funcionalidadesCtrl = StreamController<List<Funcionalidad>>();
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: const Stream.empty(),
      funcionalidadesStream: funcionalidadesCtrl.stream,
      documentosStream: const Stream.empty(),
      tareasStream: const Stream.empty(),
      ideasStream: const Stream.empty(),
    );

    funcionalidadesCtrl.addError(Exception('fallo de red'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.error, isNotNull);

    await funcionalidadesCtrl.close();
  });

  test('un error en el stream de tareas o ideas también se expone en error', () async {
    final tareasCtrl = StreamController<List<Tarea>>();
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: const Stream.empty(),
      funcionalidadesStream: const Stream.empty(),
      documentosStream: const Stream.empty(),
      tareasStream: tareasCtrl.stream,
      ideasStream: const Stream.empty(),
    );

    tareasCtrl.addError(Exception('fallo de red'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.error, isNotNull);

    await tareasCtrl.close();
  });

  test('dispose() cancela las cinco suscripciones', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final controller = ProyectoDetailController(
      proyectoId: 'p1',
      proyectoStream: proyectoCtrl.stream,
      funcionalidadesStream: const Stream.empty(),
      documentosStream: const Stream.empty(),
      tareasStream: const Stream.empty(),
      ideasStream: const Stream.empty(),
    );
    var notificaciones = 0;
    controller.addListener(() => notificaciones++);

    controller.dispose();
    proyectoCtrl.add(_proyecto());
    await Future<void>.delayed(Duration.zero);

    expect(notificaciones, 0);

    await proyectoCtrl.close();
  });
}
