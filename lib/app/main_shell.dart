// lib/app/main_shell.dart
//
// Contenedor con navegación inferior (Fase 8): las cuatro pestañas usan
// pantallas ya existentes -- Proyectos, el nuevo selector de proyecto para
// el Asistente, Actividad y Ajustes (como "Perfil") -- IndexedStack
// conserva el estado de cada una al cambiar de pestaña.
import 'package:flutter/material.dart';

import '../screens/actividad/actividad_screen.dart';
import '../screens/ajustes/ajustes_screen.dart';
import '../screens/asistente/elegir_proyecto_asistente_screen.dart';
import '../screens/proyectos/proyectos_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indice = 0;
  final _visitadas = {0};

  static const _pantallas = [
    ProyectosListScreen(),
    ElegirProyectoAsistenteScreen(),
    ActividadScreen(),
    AjustesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack con construcción perezosa: cada pestaña solo se monta
      // la primera vez que se visita (y conserva su estado después, al no
      // desmontarla) -- evita suscribir streams de las cuatro pantallas de
      // golpe al abrir la app cuando puede que el usuario solo use una.
      body: IndexedStack(
        index: _indice,
        children: [for (var i = 0; i < _pantallas.length; i++) _visitadas.contains(i) ? _pantallas[i] : const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() {
          _indice = i;
          _visitadas.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize), label: 'Proyectos'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Asistente'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Actividad'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
