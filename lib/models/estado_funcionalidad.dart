// lib/models/estado_funcionalidad.dart
import 'package:flutter/material.dart';

/// Ciclo de vida de una funcionalidad dentro de un proyecto. Mismos colores
/// semánticos que EstadoProyecto (fijos, no dependen del tema) para que el
/// significado de cada color sea el mismo en toda la app.
enum EstadoFuncionalidad {
  planificada('Planificada', Icons.schedule, Color(0xFF8A93A6)),
  enProgreso('En progreso', Icons.autorenew, Color(0xFF5B6EF5)),
  completada('Completada', Icons.check_circle, Color(0xFF1FA971)),
  descartada('Descartada', Icons.block, Color(0xFFE05B55));

  const EstadoFuncionalidad(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
