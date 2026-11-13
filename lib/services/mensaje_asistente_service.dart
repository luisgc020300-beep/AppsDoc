// lib/services/mensaje_asistente_service.dart
//
// Historial persistido del chat del asistente de IA (antes era efímero,
// solo en memoria de AsistenteScreen -- el CEO pidió que sobreviviera a
// salir y volver a entrar). Un mensaje más, igual que cualquier otra
// entidad del proyecto: usuarios/{uid}/proyectos/{id}/mensajesAsistente.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/mensaje_asistente.dart';

class MensajeAsistenteService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('mensajesAsistente');

  static Stream<List<MensajeAsistente>> streamMensajes(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(
      uid,
      proyectoId,
    ).orderBy('fecha').snapshots().map((snap) => snap.docs.map((d) => MensajeAsistente.fromJson(d.id, proyectoId, d.data())).toList());
  }

  static Future<void> agregar({
    required String proyectoId,
    required String texto,
    required bool esUsuario,
    bool esError = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('MensajeAsistenteService.agregar: no hay sesión iniciada');
    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty) throw ArgumentError('El texto del mensaje no puede estar vacío');

    await _coleccion(uid, proyectoId).add(
      MensajeAsistente(
        id: '',
        proyectoId: proyectoId,
        texto: textoLimpio,
        esUsuario: esUsuario,
        esError: esError,
        fecha: DateTime.now(),
      ).toJson(),
    );
  }

  /// Borra todo el historial de este proyecto -- "Nueva conversación" en
  /// AsistenteScreen. Irreversible, siempre tras confirmación del usuario.
  /// Documento a documento en vez de con WriteBatch: el número de mensajes
  /// de un chat nunca es tan grande como para que importe el rendimiento,
  /// y así queda igual de simple que el resto de servicios.
  static Future<void> limpiar(String proyectoId) async {
    final uid = _uid;
    if (uid == null) throw StateError('MensajeAsistenteService.limpiar: no hay sesión iniciada');
    final snap = await _coleccion(uid, proyectoId).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
