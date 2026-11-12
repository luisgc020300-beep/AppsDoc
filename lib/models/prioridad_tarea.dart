// lib/models/prioridad_tarea.dart
import 'package:flutter/material.dart';

enum PrioridadTarea {
  baja('Baja', Icons.arrow_downward, Color(0xFF8A93A6)),
  media('Media', Icons.drag_handle, Color(0xFFD9A441)),
  alta('Alta', Icons.arrow_upward, Color(0xFFE05B55));

  const PrioridadTarea(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
