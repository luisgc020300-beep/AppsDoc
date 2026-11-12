// test/models/funcionalidad_test.dart
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/models/funcionalidad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final ahora = DateTime(2026, 11, 12, 9);
    final original = Funcionalidad(
      id: 'f1',
      proyectoId: 'p1',
      nombre: 'Login con Google',
      descripcion: 'Añadir botón de acceso con Google',
      estado: EstadoFuncionalidad.enProgreso,
      notas: 'Pendiente de probar en iOS',
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruido = Funcionalidad.fromJson('f1', 'p1', original.toJson());

    expect(reconstruido.id, 'f1');
    expect(reconstruido.proyectoId, 'p1');
    expect(reconstruido.nombre, 'Login con Google');
    expect(reconstruido.descripcion, 'Añadir botón de acceso con Google');
    expect(reconstruido.estado, EstadoFuncionalidad.enProgreso);
    expect(reconstruido.notas, 'Pendiente de probar en iOS');
    expect(reconstruido.updatedAt, ahora);
  });

  test('fromJson() con un estado desconocido cae a EstadoFuncionalidad.planificada', () {
    final f = Funcionalidad.fromJson('f1', 'p1', {
      'nombre': 'X',
      'estado': 'ya_no_existe',
      'createdAt': null,
      'updatedAt': null,
    });

    expect(f.estado, EstadoFuncionalidad.planificada);
  });

  test('copyWith() solo cambia lo indicado y conserva el resto', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Funcionalidad(id: 'f1', proyectoId: 'p1', nombre: 'A', estado: EstadoFuncionalidad.planificada, createdAt: ahora, updatedAt: ahora);

    final actualizado = original.copyWith(estado: EstadoFuncionalidad.completada, notas: 'listo');

    expect(actualizado.id, 'f1');
    expect(actualizado.proyectoId, 'p1');
    expect(actualizado.nombre, 'A');
    expect(actualizado.estado, EstadoFuncionalidad.completada);
    expect(actualizado.notas, 'listo');
  });
}
