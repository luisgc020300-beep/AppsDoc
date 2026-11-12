// lib/models/app_project.dart
import 'estado_app.dart';
import 'pendiente.dart';

class AppProject {
  AppProject({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.stack = '',
    this.ruta = '',
    this.estado = EstadoApp.enDesarrollo,
    List<Pendiente>? pendientes,
  }) : pendientes = pendientes ?? [];

  final String id;
  final String nombre;
  final String descripcion;
  final String stack;
  final String ruta;
  final EstadoApp estado;
  final List<Pendiente> pendientes;

  int get pendientesSinHacer => pendientes.where((p) => !p.hecho).length;

  AppProject copyWith({
    String? nombre,
    String? descripcion,
    String? stack,
    String? ruta,
    EstadoApp? estado,
    List<Pendiente>? pendientes,
  }) {
    return AppProject(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      stack: stack ?? this.stack,
      ruta: ruta ?? this.ruta,
      estado: estado ?? this.estado,
      pendientes: pendientes ?? this.pendientes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'stack': stack,
    'ruta': ruta,
    'estado': estado.name,
    'pendientes': pendientes.map((p) => p.toJson()).toList(),
  };

  factory AppProject.fromJson(Map<String, dynamic> json) => AppProject(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    descripcion: json['descripcion'] as String? ?? '',
    stack: json['stack'] as String? ?? '',
    ruta: json['ruta'] as String? ?? '',
    estado: EstadoApp.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoApp.enDesarrollo,
    ),
    pendientes: (json['pendientes'] as List<dynamic>? ?? [])
        .map((p) => Pendiente.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}
