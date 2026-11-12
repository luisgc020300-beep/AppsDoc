// lib/services/ai_assistant_service.dart
//
// Cliente de las dos Cloud Functions callable de la Fase 7
// (preguntarAsistente/extraerAuditoria, en functions/index.js). La clave
// de Anthropic nunca llega aquí -- vive solo en Secret Manager, accedida
// exclusivamente desde el backend.
//
// Ninguno de los dos métodos escribe nada: preguntar() solo devuelve
// texto, y extraerAuditoria() solo devuelve una propuesta. Guardar algo a
// partir de esa propuesta es decisión explícita del usuario, con los
// servicios ya existentes (AuditoriaService/TareaService).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/github_repo_info.dart';
import '../models/propuesta_auditoria.dart';

class AiAssistantException implements Exception {
  AiAssistantException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class AiAssistantService {
  /// Seam de solo test -- sustituye la llamada real a Cloud Functions por
  /// una función en memoria, para poder simular respuestas y errores sin
  /// Firebase real. Mismo criterio que debugFirestoreOverride en el resto
  /// de servicios.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(String nombre, Map<String, dynamic> datos)? debugCallableOverride;

  static const String _region = 'europe-west1';

  static Future<Map<String, dynamic>> _llamar(String nombre, Map<String, dynamic> datos) async {
    if (debugCallableOverride != null) return debugCallableOverride!(nombre, datos);
    final resultado = await FirebaseFunctions.instanceFor(region: _region).httpsCallable(nombre).call<dynamic>(datos);
    return Map<String, dynamic>.from(resultado.data as Map);
  }

  static Future<String> preguntar({
    required String proyectoId,
    required String pregunta,
    GithubRepoInfo? githubResumen,
  }) async {
    try {
      final datos = await _llamar('preguntarAsistente', {
        'proyectoId': proyectoId,
        'pregunta': pregunta,
        if (githubResumen != null)
          'githubResumen': {
            'ramaPrincipal': githubResumen.ramaPrincipal,
            'ultimoCommitMensaje': githubResumen.ultimoCommitMensaje,
            'ultimoCommitFecha': githubResumen.ultimoCommitFecha.toIso8601String(),
            'actualizadoEn': githubResumen.actualizadoEn.toIso8601String(),
          },
      });
      return datos['respuesta'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw AiAssistantException(_mensajeDeError(e));
    }
  }

  static Future<PropuestaAuditoria> extraerAuditoria({required String proyectoId, required String texto}) async {
    try {
      final datos = await _llamar('extraerAuditoria', {'proyectoId': proyectoId, 'texto': texto});
      return PropuestaAuditoria.fromJson(datos);
    } on FirebaseFunctionsException catch (e) {
      throw AiAssistantException(_mensajeDeError(e));
    }
  }

  static String _mensajeDeError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return 'Has alcanzado el límite diario de peticiones a la IA. Inténtalo de nuevo mañana.';
      case 'unauthenticated':
        return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
      case 'not-found':
        return 'No se encontró el proyecto.';
      case 'invalid-argument':
        return e.message ?? 'Petición inválida.';
      case 'unavailable':
        return 'No se pudo contactar con el servicio de IA. Comprueba tu conexión.';
      default:
        return 'No se pudo completar la petición a la IA. Inténtalo de nuevo.';
    }
  }
}
