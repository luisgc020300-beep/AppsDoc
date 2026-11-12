// lib/models/estado_tarea.dart
import 'package:flutter/material.dart';

/// Mismo criterio que el resto de estados de la app: color fijo, no
/// depende del tema.
enum EstadoTarea {
  pendiente('Pendiente', Icons.radio_button_unchecked, Color(0xFF8A93A6)),
  enProgreso('En progreso', Icons.autorenew, Color(0xFF5B6EF5)),
  completada('Completada', Icons.check_circle, Color(0xFF1FA971)),
  cancelada('Cancelada', Icons.cancel, Color(0xFFE05B55));

  const EstadoTarea(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
