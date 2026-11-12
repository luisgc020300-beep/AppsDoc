// lib/models/auditoria.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'hallazgo.dart';
import 'origen_auditoria.dart';
import 'resultado_auditoria.dart';

class Auditoria {
  Auditoria({
    required this.id,
    required this.proyectoId,
    required this.fecha,
    this.origen = OrigenAuditoria.manual,
    required this.resumen,
    this.resultado = ResultadoAuditoria.conObservaciones,
    List<Hallazgo>? hallazgos,
    required this.createdAt,
    required this.updatedAt,
  }) : hallazgos = hallazgos ?? [];

  final String id;
  final String proyectoId;
  final DateTime fecha;
  final OrigenAuditoria origen;
  final String resumen;
  final ResultadoAuditoria resultado;
  final List<Hallazgo> hallazgos;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get hallazgosAbiertos => hallazgos.where((h) => h.estado.name == 'abierto' || h.estado.name == 'enProgreso').length;

  Map<String, dynamic> toJson() => {
    'fecha': Timestamp.fromDate(fecha),
    'origen': origen.name,
    'resumen': resumen,
    'resultado': resultado.name,
    'hallazgos': hallazgos.map((h) => h.toJson()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Auditoria.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Auditoria(
    id: id,
    proyectoId: proyectoId,
    fecha: (json['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    origen: OrigenAuditoria.values.firstWhere((o) => o.name == json['origen'], orElse: () => OrigenAuditoria.manual),
    resumen: json['resumen'] as String? ?? '',
    resultado: ResultadoAuditoria.values.firstWhere(
      (r) => r.name == json['resultado'],
      orElse: () => ResultadoAuditoria.conObservaciones,
    ),
    hallazgos: (json['hallazgos'] as List<dynamic>? ?? [])
        .map((h) => Hallazgo.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList(),
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
