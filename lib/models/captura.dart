// lib/models/captura.dart
//
// Metadatos de una captura de pantalla subida manualmente a la galería del
// expediente (Fase 10). El binario vive en Cloud Storage
// (capturas/{uid}/{proyectoId}/{pantallaClave}/{capturaId}.jpg) -- este
// modelo solo guarda la ruta y los metadatos en Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'origen_captura.dart';

class Captura {
  Captura({
    required this.id,
    required this.proyectoId,
    required this.pantallaClave,
    required this.storagePath,
    this.orden = 0,
    this.origen = OrigenCaptura.manual,
    required this.subidaEn,
    this.hashContenido = '',
    this.tamanioBytes = 0,
    this.descripcion = '',
  });

  final String id;
  final String proyectoId;
  final String pantallaClave;
  final String storagePath;
  final int orden;
  final OrigenCaptura origen;
  final DateTime subidaEn;
  final String hashContenido;
  final int tamanioBytes;
  final String descripcion;

  Map<String, dynamic> toJson() => {
    'pantallaClave': pantallaClave,
    'storagePath': storagePath,
    'orden': orden,
    'origen': origen.name,
    'subidaEn': Timestamp.fromDate(subidaEn),
    'hashContenido': hashContenido,
    'tamanioBytes': tamanioBytes,
    'descripcion': descripcion,
  };

  factory Captura.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Captura(
    id: id,
    proyectoId: proyectoId,
    pantallaClave: json['pantallaClave'] as String? ?? '',
    storagePath: json['storagePath'] as String? ?? '',
    orden: (json['orden'] as num?)?.toInt() ?? 0,
    origen: OrigenCaptura.values.firstWhere((o) => o.name == json['origen'], orElse: () => OrigenCaptura.manual),
    subidaEn: (json['subidaEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    hashContenido: json['hashContenido'] as String? ?? '',
    tamanioBytes: (json['tamanioBytes'] as num?)?.toInt() ?? 0,
    descripcion: json['descripcion'] as String? ?? '',
  );
}
