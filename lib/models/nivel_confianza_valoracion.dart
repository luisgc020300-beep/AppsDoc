// lib/models/nivel_confianza_valoracion.dart
import 'package:flutter/material.dart';

/// Cuánto confía la IA en sus propias estimaciones de valoración económica o
/// potencial de usuarios (Fase 10) -- nunca una medida de precisión real,
/// solo de cuánta información tenía disponible al estimar.
enum NivelConfianzaValoracion {
  baja('Baja', Icons.trending_down, Color(0xFFE05B55)),
  media('Media', Icons.trending_flat, Color(0xFFD9A441)),
  alta('Alta', Icons.trending_up, Color(0xFF1FA971));

  const NivelConfianzaValoracion(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
