// lib/models/origen_auditoria.dart
import 'package:flutter/material.dart';

/// De dónde viene una auditoría. `claude` existe desde la Fase 4 --
/// preparación explícita para auditorías pegadas desde una conversación
/// con Claude (Fase 7). `analisisRepositorio` (Fase 9) es el análisis
/// automático de un repositorio de GitHub completo, distinto de pegar un
/// texto ya escrito: aquí la IA ha leído el código fuente real.
enum OrigenAuditoria {
  manual('Manual', Icons.edit_note, Color(0xFF8A93A6)),
  claude('Claude', Icons.auto_awesome, Color(0xFF9B6BF2)),
  analisisRepositorio('Análisis de repositorio', Icons.travel_explore, Color(0xFF14B8A6)),
  otro('Otro', Icons.source, Color(0xFF5B6EF5));

  const OrigenAuditoria(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
