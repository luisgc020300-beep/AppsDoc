// lib/models/estado_proyecto.dart
import 'package:flutter/material.dart';

/// Ciclo de vida de un proyecto dentro de AppsDoc. El color es fijo
/// (semántico), no depende del tema claro/oscuro -- igual criterio que el
/// resto de chips de estado en RiskRunner/Convive/REPARA.
enum EstadoProyecto {
  idea('Idea', Icons.lightbulb_outline, Color(0xFF9B6BF2)),
  enDesarrollo('En desarrollo', Icons.construction, Color(0xFF5B6EF5)),
  pausado('Pausado', Icons.pause_circle, Color(0xFFD9A441)),
  lanzado('Lanzado', Icons.rocket_launch, Color(0xFF1FA971)),
  archivado('Archivado', Icons.inventory_2, Color(0xFF8A93A6));

  const EstadoProyecto(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
