// test/models/auditoria_test.dart
import 'package:appsdoc/models/auditoria.dart';
import 'package:appsdoc/models/estado_hallazgo.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/hallazgo.dart';
import 'package:appsdoc/models/origen_auditoria.dart';
import 'package:appsdoc/models/resultado_auditoria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder datos, incluidos los hallazgos', () {
    final ahora = DateTime(2026, 11, 12, 9);
    final fecha = DateTime(2026, 11, 10);
    final original = Auditoria(
      id: 'a1',
      proyectoId: 'p1',
      fecha: fecha,
      origen: OrigenAuditoria.claude,
      resumen: 'Auditoría de seguridad pegada desde una conversación con Claude.',
      resultado: ResultadoAuditoria.conObservaciones,
      hallazgos: [
        Hallazgo(id: 'h1', titulo: 'Falta validación', gravedad: GravedadHallazgo.alta),
        Hallazgo(id: 'h2', titulo: 'Nombre poco claro', gravedad: GravedadHallazgo.baja, estado: EstadoHallazgo.resuelto),
      ],
      createdAt: ahora,
      updatedAt: ahora,
    );

    final reconstruida = Auditoria.fromJson('a1', 'p1', original.toJson());

    expect(reconstruida.fecha, fecha);
    expect(reconstruida.origen, OrigenAuditoria.claude);
    expect(reconstruida.resumen, 'Auditoría de seguridad pegada desde una conversación con Claude.');
    expect(reconstruida.resultado, ResultadoAuditoria.conObservaciones);
    expect(reconstruida.hallazgos, hasLength(2));
    expect(reconstruida.hallazgos[0].id, 'h1');
    expect(reconstruida.hallazgos[0].titulo, 'Falta validación');
    expect(reconstruida.hallazgos[0].gravedad, GravedadHallazgo.alta);
    expect(reconstruida.hallazgos[0].estado, EstadoHallazgo.abierto);
    expect(reconstruida.hallazgos[1].estado, EstadoHallazgo.resuelto);
  });

  test('toJson()/fromJson() sin hallazgos los mantiene como lista vacía', () {
    final ahora = DateTime(2026, 11, 12);
    final original = Auditoria(id: 'a1', proyectoId: 'p1', fecha: ahora, resumen: 'X', createdAt: ahora, updatedAt: ahora);

    final reconstruida = Auditoria.fromJson('a1', 'p1', original.toJson());

    expect(reconstruida.hallazgos, isEmpty);
  });

  test('fromJson() con origen/resultado desconocidos cae a los valores por defecto', () {
    final a = Auditoria.fromJson('a1', 'p1', {
      'fecha': null,
      'origen': 'ya_no_existe',
      'resumen': 'X',
      'resultado': 'ya_no_existe',
      'hallazgos': [],
      'createdAt': null,
      'updatedAt': null,
    });

    expect(a.origen, OrigenAuditoria.manual);
    expect(a.resultado, ResultadoAuditoria.conObservaciones);
  });

  group('hallazgosAbiertos', () {
    test('cuenta los hallazgos en estado abierto o en progreso', () {
      final ahora = DateTime(2026, 11, 12);
      final a = Auditoria(
        id: 'a1',
        proyectoId: 'p1',
        fecha: ahora,
        resumen: 'X',
        hallazgos: [
          Hallazgo(id: 'h1', titulo: 'A', estado: EstadoHallazgo.abierto),
          Hallazgo(id: 'h2', titulo: 'B', estado: EstadoHallazgo.enProgreso),
          Hallazgo(id: 'h3', titulo: 'C', estado: EstadoHallazgo.resuelto),
          Hallazgo(id: 'h4', titulo: 'D', estado: EstadoHallazgo.descartado),
        ],
        createdAt: ahora,
        updatedAt: ahora,
      );

      expect(a.hallazgosAbiertos, 2);
    });

    test('es 0 sin hallazgos', () {
      final ahora = DateTime(2026, 11, 12);
      final a = Auditoria(id: 'a1', proyectoId: 'p1', fecha: ahora, resumen: 'X', createdAt: ahora, updatedAt: ahora);

      expect(a.hallazgosAbiertos, 0);
    });
  });
}
