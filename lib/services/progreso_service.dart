// lib/services/progreso_service.dart
//
// Puro Dart, sin Firestore -- mismo criterio que RegistroService/
// PagoService de REPARA, que separan cálculo puro de I/O. Testeable con
// listas en memoria. El porcentaje mide exclusivamente preparación real
// para publicar: GitHub conectado y actividad reciente son indicadores
// independientes (fuera de esta rúbrica, nunca suman puntos aquí).
import '../models/auditoria.dart';
import '../models/criterio_progreso.dart';
import '../models/documento.dart';
import '../models/estado_funcionalidad.dart';
import '../models/estado_hallazgo.dart';
import '../models/categoria_documento.dart';
import '../models/funcionalidad.dart';
import '../models/gravedad_hallazgo.dart';
import '../models/progreso_resultado.dart';
import '../models/tarea.dart';

class ProgresoService {
  ProgresoService._();

  static ProgresoResultado calcular({
    required List<Funcionalidad> funcionalidades,
    required List<Tarea> tareas,
    required List<Documento> documentos,
    required List<Auditoria> auditorias,
  }) {
    final criterios = [
      _criterioFuncionalidades(funcionalidades),
      _criterioHallazgosCriticos(auditorias),
      _criterioTareasAlDia(tareas),
      _criterioDocumentacion(documentos),
    ];
    final porcentaje = criterios.fold<int>(0, (suma, c) => suma + c.puntosObtenidos);
    return ProgresoResultado(porcentaje: porcentaje, criterios: criterios);
  }

  /// 40 puntos repartidos en proporción a cuántas funcionalidades están
  /// completadas -- las descartadas no cuentan ni en el numerador ni en el
  /// denominador (no son trabajo pendiente, son trabajo que se decidió no
  /// hacer). Sin ninguna funcionalidad relevante, 0 puntos: no hay crédito
  /// sin funcionalidad entregada de verdad.
  static CriterioProgreso _criterioFuncionalidades(List<Funcionalidad> funcionalidades) {
    const maximo = 40;
    final relevantes = funcionalidades.where((f) => f.estado != EstadoFuncionalidad.descartada).toList();
    if (relevantes.isEmpty) {
      return const CriterioProgreso(nombre: 'Funcionalidades completadas', puntosObtenidos: 0, puntosMaximos: maximo);
    }
    final completadas = relevantes.where((f) => f.estado == EstadoFuncionalidad.completada).length;
    final puntos = (completadas / relevantes.length * maximo).round();
    return CriterioProgreso(nombre: 'Funcionalidades completadas', puntosObtenidos: puntos, puntosMaximos: maximo);
  }

  /// 30 puntos, todo o nada: se pierden si CUALQUIER hallazgo de
  /// cualquier auditoría (no solo la última) sigue abierto o en progreso
  /// con gravedad alta o crítica. Un hallazgo resuelto o descartado no
  /// cuenta, sea cual sea su gravedad. Sin auditorías ni hallazgos, no hay
  /// ningún hallazgo crítico abierto -- 30 puntos (vacuously true, no es
  /// lo mismo que "ya se auditó y salió limpio", pero objetivamente no hay
  /// ninguno abierto).
  static CriterioProgreso _criterioHallazgosCriticos(List<Auditoria> auditorias) {
    const maximo = 30;
    final hayCriticoAbierto = auditorias.any(
      (a) => a.hallazgos.any(
        (h) =>
            (h.gravedad == GravedadHallazgo.alta || h.gravedad == GravedadHallazgo.critica) &&
            (h.estado == EstadoHallazgo.abierto || h.estado == EstadoHallazgo.enProgreso),
      ),
    );
    return CriterioProgreso(
      nombre: 'Sin hallazgos críticos abiertos',
      puntosObtenidos: hayCriticoAbierto ? 0 : maximo,
      puntosMaximos: maximo,
    );
  }

  /// 15 puntos, todo o nada: se pierden si cualquier tarea está vencida
  /// (Tarea.vencida ya descarta las completadas/canceladas). Sin tareas,
  /// 15 puntos -- no hay ninguna vencida porque no hay ninguna.
  static CriterioProgreso _criterioTareasAlDia(List<Tarea> tareas) {
    const maximo = 15;
    final hayVencidas = tareas.any((t) => t.vencida);
    return CriterioProgreso(nombre: 'Tareas al día', puntosObtenidos: hayVencidas ? 0 : maximo, puntosMaximos: maximo);
  }

  /// 15 puntos si existe al menos un documento de categoría Arquitectura
  /// -- la documentación mínima que cualquier proyecto publicable debería
  /// tener para que otro (o el propio IA más adelante) pueda entenderlo.
  static CriterioProgreso _criterioDocumentacion(List<Documento> documentos) {
    const maximo = 15;
    final hayDocumentacionBase = documentos.any((d) => d.categoria == CategoriaDocumento.arquitectura);
    return CriterioProgreso(
      nombre: 'Documentación base',
      puntosObtenidos: hayDocumentacionBase ? maximo : 0,
      puntosMaximos: maximo,
    );
  }
}
