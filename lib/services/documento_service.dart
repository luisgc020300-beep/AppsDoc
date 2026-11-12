// lib/services/documento_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/categoria_documento.dart';
import '../models/documento.dart';

class DocumentoService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('documentos');

  static Stream<List<Documento>> streamDocumentos(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('updatedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Documento.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Future<String> crear({
    required String proyectoId,
    required String titulo,
    CategoriaDocumento categoria = CategoriaDocumento.nota,
    String contenido = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('DocumentoService.crear: no hay sesión iniciada');
    final tituloLimpio = titulo.trim();
    if (tituloLimpio.isEmpty) throw ArgumentError('El título del documento no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid, proyectoId).add(
      Documento(
        id: '',
        proyectoId: proyectoId,
        titulo: tituloLimpio,
        categoria: categoria,
        contenido: contenido.trim(),
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
    CategoriaDocumento? categoria,
    String? contenido,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('DocumentoService.actualizar: no hay sesión iniciada');
    if (titulo != null && titulo.trim().isEmpty) {
      throw ArgumentError('El título del documento no puede estar vacío');
    }

    final cambios = <String, dynamic>{'updatedAt': Timestamp.fromDate(DateTime.now())};
    if (titulo != null) cambios['titulo'] = titulo.trim();
    if (categoria != null) cambios['categoria'] = categoria.name;
    if (contenido != null) cambios['contenido'] = contenido.trim();

    await _coleccion(uid, proyectoId).doc(id).update(cambios);
  }

  static Future<void> eliminar(String proyectoId, String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('DocumentoService.eliminar: no hay sesión iniciada');
    await _coleccion(uid, proyectoId).doc(id).delete();
  }
}
