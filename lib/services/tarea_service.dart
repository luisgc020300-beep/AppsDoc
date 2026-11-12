// lib/services/tarea_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/accion_historial.dart';
import '../models/estado_tarea.dart';
import '../models/prioridad_tarea.dart';
import '../models/tarea.dart';
import '../models/tipo_entidad_historial.dart';
import 'historial_service.dart';
import 'proyecto_service.dart';

class TareaService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('tareas');

  static Stream<List<Tarea>> streamTareas(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('updatedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Tarea.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Future<String> crear({
    required String proyectoId,
    required String titulo,
    String descripcion = '',
    EstadoTarea estado = EstadoTarea.pendiente,
    PrioridadTarea prioridad = PrioridadTarea.media,
    DateTime? fechaLimite,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('TareaService.crear: no hay sesión iniciada');
    final tituloLimpio = titulo.trim();
    if (tituloLimpio.isEmpty) throw ArgumentError('El título de la tarea no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid, proyectoId).add(
      Tarea(
        id: '',
        proyectoId: proyectoId,
        titulo: tituloLimpio,
        descripcion: descripcion.trim(),
        estado: estado,
        prioridad: prioridad,
        fechaLimite: fechaLimite,
        createdAt: ahora,
        updatedAt: ahora,
      ).toJson(),
    );
    await HistorialService.registrar(
      proyectoId: proyectoId,
      entidad: TipoEntidadHistorial.tarea,
      accion: AccionHistorial.creado,
      descripcion: 'Tarea creada: "$tituloLimpio"',
    );
    await ProyectoService.recalcularProgreso(proyectoId);
    return ref.id;
  }

  /// [quitarFechaLimite] permite borrar la fecha ya puesta -- distinguir
  /// "no tocar la fecha" (omitir el parámetro) de "quitarla" (true) no se
  /// puede hacer solo con `DateTime? fechaLimite` porque null es ambiguo
  /// entre ambos casos.
  static Future<void> actualizar(
    String proyectoId,
    String id, {
    String? titulo,
    String? descripcion,
    EstadoTarea? estado,
    PrioridadTarea? prioridad,
    DateTime? fechaLimite,
    bool quitarFechaLimite = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('TareaService.actualizar: no hay sesión iniciada');
    if (titulo != null && titulo.trim().isEmpty) {
      throw ArgumentError('El título de la tarea no puede estar vacío');
    }

    final cambios = <String, dynamic>{'updatedAt': Timestamp.fromDate(DateTime.now())};
    final camposCambiados = <String>[];
    if (titulo != null) {
      cambios['titulo'] = titulo.trim();
      camposCambiados.add('título');
    }
    if (descripcion != null) {
      cambios['descripcion'] = descripcion.trim();
      camposCambiados.add('descripción');
    }
    if (estado != null) {
      cambios['estado'] = estado.name;
      camposCambiados.add('estado');
    }
    if (prioridad != null) {
      cambios['prioridad'] = prioridad.name;
      camposCambiados.add('prioridad');
    }
    if (quitarFechaLimite) {
      cambios['fechaLimite'] = null;
      camposCambiados.add('fecha límite');
    } else if (fechaLimite != null) {
      cambios['fechaLimite'] = Timestamp.fromDate(fechaLimite);
      camposCambiados.add('fecha límite');
    }

    await _coleccion(uid, proyectoId).doc(id).update(cambios);
    if (camposCambiados.isNotEmpty) {
      await HistorialService.registrar(
        proyectoId: proyectoId,
        entidad: TipoEntidadHistorial.tarea,
        accion: AccionHistorial.actualizado,
        descripcion: 'Tarea actualizada (${camposCambiados.join(', ')})',
      );
      await ProyectoService.recalcularProgreso(proyectoId);
    }
  }

  static Future<void> eliminar(String proyectoId, String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('TareaService.eliminar: no hay sesión iniciada');
    await _coleccion(uid, proyectoId).doc(id).delete();
    await ProyectoService.recalcularProgreso(proyectoId);
  }
}
