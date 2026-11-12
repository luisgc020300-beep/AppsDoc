// lib/screens/proyectos/proyectos_list_screen.dart
//
// Placeholder de la Fase 0 -- la gestión real de proyectos (modelo
// Proyecto, ProyectoService, CRUD contra Firestore) es la Fase 1. Esta
// pantalla solo prueba que la puerta de autenticación y la navegación
// inicial funcionan de extremo a extremo.
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../ajustes/ajustes_screen.dart';

class ProyectosListScreen extends StatelessWidget {
  const ProyectosListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppsDoc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 48, color: colors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Aquí vivirán tus proyectos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'La gestión de proyectos llega en la próxima fase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
