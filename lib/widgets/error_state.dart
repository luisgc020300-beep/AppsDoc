// lib/widgets/error_state.dart
//
// Estado de error de pantalla completa -- antes era _ErrorState, privado
// y duplicado dentro de proyectos_list_screen.dart. Compartido por
// cualquier pantalla que consuma un stream con estado de error propio.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({required this.titulo, required this.error, super.key});

  final String titulo;
  final Object error;

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
              decoration: BoxDecoration(color: colors.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 36, color: colors.danger),
            ),
            const SizedBox(height: 20),
            Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}
