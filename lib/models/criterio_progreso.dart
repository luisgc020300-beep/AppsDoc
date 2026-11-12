// lib/models/criterio_progreso.dart
//
// Una fila ya evaluada del resultado de ProgresoService.calcular() -- no
// es una regla configurable ni se guarda en Firestore, es la salida de la
// función pura para poder mostrar el desglose ("qué te falta").
class CriterioProgreso {
  const CriterioProgreso({required this.nombre, required this.puntosObtenidos, required this.puntosMaximos});

  final String nombre;
  final int puntosObtenidos;
  final int puntosMaximos;

  bool get cumplido => puntosObtenidos >= puntosMaximos;
}
