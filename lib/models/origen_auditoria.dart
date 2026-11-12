// lib/models/origen_auditoria.dart
import 'package:flutter/material.dart';

/// De dónde viene una auditoría. `claude` existe desde ya -- preparación
/// explícita para poder marcar auditorías pegadas desde una conversación
/// con Claude (fase de IA, todavía no construida) sin tener que migrar
/// datos más adelante.
enum OrigenAuditoria {
  manual('Manual', Icons.edit_note, Color(0xFF8A93A6)),
  claude('Claude', Icons.auto_awesome, Color(0xFF9B6BF2)),
  otro('Otro', Icons.source, Color(0xFF5B6EF5));

  const OrigenAuditoria(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
