// test/screens/idea_form_screen_test.dart
import 'package:appsdoc/models/estado_idea.dart';
import 'package:appsdoc/screens/ideas/idea_form_screen.dart';
import 'package:appsdoc/services/idea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    IdeaService.debugFirestoreOverride = FakeFirebaseFirestore();
    IdeaService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    IdeaService.debugFirestoreOverride = null;
    IdeaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un título vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const IdeaFormScreen(proyectoId: 'p1')));

    await tester.tap(find.widgetWithText(FilledButton, 'Crear idea'));
    await tester.pump();

    expect(find.text('El título es obligatorio'), findsOneWidget);
    expect(await IdeaService.streamIdeas('p1').first, isEmpty);
  });

  testWidgets('crear con título válido guarda con el estado "Nueva" por defecto y respeta las notas', (tester) async {
    await tester.pumpWidget(envolver(const IdeaFormScreen(proyectoId: 'p1')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Soporte offline');
    await tester.enterText(find.widgetWithText(TextFormField, 'Notas'), 'mirar sync al reconectar');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear idea'));
    await tester.pumpAndSettle();

    final i = (await IdeaService.streamIdeas('p1').first).single;
    expect(i.titulo, 'Soporte offline');
    expect(i.notas, 'mirar sync al reconectar');
    expect(i.estado, EstadoIdea.nueva);
  });

  testWidgets('editar una idea existente precarga sus datos y permite eliminarla', (tester) async {
    await IdeaService.crear(proyectoId: 'p1', titulo: 'A editar', estado: EstadoIdea.evaluando);
    final existente = (await IdeaService.streamIdeas('p1').first).single;

    await tester.pumpWidget(envolver(IdeaFormScreen(proyectoId: 'p1', ideaExistente: existente)));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'A editar'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Evaluando')).selected, true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await IdeaService.streamIdeas('p1').first, isEmpty);
  });
}
