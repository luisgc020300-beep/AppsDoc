// lib/screens/ajustes/ajustes_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/theme_controller.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final correo = FirebaseAuth.instance.currentUser?.email ?? '';
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (correo.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: colors.accentMuted,
                        child: Icon(Icons.person, color: colors.accent, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tu cuenta', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(correo, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('Tema', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: controller.mode,
                onChanged: (m) => controller.setMode(m!),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(title: Text('Según el sistema'), value: ThemeMode.system),
                    RadioListTile<ThemeMode>(title: Text('Claro'), value: ThemeMode.light),
                    RadioListTile<ThemeMode>(title: Text('Oscuro'), value: ThemeMode.dark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: colors.danger),
                title: Text('Cerrar sesión', style: TextStyle(color: colors.danger)),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
