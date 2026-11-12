// test/controllers/proyectos_list_controller_test.dart
import 'dart:async';

import 'package:appsdoc/controllers/proyectos_list_controller.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto(String id) {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: id, nombre: id, estado: EstadoProyecto.idea, createdAt: ahora, updatedAt: ahora);
}

void main() {
  test('empieza cargando hasta que el stream emite su primer valor', () async {
    final controller = ProyectosListController(proyectosStream: StreamController<List<Proyecto>>().stream);
    expect(controller.cargando, true);
    expect(controller.proyectos, isNull);
    expect(controller.error, isNull);
  });

  test('al emitir una lista (incluida vacía), deja de cargar y la expone', () async {
    final streamController = StreamController<List<Proyecto>>();
    final controller = ProyectosListController(proyectosStream: streamController.stream);

    streamController.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(controller.cargando, false);
    expect(controller.proyectos, isEmpty);
    expect(controller.error, isNull);

    await streamController.close();
  });

  test('con datos reales, expone la lista tal cual la emitió el stream', () async {
    final streamController = StreamController<List<Proyecto>>();
    final controller = ProyectosListController(proyectosStream: streamController.stream);

    streamController.add([_proyecto('a'), _proyecto('b')]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.proyectos!.map((p) => p.id), ['a', 'b']);

    await streamController.close();
  });

  test('si el stream emite un error, lo expone y dispara notifyListeners()', () async {
    final streamController = StreamController<List<Proyecto>>();
    final controller = ProyectosListController(proyectosStream: streamController.stream);
    var notificaciones = 0;
    controller.addListener(() => notificaciones++);

    streamController.addError(Exception('fallo de red'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.cargando, false);
    expect(controller.error, isNotNull);
    expect(controller.proyectos, isNull);
    expect(notificaciones, greaterThan(0));

    await streamController.close();
  });

  test('dispose() cancela la suscripción -- nuevos eventos ya no notifican', () async {
    final streamController = StreamController<List<Proyecto>>();
    final controller = ProyectosListController(proyectosStream: streamController.stream);
    var notificaciones = 0;
    controller.addListener(() => notificaciones++);

    controller.dispose();
    streamController.add([_proyecto('a')]);
    await Future<void>.delayed(Duration.zero);

    expect(notificaciones, 0);

    await streamController.close();
  });
}
