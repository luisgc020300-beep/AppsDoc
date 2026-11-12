// lib/models/funcionalidad.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_funcionalidad.dart';

class Funcionalidad {
  Funcionalidad({
    required this.id,
    required this.proyectoId,
    required this.nombre,
    this.descripcion = '',
    this.estado = EstadoFuncionalidad.planificada,
    this.notas = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String proyectoId;
  final String nombre;
  final String descripcion;
  final EstadoFuncionalidad estado;
  final String notas;
  final DateTime createdAt;
  final DateTime updatedAt;

  Funcionalidad copyWith({String? nombre, String? descripcion, EstadoFuncionalidad? estado, String? notas, DateTime? updatedAt}) {
    return Funcionalidad(
      id: id,
      proyectoId: proyectoId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'estado': estado.name,
    'notas': notas,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Funcionalidad.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Funcionalidad(
    id: id,
    proyectoId: proyectoId,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    estado: EstadoFuncionalidad.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoFuncionalidad.planificada,
    ),
    notas: json['notas'] as String? ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
