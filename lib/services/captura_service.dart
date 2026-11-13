// lib/services/captura_service.dart
//
// Galería de capturas manuales del expediente (Fase 10). El binario vive en
// Cloud Storage (capturas/{uid}/{proyectoId}/{pantallaClave}/{capturaId}.ext,
// reglas espejo de Firestore en storage.rules); los metadatos en
// usuarios/{uid}/proyectos/{proyectoId}/capturas/{capturaId}. Las capturas
// sobreviven a cualquier reanálisis porque referencian pantallaClave (de
// pantallasCatalogo, ver ExpedienteService), nunca un índice o nombre de
// pantalla que pueda cambiar entre versiones.
//
// fake_cloud_firestore no tiene equivalente para Storage -- por eso la
// subida/descarga/borrado del binario en sí tienen su propio seam de test
// (debugSubidaOverride/debugUrlDescargaOverride/debugEliminarArchivoOverride),
// independiente de debugFirestoreOverride, que solo cubre los metadatos.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/captura.dart';
import '../models/origen_captura.dart';

class CapturaService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;
  @visibleForTesting
  static Future<void> Function(String storagePath, Uint8List bytes, String contentType)? debugSubidaOverride;
  @visibleForTesting
  static Future<String> Function(String storagePath)? debugUrlDescargaOverride;
  @visibleForTesting
  static Future<void> Function(String storagePath)? debugEliminarArchivoOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('capturas');

  /// Todas las capturas del proyecto, más recientes primero. La galería las
  /// agrupa por pantallaClave en memoria -- con los pocos cientos de
  /// capturas que cabe esperar por proyecto no hace falta una query por
  /// pantalla ni un índice compuesto nuevo.
  static Stream<List<Captura>> streamCapturas(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(
      uid,
      proyectoId,
    ).orderBy('subidaEn', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Captura.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Future<String> obtenerUrl(String storagePath) async {
    if (debugUrlDescargaOverride != null) return debugUrlDescargaOverride!(storagePath);
    return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
  }

  /// Sube la imagen si no existe ya una captura idéntica (mismo hash) para
  /// esa pantalla -- en ese caso devuelve la existente sin volver a subir
  /// ni crear metadatos nuevos.
  static Future<Captura> subir({
    required String proyectoId,
    required String pantallaClave,
    required Uint8List bytes,
    String extension = 'jpg',
    String descripcion = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('CapturaService.subir: no hay sesión iniciada');
    if (pantallaClave.isEmpty) throw ArgumentError('pantallaClave no puede estar vacía');

    final hash = sha256.convert(bytes).toString();
    final existentesSnap = await _coleccion(uid, proyectoId).where('pantallaClave', isEqualTo: pantallaClave).get();
    for (final doc in existentesSnap.docs) {
      if (doc.data()['hashContenido'] == hash) {
        return Captura.fromJson(doc.id, proyectoId, doc.data());
      }
    }

    final docRef = _coleccion(uid, proyectoId).doc();
    final storagePath = 'capturas/$uid/$proyectoId/$pantallaClave/${docRef.id}.$extension';
    final contentType = 'image/$extension';

    if (debugSubidaOverride != null) {
      await debugSubidaOverride!(storagePath, bytes, contentType);
    } else {
      await FirebaseStorage.instance.ref(storagePath).putData(bytes, SettableMetadata(contentType: contentType));
    }

    final captura = Captura(
      id: docRef.id,
      proyectoId: proyectoId,
      pantallaClave: pantallaClave,
      storagePath: storagePath,
      orden: existentesSnap.docs.length,
      origen: OrigenCaptura.manual,
      subidaEn: DateTime.now(),
      hashContenido: hash,
      tamanioBytes: bytes.length,
      descripcion: descripcion,
    );
    await docRef.set(captura.toJson());
    return captura;
  }

  static Future<void> eliminar(String proyectoId, String capturaId) async {
    final uid = _uid;
    if (uid == null) throw StateError('CapturaService.eliminar: no hay sesión iniciada');
    final snap = await _coleccion(uid, proyectoId).doc(capturaId).get();
    if (!snap.exists) return;
    final storagePath = snap.data()?['storagePath'] as String? ?? '';

    if (storagePath.isNotEmpty) {
      try {
        if (debugEliminarArchivoOverride != null) {
          await debugEliminarArchivoOverride!(storagePath);
        } else {
          await FirebaseStorage.instance.ref(storagePath).delete();
        }
      } on FirebaseException catch (e) {
        // "El archivo ya no existe en Storage" nunca debe bloquear que se
        // borre su metadato -- si ya no está, el objetivo ya está cumplido.
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await _coleccion(uid, proyectoId).doc(capturaId).delete();
  }
}
