// test/models/idea_test.dart
import 'package:appsdoc/models/estado_idea.dart';
import 'package:appsdoc/models/idea.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final ahora = DateTime(2026, 11, 12, 9);
    final original = Idea(
      id: 'i1',
      proyectoId: 'p1',
      titulo: 'Modo oscuro automático según la hora',
      descripcion: 'Cambiar solo/oscuro según amanecer/atardecer',
      notas: 'Mirar si merece la pena frente a dejarlo manual',
      estado: EstadoIdea.evaluando,
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruida = Idea.fromJson('i1', 'p1', original.toJson());

    expect(reconstruida.titulo, 'Modo oscuro automático según la hora');
    expect(reconstruida.descripcion, 'Cambiar solo/oscuro según amanecer/atardecer');
    expect(reconstruida.notas, 'Mirar si merece la pena frente a dejarlo manual');
    expect(reconstruida.estado, EstadoIdea.evaluando);
  });

  test('fromJson() con un estado desconocido cae a EstadoIdea.nueva', () {
    final i = Idea.fromJson('i1', 'p1', {
      'titulo': 'X',
      'estado': 'ya_no_existe',
      'createdAt': null,
      'updatedAt': null,
    });

    expect(i.estado, EstadoIdea.nueva);
  });

  test('copyWith() solo cambia lo indicado y conserva el resto', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Idea(id: 'i1', proyectoId: 'p1', titulo: 'A', estado: EstadoIdea.nueva, createdAt: ahora, updatedAt: ahora);

    final actualizada = original.copyWith(estado: EstadoIdea.aceptada, notas: 'convencido');

    expect(actualizada.id, 'i1');
    expect(actualizada.titulo, 'A');
    expect(actualizada.estado, EstadoIdea.aceptada);
    expect(actualizada.notas, 'convencido');
  });
}
