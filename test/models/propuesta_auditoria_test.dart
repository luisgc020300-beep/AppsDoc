// test/models/propuesta_auditoria_test.dart
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/propuesta_auditoria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PropuestaAuditoria.fromJson() parsea resumen, hallazgos y tareas', () {
    final propuesta = PropuestaAuditoria.fromJson({
      'resumen': 'Auditoría de seguridad pre-lanzamiento.',
      'hallazgos': [
        {'titulo': 'Falta rate limit', 'descripcion': 'En el endpoint X', 'gravedad': 'alta'},
      ],
      'tareas': [
        {'titulo': 'Añadir rate limit', 'descripcion': ''},
      ],
    });

    expect(propuesta.resumen, 'Auditoría de seguridad pre-lanzamiento.');
    expect(propuesta.hallazgos, hasLength(1));
    expect(propuesta.hallazgos.single.titulo, 'Falta rate limit');
    expect(propuesta.hallazgos.single.descripcion, 'En el endpoint X');
    expect(propuesta.hallazgos.single.gravedad, GravedadHallazgo.alta);
    expect(propuesta.tareas, hasLength(1));
    expect(propuesta.tareas.single.titulo, 'Añadir rate limit');
  });

  test('PropuestaAuditoria.fromJson() con hallazgos/tareas ausentes cae a listas vacías', () {
    final propuesta = PropuestaAuditoria.fromJson({'resumen': 'X'});

    expect(propuesta.hallazgos, isEmpty);
    expect(propuesta.tareas, isEmpty);
  });

  test('PropuestaAuditoria.fromJson() con resumen ausente cae a cadena vacía, no lanza', () {
    final propuesta = PropuestaAuditoria.fromJson({'hallazgos': [], 'tareas': []});

    expect(propuesta.resumen, isEmpty);
  });

  test('HallazgoPropuesto.fromJson() con una gravedad desconocida cae a media', () {
    final h = HallazgoPropuesto.fromJson({'titulo': 'A', 'gravedad': 'no-existe'});

    expect(h.gravedad, GravedadHallazgo.media);
  });

  test('TareaPropuesta.fromJson() con descripción ausente cae a cadena vacía', () {
    final t = TareaPropuesta.fromJson({'titulo': 'A'});

    expect(t.descripcion, isEmpty);
  });
}
