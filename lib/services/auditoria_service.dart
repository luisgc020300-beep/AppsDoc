// lib/services/auditoria_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/accion_historial.dart';
import '../models/auditoria.dart';
import '../models/estado_hallazgo.dart';
import '../models/gravedad_hallazgo.dart';
import '../models/hallazgo.dart';
import '../models/origen_auditoria.dart';
import '../models/resultado_auditoria.dart';
import '../models/tipo_entidad_historial.dart';
import 'historial_service.dart';

class AuditoriaService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('auditorias');

  static Stream<List<Auditoria>> streamAuditorias(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(uid, proyectoId).orderBy('fecha', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Auditoria.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  /// Stream de una sola auditoría -- necesario porque sus hallazgos se
  /// añaden/cambian de estado/quitan mientras se sigue viendo la misma
  /// pantalla (a diferencia del resto de fichas, que solo se editan por
  /// campos y se cierran al guardar). `null` si no existe o no hay sesión.
  static Stream<Auditoria?> streamAuditoria(String proyectoId, String id) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _coleccion(uid, proyectoId).doc(id).snapshots().map(
      (d) => d.exists ? Auditoria.fromJson(d.id, proyectoId, d.data()!) : null,
    );
  }

  static Future<String> crear({
    required String proyectoId,
    required DateTime fecha,
    OrigenAuditoria origen = OrigenAuditoria.manual,
    required String resumen,
    ResultadoAuditoria resultado = ResultadoAuditoria.conObservaciones,
    List<Hallazgo> hallazgos = const [],
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('AuditoriaService.crear: no hay sesión iniciada');
    final resumenLimpio = resumen.trim();
    if (resumenLimpio.isEmpty) throw ArgumentError('El resumen de la auditoría no puede estar vacío');

    final ahora = DateTime.now();
    final ref = await _coleccion(uid, proyectoId).add(
      Auditoria(
        id: '',
        proyectoId: proyectoId,
        fecha: fecha,
        origen: origen,
        resumen: resumenLimpio,
        resultado: resultado,
        hallazgos: hallazgos,
        createdAt: ahora,
        updatedAt: ahora,
      ).toJson(),
    );
    await HistorialService.registrar(
      proyectoId: proyectoId,
      entidad: TipoEntidadHistorial.auditoria,
      accion: AccionHistorial.creado,
      descripcion: 'Auditoría creada (origen: ${origen.etiqueta}, resultado: ${resultado.etiqueta})',
    );
    return ref.id;
  }

  static Future<void> eliminar(String proyectoId, String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('AuditoriaService.eliminar: no hay sesión iniciada');
    await _coleccion(uid, proyectoId).doc(id).delete();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _doc(String uid, String proyectoId, String id) =>
      _coleccion(uid, proyectoId).doc(id).get();

  static Future<void> agregarHallazgo(
    String proyectoId,
    String auditoriaId, {
    required String titulo,
    String descripcion = '',
    GravedadHallazgo gravedad = GravedadHallazgo.media,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('AuditoriaService.agregarHallazgo: no hay sesión iniciada');
    final tituloLimpio = titulo.trim();
    if (tituloLimpio.isEmpty) throw ArgumentError('El título del hallazgo no puede estar vacío');

    final snap = await _doc(uid, proyectoId, auditoriaId);
    final auditoria = Auditoria.fromJson(snap.id, proyectoId, snap.data()!);
    final nuevoHallazgo = Hallazgo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: tituloLimpio,
      descripcion: descripcion.trim(),
      gravedad: gravedad,
    );
    final hallazgos = [...auditoria.hallazgos, nuevoHallazgo];

    await _coleccion(uid, proyectoId).doc(auditoriaId).update({
      'hallazgos': hallazgos.map((h) => h.toJson()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    await HistorialService.registrar(
      proyectoId: proyectoId,
      entidad: TipoEntidadHistorial.auditoria,
      accion: AccionHistorial.actualizado,
      descripcion: 'Auditoría actualizada (nuevo hallazgo: "$tituloLimpio")',
    );
  }

  static Future<void> actualizarEstadoHallazgo(
    String proyectoId,
    String auditoriaId,
    String hallazgoId,
    EstadoHallazgo nuevoEstado,
  ) async {
    final uid = _uid;
    if (uid == null) throw StateError('AuditoriaService.actualizarEstadoHallazgo: no hay sesión iniciada');

    final snap = await _doc(uid, proyectoId, auditoriaId);
    final auditoria = Auditoria.fromJson(snap.id, proyectoId, snap.data()!);
    String? tituloAfectado;
    final hallazgos = auditoria.hallazgos.map((h) {
      if (h.id != hallazgoId) return h;
      tituloAfectado = h.titulo;
      return h.copyWith(estado: nuevoEstado);
    }).toList();

    await _coleccion(uid, proyectoId).doc(auditoriaId).update({
      'hallazgos': hallazgos.map((h) => h.toJson()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    await HistorialService.registrar(
      proyectoId: proyectoId,
      entidad: TipoEntidadHistorial.auditoria,
      accion: AccionHistorial.actualizado,
      descripcion: 'Auditoría actualizada (hallazgo "${tituloAfectado ?? hallazgoId}" → ${nuevoEstado.etiqueta})',
    );
  }

  static Future<void> eliminarHallazgo(String proyectoId, String auditoriaId, String hallazgoId) async {
    final uid = _uid;
    if (uid == null) throw StateError('AuditoriaService.eliminarHallazgo: no hay sesión iniciada');

    final snap = await _doc(uid, proyectoId, auditoriaId);
    final auditoria = Auditoria.fromJson(snap.id, proyectoId, snap.data()!);
    final hallazgos = auditoria.hallazgos.where((h) => h.id != hallazgoId).toList();

    await _coleccion(uid, proyectoId).doc(auditoriaId).update({
      'hallazgos': hallazgos.map((h) => h.toJson()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
