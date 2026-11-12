// test/models/hallazgo_test.dart
import 'package:appsdoc/models/estado_hallazgo.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/hallazgo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final original = Hallazgo(
      id: 'h1',
      titulo: 'Falta rate limiting',
      descripcion: 'El endpoint no limita peticiones por IP',
      gravedad: GravedadHallazgo.critica,
      estado: EstadoHallazgo.enProgreso,
    );

    final reconstruido = Hallazgo.fromJson(original.toJson());

    expect(reconstruido.id, 'h1');
    expect(reconstruido.titulo, 'Falta rate limiting');
    expect(reconstruido.descripcion, 'El endpoint no limita peticiones por IP');
    expect(reconstruido.gravedad, GravedadHallazgo.critica);
    expect(reconstruido.estado, EstadoHallazgo.enProgreso);
  });

  test('copyWith(estado: ...) cambia solo el estado y conserva el resto', () {
    final original = Hallazgo(id: 'h1', titulo: 'X', gravedad: GravedadHallazgo.alta);

    final actualizado = original.copyWith(estado: EstadoHallazgo.resuelto);

    expect(actualizado.id, 'h1');
    expect(actualizado.titulo, 'X');
    expect(actualizado.gravedad, GravedadHallazgo.alta);
    expect(actualizado.estado, EstadoHallazgo.resuelto);
  });
}
