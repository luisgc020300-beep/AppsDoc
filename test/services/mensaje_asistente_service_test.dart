// test/services/mensaje_asistente_service_test.dart
import 'package:appsdoc/services/mensaje_asistente_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    MensajeAsistenteService.debugFirestoreOverride = db;
    MensajeAsistenteService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    MensajeAsistenteService.debugFirestoreOverride = null;
    MensajeAsistenteService.debugUidOverride = null;
  });

  test('agregar() guarda el mensaje y streamMensajes() lo devuelve en orden cronológico', () async {
    await MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: '¿Qué falta?', esUsuario: true);
    await MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: 'Te falta X', esUsuario: false);

    final mensajes = await MensajeAsistenteService.streamMensajes(proyectoId).first;

    expect(mensajes, hasLength(2));
    expect(mensajes[0].texto, '¿Qué falta?');
    expect(mensajes[0].esUsuario, true);
    expect(mensajes[1].texto, 'Te falta X');
    expect(mensajes[1].esUsuario, false);
  });

  test('agregar() con esError marca el mensaje como error', () async {
    await MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: 'Fallo', esUsuario: false, esError: true);

    final mensajes = await MensajeAsistenteService.streamMensajes(proyectoId).first;

    expect(mensajes.single.esError, true);
  });

  test('agregar() con texto vacío falla y no escribe nada', () async {
    await expectLater(
      MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: '   ', esUsuario: true),
      throwsArgumentError,
    );
    expect(await MensajeAsistenteService.streamMensajes(proyectoId).first, isEmpty);
  });

  test('limpiar() borra todo el historial de ese proyecto, sin tocar el de otros', () async {
    await MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: 'Uno', esUsuario: true);
    await MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: 'Dos', esUsuario: false);
    await MensajeAsistenteService.agregar(proyectoId: 'p2', texto: 'De otro proyecto', esUsuario: true);

    await MensajeAsistenteService.limpiar(proyectoId);

    expect(await MensajeAsistenteService.streamMensajes(proyectoId).first, isEmpty);
    expect(await MensajeAsistenteService.streamMensajes('p2').first, hasLength(1));
  });

  test('limpiar() sin mensajes no lanza', () async {
    await MensajeAsistenteService.limpiar(proyectoId);
    expect(await MensajeAsistenteService.streamMensajes(proyectoId).first, isEmpty);
  });

  test('sin sesión (uid null), streamMensajes() devuelve vacío y agregar()/limpiar() lanzan', () async {
    MensajeAsistenteService.debugUidOverride = null;

    expect(await MensajeAsistenteService.streamMensajes(proyectoId).first, isEmpty);
    await expectLater(
      MensajeAsistenteService.agregar(proyectoId: proyectoId, texto: 'x', esUsuario: true),
      throwsStateError,
    );
    await expectLater(MensajeAsistenteService.limpiar(proyectoId), throwsStateError);
  });
}
