// lib/services/proyecto_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/accion_historial.dart';
import '../models/estado_proyecto.dart';
import '../models/proyecto.dart';
import '../models/tipo_entidad_historial.dart';
import 'historial_service.dart';

class ProyectoService {
  /// Seams de solo test -- nunca se asignan en código de producción. Mismo
  /// criterio que el resto de servicios de RiskRunner/Convive/REPARA:
  /// debugFirestoreOverride (no debugUidOverride) es la señal real de
  /// "estamos en test", para poder simular uid null a propósito.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid) =>
      _db.collection('usuarios').doc(uid).collection('proyectos');

  /// Lista vacía mientras no hay sesión -- nunca lanza, para que la UI
  /// pueda tratarlo igual que "todavía no hay proyectos".
  static Stream<List<Proyecto>> streamProyectos() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid).orderBy('updatedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Proyecto.fromJson(d.id, d.data())).toList(),
    );
  }

  /// `null` mientras no hay sesión o si el proyecto no existe (incluido
  /// justo después de haberse eliminado) -- la UI trata ambos casos igual.
  static Stream<Proyecto?> streamProyecto(String id) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _coleccion(uid).doc(id).snapshots().map((d) => d.exists ? Proyecto.fromJson(d.id, d.data()!) : null);
  }

  static Future<String> crear({required String nombre, String descripcion = '', EstadoProyecto estado = EstadoProyecto.idea}) async {
    final uid = _uid;
    if (uid == null) throw StateError('ProyectoService.crear: no hay sesión iniciada');
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) throw ArgumentError('El nombre del proyecto no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid).add(
      Proyecto(
        id: '',
        nombre: nombreLimpio,
        descripcion: descripcion.trim(),
        estado: estado,
        createdAt: ahora,
        updatedAt: ahora,
      ).toJson(),
    );
    await HistorialService.registrar(
      proyectoId: ref.id,
      entidad: TipoEntidadHistorial.proyecto,
      accion: AccionHistorial.creado,
      descripcion: 'Proyecto creado: "$nombreLimpio"',
    );
    return ref.id;
  }

  static Future<void> actualizar(String id, {String? nombre, String? descripcion, EstadoProyecto? estado}) async {
    final uid = _uid;
    if (uid == null) throw StateError('ProyectoService.actualizar: no hay sesión iniciada');
    if (nombre != null && nombre.trim().isEmpty) {
      throw ArgumentError('El nombre del proyecto no puede estar vacío');
    }

    final cambios = <String, dynamic>{'updatedAt': Timestamp.fromDate(DateTime.now())};
    final camposCambiados = <String>[];
    if (nombre != null) {
      cambios['nombre'] = nombre.trim();
      camposCambiados.add('nombre');
    }
    if (descripcion != null) {
      cambios['descripcion'] = descripcion.trim();
      camposCambiados.add('descripción');
    }
    if (estado != null) {
      cambios['estado'] = estado.name;
      camposCambiados.add('estado');
    }

    await _coleccion(uid).doc(id).update(cambios);
    if (camposCambiados.isNotEmpty) {
      await HistorialService.registrar(
        proyectoId: id,
        entidad: TipoEntidadHistorial.proyecto,
        accion: AccionHistorial.actualizado,
        descripcion: 'Proyecto actualizado (${camposCambiados.join(', ')})',
      );
    }
  }

  static Future<void> eliminar(String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('ProyectoService.eliminar: no hay sesión iniciada');
    await _coleccion(uid).doc(id).delete();
  }
}
