// lib/models/evento_historial.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'accion_historial.dart';
import 'tipo_entidad_historial.dart';

class EventoHistorial {
  EventoHistorial({
    required this.id,
    required this.proyectoId,
    required this.entidad,
    required this.accion,
    required this.descripcion,
    required this.fecha,
  });

  final String id;
  final String proyectoId;
  final TipoEntidadHistorial entidad;
  final AccionHistorial accion;
  final String descripcion;
  final DateTime fecha;

  Map<String, dynamic> toJson() => {
    'entidad': entidad.name,
    'accion': accion.name,
    'descripcion': descripcion,
    'fecha': Timestamp.fromDate(fecha),
  };

  factory EventoHistorial.fromJson(String id, String proyectoId, Map<String, dynamic> json) => EventoHistorial(
    id: id,
    proyectoId: proyectoId,
    entidad: TipoEntidadHistorial.values.firstWhere(
      (e) => e.name == json['entidad'],
      orElse: () => TipoEntidadHistorial.proyecto,
    ),
    accion: AccionHistorial.values.firstWhere((a) => a.name == json['accion'], orElse: () => AccionHistorial.actualizado),
    descripcion: json['descripcion'] as String? ?? '',
    fecha: (json['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
