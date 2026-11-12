// test/models/proyecto_test.dart
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final ahora = DateTime(2026, 11, 12, 10, 30);
    final original = Proyecto(
      id: 'p1',
      nombre: 'RiskRunner',
      descripcion: 'Conquista territorial de running',
      estado: EstadoProyecto.enDesarrollo,
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruido = Proyecto.fromJson('p1', original.toJson());

    expect(reconstruido.id, 'p1');
    expect(reconstruido.nombre, 'RiskRunner');
    expect(reconstruido.descripcion, 'Conquista territorial de running');
    expect(reconstruido.estado, EstadoProyecto.enDesarrollo);
    expect(reconstruido.createdAt, ahora);
    expect(reconstruido.updatedAt, ahora);
  });

  test('fromJson() con un estado desconocido cae a EstadoProyecto.idea', () {
    final proyecto = Proyecto.fromJson('p1', {
      'nombre': 'X',
      'descripcion': '',
      'estado': 'algo_que_ya_no_existe',
      'createdAt': null,
      'updatedAt': null,
    });

    expect(proyecto.estado, EstadoProyecto.idea);
  });

  test('copyWith() solo cambia lo indicado y conserva el resto', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Proyecto(id: 'p1', nombre: 'A', descripcion: 'd', estado: EstadoProyecto.idea, createdAt: ahora, updatedAt: ahora);

    final actualizado = original.copyWith(estado: EstadoProyecto.lanzado);

    expect(actualizado.id, 'p1');
    expect(actualizado.nombre, 'A');
    expect(actualizado.descripcion, 'd');
    expect(actualizado.estado, EstadoProyecto.lanzado);
    expect(actualizado.createdAt, ahora);
  });
}
