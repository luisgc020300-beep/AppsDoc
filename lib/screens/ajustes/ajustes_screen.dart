// lib/screens/ajustes/ajustes_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/theme_controller.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final correo = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          children: [
            if (correo.isNotEmpty)
              ListTile(leading: const Icon(Icons.person_outline), title: const Text('Cuenta'), subtitle: Text(correo)),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Tema'),
            ),
            RadioGroup<ThemeMode>(
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
