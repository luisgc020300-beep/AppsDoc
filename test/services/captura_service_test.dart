// test/services/captura_service_test.dart
import 'dart:typed_data';

import 'package:appsdoc/services/captura_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';
  final bytesA = Uint8List.fromList([1, 2, 3]);
  final bytesB = Uint8List.fromList([4, 5, 6]);

  setUp(() {
    db = FakeFirebaseFirestore();
    CapturaService.debugFirestoreOverride = db;
    CapturaService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    CapturaService.debugFirestoreOverride = null;
    CapturaService.debugUidOverride = null;
    CapturaService.debugSubidaOverride = null;
    CapturaService.debugUrlDescargaOverride = null;
    CapturaService.debugEliminarArchivoOverride = null;
  });

  test('subir() guarda los metadatos y sube el binario a través del seam', () async {
    final subidas = <String>[];
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {
      subidas.add(storagePath);
      expect(contentType, 'image/jpg');
    };

    final captura = await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA);

    expect(subidas, hasLength(1));
    expect(captura.pantallaClave, 'clave-1');
    expect(captura.storagePath, contains('capturas/uid-1/p1/clave-1/'));
    expect(captura.orden, 0);
    expect(captura.tamanioBytes, bytesA.length);

    final lista = await CapturaService.streamCapturas(proyectoId).first;
    expect(lista, hasLength(1));
    expect(lista.single.id, captura.id);
  });

  test('subir() la misma imagen (mismo hash) a la misma pantalla no vuelve a subir ni duplica metadatos', () async {
    var llamadasSubida = 0;
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async => llamadasSubida++;

    final primera = await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA);
    final segunda = await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA);

    expect(llamadasSubida, 1);
    expect(segunda.id, primera.id);
    expect(await CapturaService.streamCapturas(proyectoId).first, hasLength(1));
  });

  test('subir() una imagen distinta a la misma pantalla crea una segunda captura con orden 1', () async {
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {};

    await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA);
    final segunda = await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesB);

    expect(segunda.orden, 1);
    expect(await CapturaService.streamCapturas(proyectoId).first, hasLength(2));
  });

  test('subir() con pantallaClave vacía lanza y no sube nada', () async {
    var llamado = false;
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async => llamado = true;

    await expectLater(
      CapturaService.subir(proyectoId: proyectoId, pantallaClave: '', bytes: bytesA),
      throwsArgumentError,
    );
    expect(llamado, false);
  });

  test('eliminar() borra el archivo a través del seam y quita los metadatos', () async {
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {};
    final captura = await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA);
    final borrados = <String>[];
    CapturaService.debugEliminarArchivoOverride = (storagePath) async => borrados.add(storagePath);

    await CapturaService.eliminar(proyectoId, captura.id);

    expect(borrados, [captura.storagePath]);
    expect(await CapturaService.streamCapturas(proyectoId).first, isEmpty);
  });

  test('eliminar() sobre una captura inexistente no lanza y no llama al seam de borrado', () async {
    var llamado = false;
    CapturaService.debugEliminarArchivoOverride = (storagePath) async => llamado = true;

    await CapturaService.eliminar(proyectoId, 'no-existe');

    expect(llamado, false);
  });

  test('obtenerUrl() delega en el seam de test', () async {
    CapturaService.debugUrlDescargaOverride = (storagePath) async => 'https://ejemplo.test/$storagePath';

    final url = await CapturaService.obtenerUrl('capturas/uid-1/p1/clave-1/c1.jpg');

    expect(url, 'https://ejemplo.test/capturas/uid-1/p1/clave-1/c1.jpg');
  });

  test('sin sesión (uid null), streamCapturas() devuelve vacío y subir() lanza', () async {
    CapturaService.debugUidOverride = null;

    expect(await CapturaService.streamCapturas(proyectoId).first, isEmpty);
    await expectLater(
      CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: bytesA),
      throwsStateError,
    );
  });
}
