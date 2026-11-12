// lib/models/documento.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'categoria_documento.dart';

class Documento {
  Documento({
    required this.id,
    required this.proyectoId,
    required this.titulo,
    this.categoria = CategoriaDocumento.nota,
    this.contenido = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String proyectoId;
  final String titulo;
  final CategoriaDocumento categoria;
  final String contenido;
  final DateTime createdAt;
  final DateTime updatedAt;

  Documento copyWith({String? titulo, CategoriaDocumento? categoria, String? contenido, DateTime? updatedAt}) {
    return Documento(
      id: id,
      proyectoId: proyectoId,
      titulo: titulo ?? this.titulo,
      categoria: categoria ?? this.categoria,
      contenido: contenido ?? this.contenido,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'categoria': categoria.name,
    'contenido': contenido,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Documento.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Documento(
    id: id,
    proyectoId: proyectoId,
    titulo: json['titulo'] as String? ?? '',
    categoria: CategoriaDocumento.values.firstWhere(
      (c) => c.name == json['categoria'],
      orElse: () => CategoriaDocumento.nota,
    ),
    contenido: json['contenido'] as String? ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
