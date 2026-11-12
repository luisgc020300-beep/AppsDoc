// lib/services/idea_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/estado_idea.dart';
import '../models/idea.dart';

class IdeaService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('ideas');

  static Stream<List<Idea>> streamIdeas(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('updatedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Idea.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Future<String> crear({
    required String proyectoId,
    required String titulo,
    String descripcion = '',
    String notas = '',
    EstadoIdea estado = EstadoIdea.nueva,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('IdeaService.crear: no hay sesión iniciada');
    final tituloLimpio = titulo.trim();
    if (tituloLimpio.isEmpty) throw ArgumentError('El título de la idea no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid, proyectoId).add(
      Idea(
        id: '',
        proyectoId: proyectoId,
        titulo: tituloLimpio,
        descripcion: descripcion.trim(),
        notas: notas.trim(),
        estado: estado,
        createdAt: ahora,
        updatedAt: ahora,
      ).toJson(),
    );
    return ref.id;
  }

  static Future<void> actualizar(
    String proyectoId,
    String id, {
    String? titulo,
    String? descripcion,
    String? notas,
    EstadoIdea? estado,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('IdeaService.actualizar: no hay sesión iniciada');
    if (titulo != null && titulo.trim().isEmpty) {
      throw ArgumentError('El título de la idea no puede estar vacío');
    }

    final cambios = <String, dynamic>{'updatedAt': Timestamp.fromDate(DateTime.now())};
    if (titulo != null) cambios['titulo'] = titulo.trim();
    if (descripcion != null) cambios['descripcion'] = descripcion.trim();
    if (notas != null) cambios['notas'] = notas.trim();
    if (estado != null) cambios['estado'] = estado.name;

    await _coleccion(uid, proyectoId).doc(id).update(cambios);
  }

  static Future<void> eliminar(String proyectoId, String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('IdeaService.eliminar: no hay sesión iniciada');
    await _coleccion(uid, proyectoId).doc(id).delete();
  }
}
