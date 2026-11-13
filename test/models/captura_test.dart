// test/models/captura_test.dart
import 'package:appsdoc/models/captura.dart';
import 'package:appsdoc/models/origen_captura.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final subidaEn = DateTime(2026, 11, 13, 9);
    final original = Captura(
      id: 'c1',
      proyectoId: 'p1',
      pantallaClave: 'clave-1',
      storagePath: 'capturas/uid/p1/clave-1/c1.jpg',
      orden: 2,
      origen: OrigenCaptura.manual,
      subidaEn: subidaEn,
      hashContenido: 'hash123',
      tamanioBytes: 204800,
      descripcion: 'Pantalla de login en modo oscuro',
    );

    final reconstruida = Captura.fromJson('c1', 'p1', original.toJson());

    expect(reconstruida.pantallaClave, 'clave-1');
    expect(reconstruida.storagePath, 'capturas/uid/p1/clave-1/c1.jpg');
    expect(reconstruida.orden, 2);
    expect(reconstruida.origen, OrigenCaptura.manual);
    expect(reconstruida.subidaEn, subidaEn);
    expect(reconstruida.hashContenido, 'hash123');
    expect(reconstruida.tamanioBytes, 204800);
    expect(reconstruida.descripcion, 'Pantalla de login en modo oscuro');
  });

  test('fromJson() con origen desconocido cae a "manual"', () {
    final c = Captura.fromJson('c1', 'p1', {
      'pantallaClave': 'clave-1',
      'storagePath': 'x',
      'origen': 'ya_no_existe',
      'subidaEn': null,
    });

    expect(c.origen, OrigenCaptura.manual);
  });

  test('fromJson() con campos numéricos/texto ausentes cae a sus valores por defecto', () {
    final c = Captura.fromJson('c1', 'p1', {'pantallaClave': 'clave-1', 'storagePath': 'x'});

    expect(c.orden, 0);
    expect(c.tamanioBytes, 0);
    expect(c.hashContenido, '');
    expect(c.descripcion, '');
  });
}
