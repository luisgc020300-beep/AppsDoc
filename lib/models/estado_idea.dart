// lib/models/estado_idea.dart
import 'package:flutter/material.dart';

enum EstadoIdea {
  nueva('Nueva', Icons.lightbulb_outline, Color(0xFF9B6BF2)),
  evaluando('Evaluando', Icons.hourglass_empty, Color(0xFFD9A441)),
  aceptada('Aceptada', Icons.check_circle, Color(0xFF1FA971)),
  descartada('Descartada', Icons.block, Color(0xFFE05B55));

  const EstadoIdea(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
