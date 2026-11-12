// test/models/evento_historial_test.dart
import 'package:appsdoc/models/accion_historial.dart';
import 'package:appsdoc/models/evento_historial.dart';
import 'package:appsdoc/models/tipo_entidad_historial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos', () {
    final fecha = DateTime(2026, 11, 12, 10, 15);
    final original = EventoHistorial(
      id: 'e1',
      proyectoId: 'p1',
      entidad: TipoEntidadHistorial.tarea,
      accion: AccionHistorial.actualizado,
      descripcion: 'Tarea actualizada (estado)',
      fecha: fecha,
    );

    final reconstruido = EventoHistorial.fromJson('e1', 'p1', original.toJson());

    expect(reconstruido.entidad, TipoEntidadHistorial.tarea);
    expect(reconstruido.accion, AccionHistorial.actualizado);
    expect(reconstruido.descripcion, 'Tarea actualizada (estado)');
    expect(reconstruido.fecha, fecha);
  });

  test('fromJson() con entidad/acción desconocidas cae a los valores por defecto', () {
    final e = EventoHistorial.fromJson('e1', 'p1', {
      'entidad': 'ya_no_existe',
      'accion': 'ya_no_existe',
      'descripcion': 'X',
      'fecha': null,
    });

    expect(e.entidad, TipoEntidadHistorial.proyecto);
    expect(e.accion, AccionHistorial.actualizado);
  });
}
