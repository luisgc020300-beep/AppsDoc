// lib/models/mensaje_asistente.dart
//
// Un turno del chat con el asistente de IA (pregunta del usuario o
// respuesta/error de la IA), persistido para que el historial sobreviva a
// salir y volver a entrar en la pantalla.
import 'package:cloud_firestore/cloud_firestore.dart';

class MensajeAsistente {
  MensajeAsistente({
    required this.id,
    required this.proyectoId,
    required this.texto,
    required this.esUsuario,
    this.esError = false,
    required this.fecha,
  });

  final String id;
  final String proyectoId;
  final String texto;
  final bool esUsuario;
  final bool esError;
  final DateTime fecha;

  Map<String, dynamic> toJson() => {
    'texto': texto,
    'esUsuario': esUsuario,
    'esError': esError,
    'fecha': Timestamp.fromDate(fecha),
  };

  factory MensajeAsistente.fromJson(String id, String proyectoId, Map<String, dynamic> json) => MensajeAsistente(
    id: id,
    proyectoId: proyectoId,
    texto: json['texto'] as String? ?? '',
    esUsuario: json['esUsuario'] as bool? ?? false,
    esError: json['esError'] as bool? ?? false,
    fecha: (json['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
