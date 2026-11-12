// lib/models/gravedad_hallazgo.dart
import 'package:flutter/material.dart';

enum GravedadHallazgo {
  baja('Baja', Icons.arrow_downward, Color(0xFF8A93A6)),
  media('Media', Icons.drag_handle, Color(0xFFD9A441)),
  alta('Alta', Icons.arrow_upward, Color(0xFFE07A3E)),
  critica('Crítica', Icons.priority_high, Color(0xFFE05B55));

  const GravedadHallazgo(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
