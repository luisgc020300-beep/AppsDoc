// lib/models/progreso_resultado.dart
import 'criterio_progreso.dart';

/// Salida de ProgresoService.calcular() -- nunca se persiste tal cual (solo
/// el porcentaje se cachea en Proyecto.progresoPorcentaje); el desglose se
/// recalcula al vuelo cada vez que hace falta mostrarlo.
class ProgresoResultado {
  const ProgresoResultado({required this.porcentaje, required this.criterios});

  final int porcentaje;
  final List<CriterioProgreso> criterios;
}
