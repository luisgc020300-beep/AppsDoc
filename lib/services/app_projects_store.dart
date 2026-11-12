// lib/services/app_projects_store.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_project.dart';
import '../models/estado_app.dart';
import '../models/pendiente.dart';

/// Persistencia local simple -- un solo usuario, un solo dispositivo, nada
/// de backend. Todo vive en un único JSON dentro de shared_preferences.
class AppProjectsStore {
  static const _key = 'appsdoc.proyectos.v1';

  Future<List<AppProject>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      final semilla = _semillaInicial();
      await guardar(semilla);
      return semilla;
    }
    final lista = jsonDecode(raw) as List<dynamic>;
    return lista.map((e) => AppProject.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> guardar(List<AppProject> proyectos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(proyectos.map((p) => p.toJson()).toList()));
  }

  /// Punto de partida con tus apps actuales -- edítalo libremente desde la
  /// propia app, esto es solo para no arrancar con la lista vacía.
  List<AppProject> _semillaInicial() => [
    AppProject(
      id: 'riskrunner',
      nombre: 'RiskRunner',
      descripcion: 'Conquista territorial de running: cubre barrios corriendo, reta a rivales reales.',
      stack: 'Flutter, Firebase, Mapbox',
      ruta: 'c:\\dev\\mi_app',
      estado: EstadoApp.enDesarrollo,
      pendientes: [
        Pendiente(id: 'rr-1', texto: 'Apple Developer (99€) + Google Play (25€) para publicar'),
        Pendiente(id: 'rr-2', texto: 'Decidir si seguir recortando pantallas sobrecargadas (Social/Perfil)'),
      ],
    ),
    AppProject(
      id: 'convive',
      nombre: 'Convive',
      descripcion: 'App de piso compartido: tareas rotativas, chat, gastos y recordatorios.',
      stack: 'Flutter, Firebase',
      ruta: 'c:\\dev\\convive',
      estado: EstadoApp.enDesarrollo,
      pendientes: [
        Pendiente(id: 'cv-1', texto: 'FCM real + Firebase App Check antes de TestFlight/Play interno'),
        Pendiente(id: 'cv-2', texto: 'Revisar si queda algún deploy o push pendiente de confirmar'),
      ],
    ),
    AppProject(
      id: 'repara',
      nombre: 'REPARA',
      descripcion: 'Mantenimiento del hogar: trabajos, presupuestos, pagos y profesionales invitados.',
      stack: 'Flutter, Firebase',
      ruta: 'c:\\dev\\repara',
      estado: EstadoApp.enDesarrollo,
      pendientes: [
        Pendiente(id: 'rp-1', texto: 'Push notifications reales (FCM) -- falta clave APNs'),
        Pendiente(id: 'rp-2', texto: 'Decidir cuándo pasar App Check de Monitor a Enforce'),
      ],
    ),
  ];
}
