// lib/models/estado_expediente.dart
import 'package:flutter/material.dart';

/// Ciclo de vida de UNA versión de Expediente (Fase 10). "borrador" es lo que
/// acaba de devolver generarExpediente, pendiente de revisión -- nunca se
/// muestra como la versión vigente del proyecto hasta que el usuario pulsa
/// "Confirmar expediente" y pasa a "confirmado".
enum EstadoExpediente {
  borrador('Borrador', Icons.edit_note, Color(0xFF8A93A6)),
  confirmado('Confirmado', Icons.check_circle, Color(0xFF1FA971));

  const EstadoExpediente(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}
