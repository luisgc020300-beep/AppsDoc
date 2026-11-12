// test/controllers/proyecto_detail_controller_test.dart
import 'dart:async';

import 'package:appsdoc/controllers/proyecto_detail_controller.dart';
import 'package:appsdoc/models/auditoria.dart';
import 'package:appsdoc/models/documento.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/evento_historial.dart';
import 'package:appsdoc/models/funcionalidad.dart';
import 'package:appsdoc/models/idea.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/models/tarea.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto() {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: 'p1', nombre: 'Demo', estado: EstadoProyecto.idea, createdAt: ahora, updatedAt: ahora);
}

/// Construye un controller con los siete streams vacíos por defecto, salvo
/// los que se pasen explícitamente -- evita repetir `const Stream.empty()`
/// siete veces en cada test que solo le interesan uno o dos.
ProyectoDetailController _controller({
  Stream<Proyecto?>? proyectoStream,
  Stream<List<Funcionalidad>>? funcionalidadesStream,
  Stream<List<Documento>>? documentosStream,
  Stream<List<Tarea>>? tareasStream,
  Stream<List<Idea>>? ideasStream,
  Stream<List<Auditoria>>? auditoriasStream,
  Stream<List<EventoHistorial>>? historialStream,
}) {
  return ProyectoDetailController(
    proyectoId: 'p1',
    proyectoStream: proyectoStream ?? const Stream.empty(),
    funcionalidadesStream: funcionalidadesStream ?? const Stream.empty(),
    documentosStream: documentosStream ?? const Stream.empty(),
    tareasStream: tareasStream ?? const Stream.empty(),
    ideasStream: ideasStream ?? const Stream.empty(),
    auditoriasStream: auditoriasStream ?? const Stream.empty(),
    historialStream: historialStream ?? const Stream.empty(),
  );
}

void main() {
  test('empieza con proyectoCargando=true y las listas en null', () {
    final controller = _controller(
      proyectoStream: StreamController<Proyecto?>().stream,
      funcionalidadesStream: StreamController<List<Funcionalidad>>().stream,
      documentosStream: StreamController<List<Documento>>().stream,
      tareasStream: StreamController<List<Tarea>>().stream,
      ideasStream: StreamController<List<Idea>>().stream,
      auditoriasStream: StreamController<List<Auditoria>>().stream,
      historialStream: StreamController<List<EventoHistorial>>().stream,
    );

    expect(controller.proyectoCargando, true);
    expect(controller.proyecto, isNull);
    expect(controller.funcionalidades, isNull);
    expect(controller.documentos, isNull);
    expect(controller.tareas, isNull);
    expect(controller.ideas, isNull);
    expect(controller.auditorias, isNull);
    expect(controller.historial, isNull);
  });

  test('cada stream actualiza su propio dato de forma independiente', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final funcionalidadesCtrl = StreamController<List<Funcionalidad>>();
    final documentosCtrl = StreamController<List<Documento>>();
    final tareasCtrl = StreamController<List<Tarea>>();
    final ideasCtrl = StreamController<List<Idea>>();
    final auditoriasCtrl = StreamController<List<Auditoria>>();
    final historialCtrl = StreamController<List<EventoHistorial>>();
    final controller = _controller(
      proyectoStream: proyectoCtrl.stream,
      funcionalidadesStream: funcionalidadesCtrl.stream,
      documentosStream: documentosCtrl.stream,
      tareasStream: tareasCtrl.stream,
      ideasStream: ideasCtrl.stream,
      auditoriasStream: auditoriasCtrl.stream,
      historialStream: historialCtrl.stream,
    );

    proyectoCtrl.add(_proyecto());
    await Future<void>.delayed(Duration.zero);
    expect(controller.proyectoCargando, false);
    expect(controller.proyecto!.nombre, 'Demo');
    expect(controller.funcionalidades, isNull, reason: 'las funcionalidades todavía no han emitido nada');

    funcionalidadesCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.funcionalidades, isEmpty);

    documentosCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.documentos, isEmpty);

    tareasCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.tareas, isEmpty);

    ideasCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.ideas, isEmpty);
    expect(controller.auditorias, isNull);

    auditoriasCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.auditorias, isEmpty);
    expect(controller.historial, isNull);

    historialCtrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.historial, isEmpty);

    await proyectoCtrl.close();
    await funcionalidadesCtrl.close();
    await documentosCtrl.close();
    await tareasCtrl.close();
    await ideasCtrl.close();
    await auditoriasCtrl.close();
    await historialCtrl.close();
  });

  test('si el proyecto se elimina, el stream emite null y deja de estar "cargando"', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final controller = _controller(proyectoStream: proyectoCtrl.stream);

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
    final controller = _controller(funcionalidadesStream: funcionalidadesCtrl.stream);

    funcionalidadesCtrl.addError(Exception('fallo de red'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.error, isNotNull);

    await funcionalidadesCtrl.close();
  });

  test('un error en el stream de auditorías o historial también se expone en error', () async {
    final auditoriasCtrl = StreamController<List<Auditoria>>();
    final controller = _controller(auditoriasStream: auditoriasCtrl.stream);

    auditoriasCtrl.addError(Exception('fallo de red'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.error, isNotNull);

    await auditoriasCtrl.close();
  });

  test('dispose() cancela las siete suscripciones', () async {
    final proyectoCtrl = StreamController<Proyecto?>();
    final controller = _controller(proyectoStream: proyectoCtrl.stream);
    var notificaciones = 0;
    controller.addListener(() => notificaciones++);

    controller.dispose();
    proyectoCtrl.add(_proyecto());
    await Future<void>.delayed(Duration.zero);

    expect(notificaciones, 0);

    await proyectoCtrl.close();
  });
}
