// lib/models/confianza_expediente.dart
import 'package:flutter/material.dart';

/// Nivel de certeza del catálogo de funcionalidades del Expediente (Fase 10)
/// -- documental, nunca se mezcla con EstadoFuncionalidad ni con la colección
/// `funcionalidades` real (esa sí mueve ProgresoService). Encontrar código
/// relacionado nunca basta por sí solo para "verificada".
enum ConfianzaExpediente {
  detectada('Detectada', Icons.visibility_outlined, Color(0xFF8A93A6)),
  aparentementeImplementada('Aparentemente implementada', Icons.hourglass_top, Color(0xFFD9A441)),
  verificada('Verificada', Icons.verified, Color(0xFF1FA971)),
  pendiente('Pendiente', Icons.help_outline, Color(0xFF8A93A6));

  const ConfianzaExpediente(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
