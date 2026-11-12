// lib/models/tarea.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_tarea.dart';
import 'prioridad_tarea.dart';

class Tarea {
  Tarea({
    required this.id,
    required this.proyectoId,
    required this.titulo,
    this.descripcion = '',
    this.estado = EstadoTarea.pendiente,
    this.prioridad = PrioridadTarea.media,
    this.fechaLimite,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String proyectoId;
  final String titulo;
  final String descripcion;
  final EstadoTarea estado;
  final PrioridadTarea prioridad;
  final DateTime? fechaLimite;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get vencida =>
      fechaLimite != null &&
      fechaLimite!.isBefore(DateTime.now()) &&
      estado != EstadoTarea.completada &&
      estado != EstadoTarea.cancelada;

  Tarea copyWith({
    String? titulo,
    String? descripcion,
    EstadoTarea? estado,
    PrioridadTarea? prioridad,
    DateTime? fechaLimite,
    bool quitarFechaLimite = false,
    DateTime? updatedAt,
  }) {
    return Tarea(
      id: id,
      proyectoId: proyectoId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      prioridad: prioridad ?? this.prioridad,
      fechaLimite: quitarFechaLimite ? null : (fechaLimite ?? this.fechaLimite),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'estado': estado.name,
    'prioridad': prioridad.name,
    'fechaLimite': fechaLimite == null ? null : Timestamp.fromDate(fechaLimite!),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Tarea.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Tarea(
    id: id,
    proyectoId: proyectoId,
    titulo: json['titulo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    estado: EstadoTarea.values.firstWhere((e) => e.name == json['estado'], orElse: () => EstadoTarea.pendiente),
    prioridad: PrioridadTarea.values.firstWhere((p) => p.name == json['prioridad'], orElse: () => PrioridadTarea.media),
    fechaLimite: (json['fechaLimite'] as Timestamp?)?.toDate(),
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
