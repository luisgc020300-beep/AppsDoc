// lib/widgets/empty_state.dart
//
// Estado vacío de pantalla completa -- antes era _EmptyState, privado y
// duplicado dentro de proyectos_list_screen.dart. Ahora es compartido por
// cualquier pantalla que pueda no tener nada que mostrar todavía
// (proyectos, actividad...).
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icono, required this.titulo, this.subtitulo, this.accion, super.key});

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icono, size: 36, color: colors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(subtitulo!, textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
            ],
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}
