// lib/services/expediente_service.dart
//
// Cliente de la Cloud Function generarExpediente (Fase 10) + persistencia de
// sus versiones en Firestore. Puramente documental: nunca escribe en
// funcionalidades/tareas/ideas/documentos/auditorias reales ni en
// Proyecto.progresoPorcentaje -- solo LEE ese progreso para guardarlo dentro
// de SeccionProgresoValor. Cada generación crea una versión nueva
// (numeroVersion correlativo); el contenido generado por IA es inmutable
// por versión, las correcciones manuales del usuario sobre una versión ya
// confirmada se hacen in-place con editarCampo().
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/estado_expediente.dart';
import '../models/expediente.dart';

class ExpedienteException implements Exception {
  ExpedienteException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class ExpedienteService {
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(Map<String, dynamic> datos)? debugCallableOverride;

  static const String _region = 'europe-west1';
  // generarExpediente puede tardar varios minutos (hasta 7 llamadas
  // secuenciales a Anthropic en el backend) -- el timeout por defecto de
  // cloud_functions (70s) no basta.
  static const Duration _timeout = Duration(seconds: 540);

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid =>
      debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('expedientes');

  static CollectionReference<Map<String, dynamic>> _pantallasCatalogo(String uid, String proyectoId) =>
      _db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).collection('pantallasCatalogo');

  static Future<Map<String, dynamic>> _llamar(Map<String, dynamic> datos) async {
    if (debugCallableOverride != null) return debugCallableOverride!(datos);
    final resultado = await FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('generarExpediente', options: HttpsCallableOptions(timeout: _timeout)).call<dynamic>(datos);
    return Map<String, dynamic>.from(resultado.data as Map);
  }

  static Stream<List<Expediente>> streamVersiones(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _coleccion(
      uid,
      proyectoId,
    ).orderBy('numeroVersion', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => Expediente.fromJson(d.id, proyectoId, d.data())).toList(),
    );
  }

  static Stream<Expediente?> streamActualConfirmado(String proyectoId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _coleccion(uid, proyectoId)
        .where('estado', isEqualTo: EstadoExpediente.confirmado.name)
        .orderBy('numeroVersion', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : Expediente.fromJson(snap.docs.first.id, proyectoId, snap.docs.first.data()));
  }

  /// Llama a generarExpediente, empareja cada pantalla detectada con
  /// pantallasCatalogo (para que las capturas sobrevivan a un reanálisis) y
  /// guarda el resultado como un nuevo borrador -- nunca sobrescribe una
  /// versión anterior.
  static Future<Expediente> generar({required String proyectoId}) async {
    final uid = _uid;
    if (uid == null) throw StateError('ExpedienteService.generar: no hay sesión iniciada');

    final Map<String, dynamic> resultado;
    try {
      resultado = await _llamar({'proyectoId': proyectoId});
    } on FirebaseFunctionsException catch (e) {
      throw ExpedienteException(_mensajeDeError(e));
    }

    final numeroVersion = await _siguienteNumeroVersion(uid, proyectoId);
    final borrador = Expediente.fromJson('', proyectoId, {...resultado, 'numeroVersion': numeroVersion});
    final pantallasEmparejadas = await _emparejarPantallas(uid, proyectoId, borrador.pantallas);
    final conClaves = borrador.copyWith(pantallas: pantallasEmparejadas);

    final ref = await _coleccion(uid, proyectoId).add(conClaves.toJson());
    return conClaves.copyWith(id: ref.id);
  }

  static Future<int> _siguienteNumeroVersion(String uid, String proyectoId) async {
    final snap = await _coleccion(uid, proyectoId).orderBy('numeroVersion', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return 1;
    final ultima = (snap.docs.first.data()['numeroVersion'] as num?)?.toInt() ?? 0;
    return ultima + 1;
  }

  /// Compara cada pantalla recién detectada contra pantallasCatalogo:
  /// archivoPrincipal exacto tiene prioridad sobre similitud de nombre
  /// normalizado; si hay coincidencia reutiliza su claveEstable, si no crea
  /// una entrada nueva. Así las Captura (que referencian claveEstable)
  /// sobreviven a que una pantalla cambie de nombre u orden entre análisis.
  static Future<List<PantallaExpediente>> _emparejarPantallas(
    String uid,
    String proyectoId,
    List<PantallaExpediente> detectadas,
  ) async {
    final catalogoSnap = await _pantallasCatalogo(uid, proyectoId).get();
    final catalogo = catalogoSnap.docs
        .map(
          (d) => (
            id: d.id,
            nombre: d.data()['nombreActual'] as String? ?? '',
            archivo: d.data()['archivoPrincipalActual'] as String? ?? '',
          ),
        )
        .toList();

    final resultado = <PantallaExpediente>[];
    for (final pantalla in detectadas) {
      String? claveEncontrada;
      if (pantalla.archivoPrincipal.isNotEmpty) {
        for (final c in catalogo) {
          if (c.archivo == pantalla.archivoPrincipal) {
            claveEncontrada = c.id;
            break;
          }
        }
      }
      if (claveEncontrada == null) {
        for (final c in catalogo) {
          if (_normalizarNombre(c.nombre) == _normalizarNombre(pantalla.nombre)) {
            claveEncontrada = c.id;
            break;
          }
        }
      }

      final ahora = Timestamp.now();
      if (claveEncontrada != null) {
        await _pantallasCatalogo(uid, proyectoId).doc(claveEncontrada).update({
          'nombreActual': pantalla.nombre,
          'archivoPrincipalActual': pantalla.archivoPrincipal,
          'actualizadoEn': ahora,
        });
        resultado.add(pantalla.copyWith(claveEstable: claveEncontrada));
      } else {
        final ref = await _pantallasCatalogo(uid, proyectoId).add({
          'nombreActual': pantalla.nombre,
          'archivoPrincipalActual': pantalla.archivoPrincipal,
          'creadoEn': ahora,
          'actualizadoEn': ahora,
        });
        resultado.add(pantalla.copyWith(claveEstable: ref.id));
      }
    }
    return resultado;
  }

  static String _normalizarNombre(String n) => n.trim().toLowerCase();

  static Future<void> confirmar(String proyectoId, String expedienteId) async {
    final uid = _uid;
    if (uid == null) throw StateError('ExpedienteService.confirmar: no hay sesión iniciada');
    final ahora = Timestamp.fromDate(DateTime.now());
    await _coleccion(
      uid,
      proyectoId,
    ).doc(expedienteId).update({'estado': EstadoExpediente.confirmado.name, 'confirmadoEn': ahora, 'updatedAt': ahora});
  }

  static Future<void> descartarBorrador(String proyectoId, String expedienteId) async {
    final uid = _uid;
    if (uid == null) throw StateError('ExpedienteService.descartarBorrador: no hay sesión iniciada');
    final snap = await _coleccion(uid, proyectoId).doc(expedienteId).get();
    if (!snap.exists) return;
    final estado = snap.data()?['estado'] as String?;
    if (estado != EstadoExpediente.borrador.name) {
      throw StateError('ExpedienteService.descartarBorrador: solo se puede descartar un borrador, no una versión confirmada');
    }
    await _coleccion(uid, proyectoId).doc(expedienteId).delete();
  }

  /// Corrige campos de una versión concreta in-place, sin generar una
  /// versión nueva ni tocar numeroVersion/estado -- sirve tanto durante la
  /// revisión de un borrador (antes de confirmar) como para corregir a mano
  /// una versión ya confirmada más tarde. El contenido generado por IA en sí
  /// es inmutable por versión (una regeneración siempre crea un borrador
  /// nuevo, nunca sobrescribe esta versión); esto es solo para que el
  /// usuario pueda arreglar un campo sin tener que volver a analizar.
  static Future<void> editarCampo(String proyectoId, String expedienteId, Map<String, dynamic> cambios) async {
    final uid = _uid;
    if (uid == null) throw StateError('ExpedienteService.editarCampo: no hay sesión iniciada');
    final snap = await _coleccion(uid, proyectoId).doc(expedienteId).get();
    if (!snap.exists) throw StateError('ExpedienteService.editarCampo: el expediente no existe');
    await _coleccion(uid, proyectoId).doc(expedienteId).update({...cambios, 'updatedAt': Timestamp.fromDate(DateTime.now())});
  }

  static String _mensajeDeError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return 'Has alcanzado el límite diario de peticiones a la IA, o GitHub ha limitado las peticiones. Inténtalo de nuevo más tarde.';
      case 'unauthenticated':
        return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
      case 'not-found':
        return 'No se encontró el proyecto.';
      case 'failed-precondition':
        return e.message ?? 'Este proyecto no tiene un repositorio de GitHub vinculado.';
      case 'invalid-argument':
        return e.message ?? 'Petición inválida.';
      case 'unavailable':
        return 'No se pudo contactar con el servicio de IA o con GitHub. Comprueba tu conexión.';
      default:
        return 'No se pudo generar el expediente. Inténtalo de nuevo.';
    }
  }
}
