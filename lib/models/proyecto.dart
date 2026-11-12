// lib/models/proyecto.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_proyecto.dart';

/// Ficha básica de un proyecto. GitHub e IA son de fases posteriores -- el
/// modelo se amplía cuando esa fase lo necesite, no antes.
class Proyecto {
  Proyecto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.estado = EstadoProyecto.idea,
    this.progresoPorcentaje = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final EstadoProyecto estado;

  /// Caché de ProgresoService.calcular() -- nunca se escribe a mano desde
  /// la UI (no está en copyWith ni en ProyectoService.actualizar() a
  /// propósito). Solo ProyectoService.recalcularProgreso() lo recalcula y
  /// lo guarda, disparado automáticamente tras cualquier cambio en
  /// funcionalidades/tareas/documentos/auditorías del proyecto.
  final int progresoPorcentaje;
  final DateTime createdAt;
  final DateTime updatedAt;

  Proyecto copyWith({String? nombre, String? descripcion, EstadoProyecto? estado, DateTime? updatedAt}) {
    return Proyecto(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      progresoPorcentaje: progresoPorcentaje,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'estado': estado.name,
    'progresoPorcentaje': progresoPorcentaje,
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
    progresoPorcentaje: (json['progresoPorcentaje'] as num?)?.toInt() ?? 0,
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
