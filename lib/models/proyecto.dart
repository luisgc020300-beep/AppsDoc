// lib/models/proyecto.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_proyecto.dart';

/// Ficha básica de un proyecto (Fase 1). Documentación, funcionalidades,
/// tareas, auditorías, progreso, GitHub e IA son de fases posteriores --
/// el modelo se amplía cuando esa fase lo necesite, no antes.
class Proyecto {
  Proyecto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.estado = EstadoProyecto.idea,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final EstadoProyecto estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  Proyecto copyWith({String? nombre, String? descripcion, EstadoProyecto? estado, DateTime? updatedAt}) {
    return Proyecto(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'estado': estado.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Proyecto.fromJson(String id, Map<String, dynamic> json) => Proyecto(
    id: id,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    estado: EstadoProyecto.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoProyecto.idea,
    ),
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
