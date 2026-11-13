// test/screens/galeria_capturas_screen_test.dart
//
// No se prueba aquí el flujo real de "elegir pantalla -> abrir el selector
// de imágenes del dispositivo" porque image_picker llama a un canal de
// plataforma nativo sin seam en este proyecto -- CapturaService.subir() ya
// está probado a fondo en captura_service_test.dart; lo que falta cubrir
// aquí es la pantalla en sí (estado vacío, agrupación por pantalla, borrado
// desde el visor) y el caso límite de pulsar "añadir" sin ninguna pantalla
// disponible (ese camino nunca llega a tocar image_picker).
import 'dart:typed_data';

import 'package:appsdoc/models/expediente.dart';
import 'package:appsdoc/screens/expediente/galeria_capturas_screen.dart';
import 'package:appsdoc/services/captura_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const proyectoId = 'p1';
  const pantallas = [
    PantallaExpediente(claveEstable: 'clave-1', nombre: 'Login', archivoPrincipal: '', descripcionFuncion: '', navegacion: ''),
  ];

  setUp(() {
    final db = FakeFirebaseFirestore();
    CapturaService.debugFirestoreOverride = db;
    CapturaService.debugUidOverride = 'uid-test';
    CapturaService.debugUrlDescargaOverride = (path) async => 'https://ejemplo.test/$path';
  });

  tearDown(() {
    CapturaService.debugFirestoreOverride = null;
    CapturaService.debugUidOverride = null;
    CapturaService.debugSubidaOverride = null;
    CapturaService.debugUrlDescargaOverride = null;
    CapturaService.debugEliminarArchivoOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('sin capturas todavía muestra el estado vacío', (tester) async {
    await tester.pumpWidget(envolver(const GaleriaCapturasScreen(proyectoId: proyectoId, pantallas: pantallas)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay ninguna captura'), findsOneWidget);
  });

  testWidgets('muestra las capturas agrupadas bajo el nombre de su pantalla', (tester) async {
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {};
    await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: Uint8List.fromList([1, 2, 3]));

    await tester.pumpWidget(envolver(const GaleriaCapturasScreen(proyectoId: proyectoId, pantallas: pantallas)));
    await tester.pumpAndSettle();
    // La miniatura intenta cargar la URL de verdad por red -- en el entorno
    // de test eso falla y Image.network ya lo cubre con su propio
    // errorBuilder, pero el intento en sí queda registrado como una
    // excepción pendiente si no se consume explícitamente.
    tester.takeException();

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('una captura de una pantalla que ya no está en el expediente actual se etiqueta como eliminada', (tester) async {
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {};
    await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-huerfana', bytes: Uint8List.fromList([1, 2, 3]));

    await tester.pumpWidget(envolver(const GaleriaCapturasScreen(proyectoId: proyectoId, pantallas: pantallas)));
    await tester.pumpAndSettle();
    tester.takeException(); // ver comentario en el test anterior

    expect(find.textContaining('eliminada del expediente'), findsOneWidget);
  });

  testWidgets('abrir el visor y eliminar quita la captura de la galería', (tester) async {
    CapturaService.debugSubidaOverride = (storagePath, bytes, contentType) async {};
    await CapturaService.subir(proyectoId: proyectoId, pantallaClave: 'clave-1', bytes: Uint8List.fromList([1, 2, 3]));
    final borrados = <String>[];
    CapturaService.debugEliminarArchivoOverride = (storagePath) async => borrados.add(storagePath);

    await tester.pumpWidget(envolver(const GaleriaCapturasScreen(proyectoId: proyectoId, pantallas: pantallas)));
    await tester.pumpAndSettle();
    tester.takeException(); // ver comentario en el primer test de esta pantalla

    await tester.tap(find.byType(ClipRRect));
    await tester.pumpAndSettle();
    tester.takeException(); // el visor también intenta cargar la imagen por red
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // El icono de borrar cierra el visor y dispara el diálogo de
    // confirmación -- hace falta confirmarlo para que se elimine de verdad.
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(borrados, hasLength(1));
    expect(find.textContaining('Todavía no hay ninguna captura'), findsOneWidget);
  });

  testWidgets('sin ninguna pantalla disponible, pulsar "añadir" muestra un error sin abrir el selector de imágenes', (tester) async {
    await tester.pumpWidget(envolver(const GaleriaCapturasScreen(proyectoId: proyectoId, pantallas: [])));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('no tiene pantallas detectadas'), findsOneWidget);
  });
}
