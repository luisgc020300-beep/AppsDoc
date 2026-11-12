// test/controllers/actividad_controller_test.dart
import 'dart:async';

import 'package:appsdoc/controllers/actividad_controller.dart';
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/evento_historial.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/models/tipo_entidad_historial.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto(String id, String nombre) {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: id, nombre: nombre, estado: EstadoProyecto.enDesarrollo, createdAt: ahora, updatedAt: ahora);
}

EventoHistorial _evento(String id, String proyectoId, DateTime fecha, String descripcion) => EventoHistorial(
  id: id,
  proyectoId: proyectoId,
  entidad: TipoEntidadHistorial.proyecto,
  accion: AccionHistorial.creado,
  descripcion: descripcion,
  fecha: fecha,
);

void main() {
  test('mientras los proyectos no han emitido nada, eventos es null (cargando)', () {
    final controller = ActividadController(
      proyectosStream: StreamController<List<Proyecto>>().stream,
      historialStreamFactory: (_) => const Stream.empty(),
    );
    addTearDown(controller.dispose);

    expect(controller.cargando, true);
    expect(controller.eventos, isNull);
  });

  test('sin proyectos, eventos es una lista vacía, no null', () async {
    final controller = ActividadController(
      proyectosStream: Stream.value(const []),
      historialStreamFactory: (_) => const Stream.empty(),
    );
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(controller.cargando, false);
    expect(controller.eventos, isEmpty);
  });

  test('combina y ordena por fecha descendente los eventos de varios proyectos', () async {
    final historiales = {
      'p1': [_evento('e1', 'p1', DateTime(2026, 11, 1), 'Proyecto p1 creado')],
      'p2': [
        _evento('e2', 'p2', DateTime(2026, 11, 10), 'Proyecto p2 creado'),
        _evento('e3', 'p2', DateTime(2026, 11, 5), 'Funcionalidad de p2 creada'),
      ],
    };

    final controller = ActividadController(
      proyectosStream: Stream.value([_proyecto('p1', 'Uno'), _proyecto('p2', 'Dos')]),
      historialStreamFactory: (id) => Stream.value(historiales[id]!),
    );
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);

    final eventos = controller.eventos!;
    expect(eventos, hasLength(3));
    expect(eventos.map((e) => e.evento.id), ['e2', 'e3', 'e1']);
    expect(eventos.first.proyectoNombre, 'Dos');
  });

  test('un error en el stream de proyectos se refleja en error, no lanza', () async {
    final controller = ActividadController(
      proyectosStream: Stream.error(StateError('sin conexión')),
      historialStreamFactory: (_) => const Stream.empty(),
    );
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(controller.error, isNotNull);
    expect(controller.cargando, false);
  });

  test('si un proyecto desaparece de la lista, sus eventos dejan de contarse', () async {
    final proyectosController = StreamController<List<Proyecto>>();
    final historiales = {
      'p1': [_evento('e1', 'p1', DateTime(2026, 11, 1), 'p1')],
      'p2': [_evento('e2', 'p2', DateTime(2026, 11, 2), 'p2')],
    };

    final controller = ActividadController(
      proyectosStream: proyectosController.stream,
      historialStreamFactory: (id) => Stream.value(historiales[id]!),
    );
    addTearDown(controller.dispose);
    addTearDown(proyectosController.close);

    proyectosController.add([_proyecto('p1', 'Uno'), _proyecto('p2', 'Dos')]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.eventos, hasLength(2));

    proyectosController.add([_proyecto('p1', 'Uno')]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.eventos!.map((e) => e.evento.id), ['e1']);
  });
}
