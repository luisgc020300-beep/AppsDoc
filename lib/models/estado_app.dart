// lib/models/estado_app.dart
import 'package:flutter/material.dart';

enum EstadoApp {
  enDesarrollo('En desarrollo', Icons.construction, Color(0xFF3B82F6)),
  pausado('Pausado', Icons.pause_circle, Color(0xFFF59E0B)),
  lanzado('Lanzado', Icons.rocket_launch, Color(0xFF22C55E)),
  archivado('Archivado', Icons.inventory_2, Color(0xFF6B7280));

  const EstadoApp(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
