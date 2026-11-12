// test/services/progreso_service_test.dart
import 'package:appsdoc/models/auditoria.dart';
import 'package:appsdoc/models/categoria_documento.dart';
import 'package:appsdoc/models/documento.dart';
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/models/estado_hallazgo.dart';
import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/models/funcionalidad.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/hallazgo.dart';
import 'package:appsdoc/models/tarea.dart';
import 'package:appsdoc/services/progreso_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _ahora = DateTime(2026, 11, 12);

Funcionalidad _funcionalidad(EstadoFuncionalidad estado) =>
    Funcionalidad(id: 'f', proyectoId: 'p1', nombre: 'X', estado: estado, createdAt: _ahora, updatedAt: _ahora);

Tarea _tarea({DateTime? fechaLimite, EstadoTarea estado = EstadoTarea.pendiente}) =>
    Tarea(id: 't', proyectoId: 'p1', titulo: 'X', estado: estado, fechaLimite: fechaLimite, createdAt: _ahora, updatedAt: _ahora);

Documento _documento(CategoriaDocumento categoria) =>
    Documento(id: 'd', proyectoId: 'p1', titulo: 'X', categoria: categoria, createdAt: _ahora, updatedAt: _ahora);

Auditoria _auditoria(List<Hallazgo> hallazgos) =>
    Auditoria(id: 'a', proyectoId: 'p1', fecha: _ahora, resumen: 'X', hallazgos: hallazgos, createdAt: _ahora, updatedAt: _ahora);

void main() {
  group('con todas las listas vacías', () {
    test('45%: 0 (funcionalidades) + 30 (sin hallazgos) + 15 (sin tareas vencidas) + 0 (sin documentación)', () {
      final resultado = ProgresoService.calcular(funcionalidades: [], tareas: [], documentos: [], auditorias: []);

      expect(resultado.porcentaje, 45);
      expect(resultado.criterios, hasLength(4));
    });
  });

  group('criterio: Funcionalidades completadas (40 puntos)', () {
    test('todas completadas da los 40 puntos completos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [_funcionalidad(EstadoFuncionalidad.completada), _funcionalidad(EstadoFuncionalidad.completada)],
        tareas: [],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Funcionalidades completadas');
      expect(criterio.puntosObtenidos, 40);
      expect(criterio.puntosMaximos, 40);
      expect(criterio.cumplido, true);
    });

    test('ninguna completada da 0 puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [_funcionalidad(EstadoFuncionalidad.planificada), _funcionalidad(EstadoFuncionalidad.enProgreso)],
        tareas: [],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Funcionalidades completadas');
      expect(criterio.puntosObtenidos, 0);
    });

    test('la mitad completadas da la mitad de los puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [_funcionalidad(EstadoFuncionalidad.completada), _funcionalidad(EstadoFuncionalidad.enProgreso)],
        tareas: [],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Funcionalidades completadas');
      expect(criterio.puntosObtenidos, 20);
    });

    test('las descartadas no cuentan ni en el numerador ni en el denominador', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [
          _funcionalidad(EstadoFuncionalidad.completada),
          _funcionalidad(EstadoFuncionalidad.descartada),
          _funcionalidad(EstadoFuncionalidad.descartada),
        ],
        tareas: [],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Funcionalidades completadas');
      expect(criterio.puntosObtenidos, 40, reason: '1/1 relevante completada, las 2 descartadas se excluyen');
    });

    test('solo descartadas (ninguna relevante) da 0 puntos, no un error de división por cero', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [_funcionalidad(EstadoFuncionalidad.descartada)],
        tareas: [],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Funcionalidades completadas');
      expect(criterio.puntosObtenidos, 0);
    });
  });

  group('criterio: Sin hallazgos críticos abiertos (30 puntos, todo o nada)', () {
    test('un hallazgo crítico abierto hace perder los 30 puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.critica, estado: EstadoHallazgo.abierto)]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 0);
    });

    test('un hallazgo de gravedad alta en progreso también hace perder los puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.alta, estado: EstadoHallazgo.enProgreso)]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 0);
    });

    test('un hallazgo crítico ya resuelto no quita puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.critica, estado: EstadoHallazgo.resuelto)]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 30);
    });

    test('un hallazgo crítico descartado tampoco quita puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.critica, estado: EstadoHallazgo.descartado)]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 30);
    });

    test('hallazgos abiertos de gravedad baja o media no quitan puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([
            Hallazgo(id: 'h1', titulo: 'X', gravedad: GravedadHallazgo.baja, estado: EstadoHallazgo.abierto),
            Hallazgo(id: 'h2', titulo: 'Y', gravedad: GravedadHallazgo.media, estado: EstadoHallazgo.abierto),
          ]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 30);
    });

    test('revisa TODAS las auditorías, no solo la primera de la lista', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [],
        auditorias: [
          _auditoria([]),
          _auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.critica, estado: EstadoHallazgo.abierto)]),
        ],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Sin hallazgos críticos abiertos');
      expect(criterio.puntosObtenidos, 0);
    });
  });

  group('criterio: Tareas al día (15 puntos, todo o nada)', () {
    test('una tarea vencida (sin completar) hace perder los 15 puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [_tarea(fechaLimite: DateTime(2020, 1, 1))],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Tareas al día');
      expect(criterio.puntosObtenidos, 0);
    });

    test('una tarea con fecha pasada pero ya completada no quita puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [_tarea(fechaLimite: DateTime(2020, 1, 1), estado: EstadoTarea.completada)],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Tareas al día');
      expect(criterio.puntosObtenidos, 15);
    });

    test('una tarea con fecha futura no quita puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [_tarea(fechaLimite: DateTime(2099, 1, 1))],
        documentos: [],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Tareas al día');
      expect(criterio.puntosObtenidos, 15);
    });

    test('una tarea sin fecha límite no cuenta como vencida', () {
      final resultado = ProgresoService.calcular(funcionalidades: [], tareas: [_tarea()], documentos: [], auditorias: []);

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Tareas al día');
      expect(criterio.puntosObtenidos, 15);
    });
  });

  group('criterio: Documentación base (15 puntos)', () {
    test('un documento de categoría Arquitectura da los 15 puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [_documento(CategoriaDocumento.arquitectura)],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Documentación base');
      expect(criterio.puntosObtenidos, 15);
    });

    test('solo documentos de otras categorías no da puntos', () {
      final resultado = ProgresoService.calcular(
        funcionalidades: [],
        tareas: [],
        documentos: [_documento(CategoriaDocumento.nota), _documento(CategoriaDocumento.decision)],
        auditorias: [],
      );

      final criterio = resultado.criterios.firstWhere((c) => c.nombre == 'Documentación base');
      expect(criterio.puntosObtenidos, 0);
    });
  });

  test('un proyecto que cumple los cuatro criterios llega a 100%, nunca más', () {
    final resultado = ProgresoService.calcular(
      funcionalidades: [_funcionalidad(EstadoFuncionalidad.completada)],
      tareas: [_tarea(fechaLimite: DateTime(2099, 1, 1))],
      documentos: [_documento(CategoriaDocumento.arquitectura)],
      auditorias: [_auditoria([Hallazgo(id: 'h', titulo: 'X', gravedad: GravedadHallazgo.alta, estado: EstadoHallazgo.resuelto)])],
    );

    expect(resultado.porcentaje, 100);
  });
}
