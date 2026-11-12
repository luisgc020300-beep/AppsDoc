// lib/main.dart
//
// AppsDoc -- herramienta personal del CEO para tener de un vistazo el
// estado y los pendientes de todas sus apps (RiskRunner, Convive, REPARA...).
// Un solo usuario, un solo dispositivo: todo se guarda en local
// (shared_preferences), sin backend.
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const AppsDocApp());
}

class AppsDocApp extends StatelessWidget {
  const AppsDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AppsDoc',
      themeMode: ThemeMode.system,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
