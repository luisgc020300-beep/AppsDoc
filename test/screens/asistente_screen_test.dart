// test/screens/asistente_screen_test.dart
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/screens/asistente/asistente_screen.dart';
import 'package:appsdoc/screens/asistente/pegar_auditoria_screen.dart';
import 'package:appsdoc/services/ai_assistant_service.dart';
import 'package:appsdoc/services/mensaje_asistente_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto() {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: 'p1', nombre: 'REPARA', estado: EstadoProyecto.enDesarrollo, createdAt: ahora, updatedAt: ahora);
}

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    MensajeAsistenteService.debugFirestoreOverride = db;
    MensajeAsistenteService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    AiAssistantService.debugCallableOverride = null;
    MensajeAsistenteService.debugFirestoreOverride = null;
    MensajeAsistenteService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('estado vacío muestra preguntas sugeridas; tocar una la envía y muestra la respuesta', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      expect(datos['pregunta'], '¿Qué falta para publicar?');
      return {'respuesta': 'Te falta documentación de arquitectura.'};
    };

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué falta para publicar?'), findsOneWidget);

    await tester.tap(find.text('¿Qué falta para publicar?'));
    await tester.pumpAndSettle();

    expect(find.text('Te falta documentación de arquitectura.'), findsOneWidget);
  });

  testWidgets('escribir y enviar una pregunta muestra la respuesta del asistente', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => {'respuesta': 'Respuesta de prueba'};

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '¿Por dónde iba?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Por dónde iba?'), findsOneWidget);
    expect(find.text('Respuesta de prueba'), findsOneWidget);
  });

  testWidgets('un error de la IA se muestra como mensaje dentro del propio chat', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      throw FirebaseFunctionsException(code: 'resource-exhausted', message: 'x');
    };

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '¿Qué debería hacer ahora?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('límite diario'), findsOneWidget);
  });

  testWidgets('el icono de pegar auditoría abre la pantalla de pegar auditoría', (tester) async {
    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pegar auditoría'));
    await tester.pumpAndSettle();

    expect(find.byType(PegarAuditoriaScreen), findsOneWidget);
  });

  testWidgets('el historial sobrevive a salir y volver a entrar en la pantalla', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => {'respuesta': 'Respuesta de prueba'};

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '¿Por dónde iba?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    // "Salir y volver a entrar" = una instancia nueva de la pantalla, no la
    // misma -- el estado en memoria de la anterior ya no existe.
    await tester.pumpWidget(envolver(const SizedBox()));
    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();

    expect(find.text('¿Por dónde iba?'), findsOneWidget);
    expect(find.text('Respuesta de prueba'), findsOneWidget);
  });

  testWidgets('"Nueva conversación" borra el historial tras confirmar', (tester) async {
    // Pregunta deliberadamente distinta de las sugerencias del estado vacío
    // (_preguntasSugeridas incluye "¿Por dónde iba?") -- si no, al volver al
    // estado vacío tras limpiar, el texto "reaparecería" como chip de
    // sugerencia y el test daría un falso negativo.
    AiAssistantService.debugCallableOverride = (nombre, datos) async => {'respuesta': 'Respuesta de prueba'};

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pregunta de prueba única');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva conversación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Empezar de nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta de prueba única'), findsNothing);
    expect(find.text('Respuesta de prueba'), findsNothing);
    expect(find.text('Pregúntale al asistente sobre este proyecto'), findsOneWidget);
  });

  testWidgets('"Nueva conversación" sin confirmar conserva el historial', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => {'respuesta': 'Respuesta de prueba'};

    await tester.pumpWidget(envolver(AsistenteScreen(proyecto: _proyecto())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '¿Por dónde iba?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva conversación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Por dónde iba?'), findsOneWidget);
  });
}
