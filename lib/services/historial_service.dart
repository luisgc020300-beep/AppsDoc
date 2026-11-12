// lib/services/historial_service.dart
//
// Lo escriben directamente el resto de servicios (crear/actualizar de
// Proyecto, Funcionalidad, Documento, Tarea, Idea, Auditoria) tras cada
// escritura -- nunca el cliente por su cuenta. No hace falta Cloud
// Function para esto (a diferencia de REPARA): aquí no hay un segundo
// actor del que protegerse, el único lector/escritor es el propio dueño.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/accion_historial.dart';
import '../models/evento_historial.dart';
import '../models/tipo_entidad_historial.dart';

class HistorialService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('historial');

  static Stream<List<EventoHistorial>> streamHistorial(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('fecha', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => EventoHistorial.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  /// Silencioso si no hay sesión -- un evento de historial que no se pudo
  /// registrar nunca debe tumbar la operación principal que lo disparó.
  static Future<void> registrar({
    required String proyectoId,
    required TipoEntidadHistorial entidad,
    required AccionHistorial accion,
    required String descripcion,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _coleccion(uid, proyectoId).add(
      EventoHistorial(
        id: '',
        proyectoId: proyectoId,
        entidad: entidad,
        accion: accion,
        descripcion: descripcion,
        fecha: DateTime.now(),
      ).toJson(),
    );
  }
}
