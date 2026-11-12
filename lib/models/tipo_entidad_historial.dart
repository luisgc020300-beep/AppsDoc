// lib/models/tipo_entidad_historial.dart
import 'package:flutter/material.dart';

enum TipoEntidadHistorial {
  proyecto('Proyecto', Icons.folder_outlined),
  funcionalidad('Funcionalidad', Icons.extension_outlined),
  documento('Documento', Icons.description_outlined),
  tarea('Tarea', Icons.check_box_outlined),
  idea('Idea', Icons.lightbulb_outline),
  auditoria('Auditoría', Icons.fact_check_outlined);

  const TipoEntidadHistorial(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}
