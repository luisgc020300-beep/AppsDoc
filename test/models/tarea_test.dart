// test/models/tarea_test.dart
import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/models/prioridad_tarea.dart';
import 'package:appsdoc/models/tarea.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos (con fecha límite)', () {
    final ahora = DateTime(2026, 11, 12, 9);
    final limite = DateTime(2026, 12, 1);
    final original = Tarea(
      id: 't1',
      proyectoId: 'p1',
      titulo: 'Escribir reglas de Firestore',
      descripcion: 'Antes del deploy',
      estado: EstadoTarea.enProgreso,
      prioridad: PrioridadTarea.alta,
      fechaLimite: limite,
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruida = Tarea.fromJson('t1', 'p1', original.toJson());

    expect(reconstruida.titulo, 'Escribir reglas de Firestore');
    expect(reconstruida.descripcion, 'Antes del deploy');
    expect(reconstruida.estado, EstadoTarea.enProgreso);
    expect(reconstruida.prioridad, PrioridadTarea.alta);
    expect(reconstruida.fechaLimite, limite);
  });

  test('toJson()/fromJson() sin fecha límite la mantienen null', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Tarea(id: 't1', proyectoId: 'p1', titulo: 'X', createdAt: ahora, updatedAt: ahora);

    final reconstruida = Tarea.fromJson('t1', 'p1', original.toJson());

    expect(reconstruida.fechaLimite, isNull);
  });

  test('fromJson() con estado/prioridad desconocidos cae a los valores por defecto', () {
    final t = Tarea.fromJson('t1', 'p1', {
      'titulo': 'X',
      'estado': 'ya_no_existe',
      'prioridad': 'ya_no_existe',
      'createdAt': null,
      'updatedAt': null,
    });

    expect(t.estado, EstadoTarea.pendiente);
    expect(t.prioridad, PrioridadTarea.media);
  });

  group('vencida', () {
    test('es true con fecha límite pasada y estado pendiente', () {
      final ahora = DateTime(2026, 11, 12);
      final t = Tarea(
        id: 't1',
        proyectoId: 'p1',
        titulo: 'X',
        fechaLimite: DateTime(2020, 1, 1),
        createdAt: ahora,
        updatedAt: ahora,
      );
      expect(t.vencida, true);
    });

    test('es false sin fecha límite', () {
      final ahora = DateTime(2026, 11, 12);
      final t = Tarea(id: 't1', proyectoId: 'p1', titulo: 'X', createdAt: ahora, updatedAt: ahora);
      expect(t.vencida, false);
    });

    test('es false con fecha límite pasada pero ya completada', () {
      final ahora = DateTime(2026, 11, 12);
      final t = Tarea(
        id: 't1',
        proyectoId: 'p1',
        titulo: 'X',
        estado: EstadoTarea.completada,
        fechaLimite: DateTime(2020, 1, 1),
        createdAt: ahora,
        updatedAt: ahora,
      );
      expect(t.vencida, false);
    });

    test('es false con fecha límite pasada pero cancelada', () {
      final ahora = DateTime(2026, 11, 12);
      final t = Tarea(
        id: 't1',
        proyectoId: 'p1',
        titulo: 'X',
        estado: EstadoTarea.cancelada,
        fechaLimite: DateTime(2020, 1, 1),
        createdAt: ahora,
        updatedAt: ahora,
      );
      expect(t.vencida, false);
    });

    test('es false con fecha límite futura', () {
      final ahora = DateTime(2026, 11, 12);
      final t = Tarea(
        id: 't1',
        proyectoId: 'p1',
        titulo: 'X',
        fechaLimite: DateTime(2099, 1, 1),
        createdAt: ahora,
        updatedAt: ahora,
      );
      expect(t.vencida, false);
    });
  });

  test('copyWith(quitarFechaLimite: true) borra la fecha aunque no se pase ninguna nueva', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Tarea(id: 't1', proyectoId: 'p1', titulo: 'X', fechaLimite: ahora, createdAt: ahora, updatedAt: ahora);

    final actualizada = original.copyWith(quitarFechaLimite: true);

    expect(actualizada.fechaLimite, isNull);
  });

  test('copyWith() sin tocar la fecha límite la conserva', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Tarea(id: 't1', proyectoId: 'p1', titulo: 'X', fechaLimite: ahora, createdAt: ahora, updatedAt: ahora);

    final actualizada = original.copyWith(estado: EstadoTarea.completada);

    expect(actualizada.fechaLimite, ahora);
    expect(actualizada.estado, EstadoTarea.completada);
  });
}
