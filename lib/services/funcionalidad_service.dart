// lib/services/funcionalidad_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/estado_funcionalidad.dart';
import '../models/funcionalidad.dart';

class FuncionalidadService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('funcionalidades');

  static Stream<List<Funcionalidad>> streamFuncionalidades(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('updatedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Funcionalidad.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Future<String> crear({
    required String proyectoId,
    required String nombre,
    String descripcion = '',
    EstadoFuncionalidad estado = EstadoFuncionalidad.planificada,
    String notas = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('FuncionalidadService.crear: no hay sesión iniciada');
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) throw ArgumentError('El nombre de la funcionalidad no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid, proyectoId).add(
      Funcionalidad(
        id: '',
        proyectoId: proyectoId,
        nombre: nombreLimpio,
        descripcion: descripcion.trim(),
        estado: estado,
        notas: notas.trim(),
        createdAt: ahora,
        updatedAt: ahora,
      ).toJson(),
    );
    return ref.id;
  }

  static Future<void> actualizar(
    String proyectoId,
    String id, {
    String? nombre,
    String? descripcion,
    EstadoFuncionalidad? estado,
    String? notas,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('FuncionalidadService.actualizar: no hay sesión iniciada');
    if (nombre != null && nombre.trim().isEmpty) {
      throw ArgumentError('El nombre de la funcionalidad no puede estar vacío');
    }

    final cambios = <String, dynamic>{'updatedAt': Timestamp.fromDate(DateTime.now())};
    if (nombre != null) cambios['nombre'] = nombre.trim();
    if (descripcion != null) cambios['descripcion'] = descripcion.trim();
    if (estado != null) cambios['estado'] = estado.name;
    if (notas != null) cambios['notas'] = notas.trim();

    await _coleccion(uid, proyectoId).doc(id).update(cambios);
  }

  static Future<void> eliminar(String proyectoId, String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('FuncionalidadService.eliminar: no hay sesión iniciada');
    await _coleccion(uid, proyectoId).doc(id).delete();
  }
}
