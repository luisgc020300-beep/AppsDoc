// lib/models/resultado_auditoria.dart
import 'package:flutter/material.dart';

enum ResultadoAuditoria {
  aprobado('Aprobado', Icons.check_circle, Color(0xFF1FA971)),
  conObservaciones('Con observaciones', Icons.warning_amber, Color(0xFFD9A441)),
  rechazado('Rechazado', Icons.cancel, Color(0xFFE05B55));

  const ResultadoAuditoria(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
