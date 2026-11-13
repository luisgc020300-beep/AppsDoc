// lib/models/origen_captura.dart
import 'package:flutter/material.dart';

/// De dónde viene una captura de pantalla de la galería (Fase 10). Hoy solo
/// se usa `manual` -- el usuario la sube a mano. `automatica` queda
/// preparado para una futura captura vía emulador/CI, no implementada aún.
enum OrigenCaptura {
  manual('Manual', Icons.upload_outlined, Color(0xFF5B6EF5)),
  automatica('Automática', Icons.auto_awesome, Color(0xFF8A93A6));

  const OrigenCaptura(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
