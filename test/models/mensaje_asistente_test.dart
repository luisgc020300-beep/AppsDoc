// test/models/mensaje_asistente_test.dart
import 'package:appsdoc/models/mensaje_asistente.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final fecha = DateTime(2026, 11, 13, 10, 30);
    final original = MensajeAsistente(id: 'm1', proyectoId: 'p1', texto: '¿Qué falta?', esUsuario: true, fecha: fecha);

    final reconstruido = MensajeAsistente.fromJson('m1', 'p1', original.toJson());

    expect(reconstruido.texto, '¿Qué falta?');
    expect(reconstruido.esUsuario, true);
    expect(reconstruido.esError, false);
    expect(reconstruido.fecha, fecha);
  });

  test('esError por defecto es false', () {
    final m = MensajeAsistente(id: 'm1', proyectoId: 'p1', texto: 'x', esUsuario: false, fecha: DateTime.now());
    expect(m.esError, false);
  });

  test('fromJson() con campos ausentes cae a valores por defecto, nunca lanza', () {
    final m = MensajeAsistente.fromJson('m1', 'p1', {});
    expect(m.texto, '');
    expect(m.esUsuario, false);
    expect(m.esError, false);
  });
}
