// test/models/documento_test.dart
import 'package:appsdoc/models/categoria_documento.dart';
import 'package:appsdoc/models/documento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final ahora = DateTime(2026, 11, 12, 9);
    final original = Documento(
      id: 'd1',
      proyectoId: 'p1',
      titulo: 'Decisión: Firestore sobre REST propio',
      categoria: CategoriaDocumento.decision,
      contenido: 'Firestore da tiempo real gratis y encaja con el resto del ecosistema.',
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruido = Documento.fromJson('d1', 'p1', original.toJson());

    expect(reconstruido.id, 'd1');
    expect(reconstruido.proyectoId, 'p1');
    expect(reconstruido.titulo, 'Decisión: Firestore sobre REST propio');
    expect(reconstruido.categoria, CategoriaDocumento.decision);
    expect(reconstruido.contenido, 'Firestore da tiempo real gratis y encaja con el resto del ecosistema.');
    expect(reconstruido.updatedAt, ahora);
  });

  test('fromJson() con una categoría desconocida cae a CategoriaDocumento.nota', () {
    final d = Documento.fromJson('d1', 'p1', {
      'titulo': 'X',
      'categoria': 'ya_no_existe',
      'createdAt': null,
      'updatedAt': null,
    });

    expect(d.categoria, CategoriaDocumento.nota);
  });

  test('copyWith() solo cambia lo indicado y conserva el resto', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Documento(id: 'd1', proyectoId: 'p1', titulo: 'A', createdAt: ahora, updatedAt: ahora);

    final actualizado = original.copyWith(categoria: CategoriaDocumento.arquitectura, contenido: 'nuevo contenido');

    expect(actualizado.id, 'd1');
    expect(actualizado.proyectoId, 'p1');
    expect(actualizado.titulo, 'A');
    expect(actualizado.categoria, CategoriaDocumento.arquitectura);
    expect(actualizado.contenido, 'nuevo contenido');
  });
}
