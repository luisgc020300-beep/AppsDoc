// test/screens/asistente_screen_test.dart
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/screens/asistente/asistente_screen.dart';
import 'package:appsdoc/screens/asistente/pegar_auditoria_screen.dart';
import 'package:appsdoc/services/ai_assistant_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Proyecto _proyecto() {
  final ahora = DateTime(2026, 11, 12);
  return Proyecto(id: 'p1', nombre: 'REPARA', estado: EstadoProyecto.enDesarrollo, createdAt: ahora, updatedAt: ahora);
}

void main() {
  tearDown(() {
    AiAssistantService.debugCallableOverride = null;
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
}
