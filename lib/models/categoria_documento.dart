// lib/models/categoria_documento.dart
import 'package:flutter/material.dart';

/// Mismo criterio que EstadoProyecto/EstadoFuncionalidad: color fijo con
/// significado, reutilizando los mismos tonos ya usados en esos estados
/// (violeta de "Idea", azul de "En desarrollo/progreso", ámbar de
/// "Pausado") en vez de inventar una paleta nueva.
enum CategoriaDocumento {
  arquitectura('Arquitectura', Icons.architecture, Color(0xFF5B6EF5)),
  decision('Decisión', Icons.gavel, Color(0xFF9B6BF2)),
  nota('Nota', Icons.sticky_note_2_outlined, Color(0xFFD9A441));

  const CategoriaDocumento(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
