// lib/widgets/seccion_header.dart
//
// Cabecera de sección reutilizable: icono + título + acción opcional
// (normalmente el botón de añadir). Antes era un Row(Expanded(Text),
// IconButton) repetido en cada sección de la ficha de proyecto.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class SeccionHeader extends StatelessWidget {
  const SeccionHeader({required this.titulo, this.icono, this.accion, super.key});

  final String titulo;
  final IconData? icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        if (icono != null) ...[Icon(icono, size: 18, color: colors.accent), const SizedBox(width: 8)],
        Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleMedium)),
        ?accion,
      ],
    );
  }
}
