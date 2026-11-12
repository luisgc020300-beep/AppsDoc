// lib/app/appsdoc_app.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/proyectos/proyectos_list_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';
import 'auth_gate.dart';

class AppsDocApp extends StatelessWidget {
  const AppsDocApp({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AppsDoc',
        themeMode: themeController.mode,
        theme: buildAppsDocLightTheme(),
        darkTheme: buildAppsDocDarkTheme(),
        home: AuthGate<User>(
          authStateChanges: FirebaseAuth.instance.authStateChanges(),
          onAutenticado: (_) => const ProyectosListScreen(),
          onSinSesion: (_) => const LoginScreen(),
        ),
      ),
    );
  }
}
