// test/services/github_service_test.dart
import 'dart:convert';

import 'package:appsdoc/services/github_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    GithubService.debugHttpClientOverride = null;
  });

  group('parseRepoUrl()', () {
    test('acepta una URL normal de GitHub', () {
      final r = GithubService.parseRepoUrl('https://github.com/luisgc020300-beep/AppsDoc');
      expect(r.propietario, 'luisgc020300-beep');
      expect(r.nombre, 'AppsDoc');
    });

    test('quita el sufijo .git', () {
      final r = GithubService.parseRepoUrl('https://github.com/owner/repo.git');
      expect(r.nombre, 'repo');
    });

    test('ignora la barra final', () {
      final r = GithubService.parseRepoUrl('https://github.com/owner/repo/');
      expect(r.propietario, 'owner');
      expect(r.nombre, 'repo');
    });

    test('ignora espacios sueltos alrededor', () {
      final r = GithubService.parseRepoUrl('  https://github.com/owner/repo  ');
      expect(r.propietario, 'owner');
      expect(r.nombre, 'repo');
    });

    test('rechaza una URL de otro host', () {
      expect(() => GithubService.parseRepoUrl('https://gitlab.com/owner/repo'), throwsA(isA<UrlRepositorioInvalidaException>()));
    });

    test('rechaza una URL sin propietario/nombre', () {
      expect(() => GithubService.parseRepoUrl('https://github.com/owner'), throwsA(isA<UrlRepositorioInvalidaException>()));
    });

    test('rechaza texto que no es una URL', () {
      expect(() => GithubService.parseRepoUrl('no es una url'), throwsA(isA<UrlRepositorioInvalidaException>()));
    });
  });

  group('obtenerResumenRepo()', () {
    test('devuelve rama principal, último commit y fecha de actualización', () async {
      GithubService.debugHttpClientOverride = MockClient((request) async {
        if (request.url.path == '/repos/owner/repo') {
          return http.Response(
            jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}),
            200,
          );
        }
        if (request.url.path == '/repos/owner/repo/commits/main') {
          return http.Response(
            jsonEncode({
              'commit': {
                'message': 'fix: progreso real\n\nDetalle largo que no debe aparecer',
                'committer': {'date': '2026-11-10T08:30:00Z'},
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final info = await GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo');

      expect(info.propietario, 'owner');
      expect(info.nombre, 'repo');
      expect(info.ramaPrincipal, 'main');
      expect(info.ultimoCommitMensaje, 'fix: progreso real', reason: 'solo la primera línea del mensaje');
      expect(info.ultimoCommitFecha, DateTime.parse('2026-11-10T08:30:00Z').toLocal());
      expect(info.actualizadoEn, DateTime.parse('2026-11-01T10:00:00Z').toLocal());
    });

    test('repo inexistente o privado (404) lanza RepositorioNoEncontradoOPrivadoException', () async {
      GithubService.debugHttpClientOverride = MockClient((request) async => http.Response('not found', 404));

      await expectLater(
        GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo'),
        throwsA(isA<RepositorioNoEncontradoOPrivadoException>()),
      );
    });

    test('403 con límite de peticiones agotado lanza LimiteDePeticionesGithubException', () async {
      GithubService.debugHttpClientOverride = MockClient(
        (request) async => http.Response('rate limited', 403, headers: {'x-ratelimit-remaining': '0'}),
      );

      await expectLater(
        GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo'),
        throwsA(isA<LimiteDePeticionesGithubException>()),
      );
    });

    test('403 sin cabecera de límite lanza GithubApiException genérica', () async {
      GithubService.debugHttpClientOverride = MockClient((request) async => http.Response('forbidden', 403));

      await expectLater(
        GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo'),
        throwsA(isA<GithubApiException>()),
      );
    });

    test('un código de estado inesperado lanza GithubApiException', () async {
      GithubService.debugHttpClientOverride = MockClient((request) async => http.Response('boom', 500));

      await expectLater(
        GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo'),
        throwsA(isA<GithubApiException>()),
      );
    });

    test('un fallo de red lanza GithubApiException en vez de dejar escapar la excepción original', () async {
      GithubService.debugHttpClientOverride = MockClient((request) async => throw const SocketExceptionFake());

      await expectLater(
        GithubService.obtenerResumenRepo(propietario: 'owner', nombre: 'repo'),
        throwsA(isA<GithubApiException>()),
      );
    });
  });
}

/// Representa cualquier fallo de red real (SocketException, TimeoutException,
/// etc.) sin depender de dart:io en un test que también corre en web.
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
}
