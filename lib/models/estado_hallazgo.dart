// lib/models/estado_hallazgo.dart
import 'package:flutter/material.dart';

enum EstadoHallazgo {
  abierto('Abierto', Icons.radio_button_unchecked, Color(0xFFE05B55)),
  enProgreso('En progreso', Icons.autorenew, Color(0xFF5B6EF5)),
  resuelto('Resuelto', Icons.check_circle, Color(0xFF1FA971)),
  descartado('Descartado', Icons.block, Color(0xFF8A93A6));

  const EstadoHallazgo(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
