// lib/models/idea.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_idea.dart';

class Idea {
  Idea({
    required this.id,
    required this.proyectoId,
    required this.titulo,
    this.descripcion = '',
    this.notas = '',
    this.estado = EstadoIdea.nueva,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String proyectoId;
  final String titulo;
  final String descripcion;
  final String notas;
  final EstadoIdea estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  Idea copyWith({String? titulo, String? descripcion, String? notas, EstadoIdea? estado, DateTime? updatedAt}) {
    return Idea(
      id: id,
      proyectoId: proyectoId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'notas': notas,
    'estado': estado.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Idea.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Idea(
    id: id,
    proyectoId: proyectoId,
    titulo: json['titulo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    notas: json['notas'] as String? ?? '',
    estado: EstadoIdea.values.firstWhere((e) => e.name == json['estado'], orElse: () => EstadoIdea.nueva),
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
