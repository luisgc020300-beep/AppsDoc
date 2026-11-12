// test/services/ai_assistant_service_test.dart
import 'package:appsdoc/models/github_repo_info.dart';
import 'package:appsdoc/services/ai_assistant_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AiAssistantService.debugCallableOverride = null;
  });

  group('preguntar()', () {
    test('devuelve la respuesta que da la función', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        expect(nombre, 'preguntarAsistente');
        expect(datos['proyectoId'], 'p1');
        expect(datos['pregunta'], '¿Qué falta para publicar?');
        expect(datos.containsKey('githubResumen'), false);
        return {'respuesta': 'Te falta documentación de arquitectura.'};
      };

      final respuesta = await AiAssistantService.preguntar(proyectoId: 'p1', pregunta: '¿Qué falta para publicar?');

      expect(respuesta, 'Te falta documentación de arquitectura.');
    });

    test('incluye el resumen de GitHub cuando se proporciona', () async {
      Map<String, dynamic>? datosRecibidos;
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        datosRecibidos = datos;
        return {'respuesta': 'ok'};
      };

      await AiAssistantService.preguntar(
        proyectoId: 'p1',
        pregunta: 'x',
        githubResumen: GithubRepoInfo(
          propietario: 'owner',
          nombre: 'repo',
          ramaPrincipal: 'main',
          ultimoCommitMensaje: 'fix: x',
          ultimoCommitFecha: DateTime.utc(2026, 11, 10, 8, 30),
          actualizadoEn: DateTime.utc(2026, 11, 1, 10),
        ),
      );

      expect(datosRecibidos!['githubResumen'], {
        'ramaPrincipal': 'main',
        'ultimoCommitMensaje': 'fix: x',
        'ultimoCommitFecha': '2026-11-10T08:30:00.000Z',
        'actualizadoEn': '2026-11-01T10:00:00.000Z',
      });
    });

    test('un FirebaseFunctionsException resource-exhausted se traduce a un mensaje en español', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        throw FirebaseFunctionsException(code: 'resource-exhausted', message: 'x');
      };

      await expectLater(
        AiAssistantService.preguntar(proyectoId: 'p1', pregunta: 'x'),
        throwsA(isA<AiAssistantException>().having((e) => e.mensaje, 'mensaje', contains('límite diario'))),
      );
    });

    test('un FirebaseFunctionsException not-found se traduce a un mensaje en español', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        throw FirebaseFunctionsException(code: 'not-found', message: 'x');
      };

      await expectLater(
        AiAssistantService.preguntar(proyectoId: 'p1', pregunta: 'x'),
        throwsA(isA<AiAssistantException>().having((e) => e.mensaje, 'mensaje', contains('proyecto'))),
      );
    });

    test('un código desconocido cae a un mensaje genérico, nunca deja escapar la excepción original', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        throw FirebaseFunctionsException(code: 'internal', message: 'detalle interno que no debe mostrarse tal cual');
      };

      await expectLater(AiAssistantService.preguntar(proyectoId: 'p1', pregunta: 'x'), throwsA(isA<AiAssistantException>()));
    });
  });

  group('extraerAuditoria()', () {
    test('convierte la respuesta en una PropuestaAuditoria', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        expect(nombre, 'extraerAuditoria');
        expect(datos['proyectoId'], 'p1');
        expect(datos['texto'], 'texto pegado');
        return {
          'resumen': 'Resumen de la auditoría',
          'hallazgos': [
            {'titulo': 'Falta rate limit', 'descripcion': 'En X', 'gravedad': 'alta'},
          ],
          'tareas': [
            {'titulo': 'Añadir rate limit', 'descripcion': ''},
          ],
        };
      };

      final propuesta = await AiAssistantService.extraerAuditoria(proyectoId: 'p1', texto: 'texto pegado');

      expect(propuesta.resumen, 'Resumen de la auditoría');
      expect(propuesta.hallazgos, hasLength(1));
      expect(propuesta.hallazgos.single.titulo, 'Falta rate limit');
      expect(propuesta.tareas, hasLength(1));
      expect(propuesta.tareas.single.titulo, 'Añadir rate limit');
    });

    test('un error de la función se traduce igual que en preguntar()', () async {
      AiAssistantService.debugCallableOverride = (nombre, datos) async {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: 'x');
      };

      await expectLater(
        AiAssistantService.extraerAuditoria(proyectoId: 'p1', texto: 'x'),
        throwsA(isA<AiAssistantException>().having((e) => e.mensaje, 'mensaje', contains('sesión'))),
      );
    });
  });
}
