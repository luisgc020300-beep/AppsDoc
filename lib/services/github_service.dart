// lib/services/github_service.dart
//
// Solo lectura, sin ningún token: la API pública de GitHub permite leer
// repos públicos sin autenticar (limitada a 60 peticiones/hora por IP,
// suficiente para un uso personal). Un repositorio privado o inexistente
// se ve igual desde fuera (GitHub no distingue para no filtrar su
// existencia) -- de ahí RepositorioNoEncontradoOPrivadoException.
//
// Si en el futuro hiciera falta autenticarse (repos privados reales,
// límite de peticiones más alto, webhooks), el token vive en Firebase
// Secret Manager y esta clase pasa a llamar a una Cloud Function callable
// en vez de a api.github.com directamente -- nunca un token de GitHub en
// el cliente. Mismo patrón que la clave de Anthropic en RiskRunner/REPARA.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/github_repo_info.dart';

/// La URL no tiene forma de repositorio de GitHub (host distinto o le
/// faltan propietario/nombre).
class UrlRepositorioInvalidaException implements Exception {
  @override
  String toString() => 'La URL no parece la de un repositorio de GitHub.';
}

/// GitHub no distingue "no existe" de "existe pero es privado" para una
/// petición sin autenticar -- ambos devuelven 404.
class RepositorioNoEncontradoOPrivadoException implements Exception {
  @override
  String toString() => 'El repositorio no existe o es privado.';
}

/// Límite de peticiones sin autenticar agotado (60/hora por IP).
class LimiteDePeticionesGithubException implements Exception {
  @override
  String toString() => 'Límite de peticiones a GitHub alcanzado. Inténtalo más tarde.';
}

/// Cualquier otro fallo de red o respuesta inesperada de la API.
class GithubApiException implements Exception {
  GithubApiException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class GithubService {
  @visibleForTesting
  static http.Client? debugHttpClientOverride;

  static http.Client get _client => debugHttpClientOverride ?? http.Client();

  /// Acepta `https://github.com/propietario/repo`, con o sin `.git` y con
  /// o sin barra final. Lanza [UrlRepositorioInvalidaException] para
  /// cualquier otra cosa -- nunca devuelve un resultado parcial.
  static ({String propietario, String nombre}) parseRepoUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.host.toLowerCase().endsWith('github.com')) {
      throw UrlRepositorioInvalidaException();
    }
    final segmentos = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segmentos.length < 2) throw UrlRepositorioInvalidaException();

    final propietario = segmentos[0];
    var nombre = segmentos[1];
    if (nombre.endsWith('.git')) nombre = nombre.substring(0, nombre.length - 4);
    if (propietario.isEmpty || nombre.isEmpty) throw UrlRepositorioInvalidaException();

    return (propietario: propietario, nombre: nombre);
  }

  /// Rama principal, mensaje y fecha del último commit en esa rama, y
  /// fecha de última actualización del repo. Pensado para ampliarse con
  /// consultas de commits/cambios recientes sin tocar esta firma (misma
  /// pareja propietario/nombre ya validada).
  static Future<GithubRepoInfo> obtenerResumenRepo({required String propietario, required String nombre}) async {
    final repoJson = await _obtenerJson('/repos/$propietario/$nombre');

    final ramaPrincipal = repoJson['default_branch'] as String? ?? 'main';
    final actualizadoEn = DateTime.parse(repoJson['updated_at'] as String).toLocal();

    final commitJson = await _obtenerJson('/repos/$propietario/$nombre/commits/$ramaPrincipal');
    final commit = commitJson['commit'] as Map<String, dynamic>;
    final mensajeCompleto = commit['message'] as String? ?? '';
    final autor = commit['committer'] as Map<String, dynamic>? ?? commit['author'] as Map<String, dynamic>?;
    final fechaCommit = DateTime.parse(autor!['date'] as String).toLocal();

    return GithubRepoInfo(
      propietario: propietario,
      nombre: nombre,
      ramaPrincipal: ramaPrincipal,
      ultimoCommitMensaje: mensajeCompleto.split('\n').first,
      ultimoCommitFecha: fechaCommit,
      actualizadoEn: actualizadoEn,
    );
  }

  static Future<Map<String, dynamic>> _obtenerJson(String ruta) async {
    final http.Response respuesta;
    try {
      respuesta = await _client.get(
        Uri.https('api.github.com', ruta),
        headers: const {'Accept': 'application/vnd.github+json'},
      );
    } catch (_) {
      throw GithubApiException('No se pudo conectar con GitHub. Comprueba tu conexión.');
    }

    switch (respuesta.statusCode) {
      case 200:
        return jsonDecode(respuesta.body) as Map<String, dynamic>;
      case 404:
        throw RepositorioNoEncontradoOPrivadoException();
      case 403:
        if (respuesta.headers['x-ratelimit-remaining'] == '0') {
          throw LimiteDePeticionesGithubException();
        }
        throw GithubApiException('GitHub rechazó la petición (403).');
      default:
        throw GithubApiException('GitHub devolvió un error inesperado (${respuesta.statusCode}).');
    }
  }
}
