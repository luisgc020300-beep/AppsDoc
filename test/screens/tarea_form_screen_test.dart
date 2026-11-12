// test/screens/tarea_form_screen_test.dart
import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/models/prioridad_tarea.dart';
import 'package:appsdoc/screens/tareas/tarea_form_screen.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TareaService.debugFirestoreOverride = FakeFirebaseFirestore();
    TareaService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un título vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const TareaFormScreen(proyectoId: 'p1')));

    // El formulario de tarea es más largo que los demás (estado + prioridad
    // + fecha) -- el botón queda fuera del viewport por defecto del test.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pump();

    expect(find.text('El título es obligatorio'), findsOneWidget);
    expect(await TareaService.streamTareas('p1').first, isEmpty);
  });

  testWidgets('elegir prioridad y estado distintos los refleja seleccionados', (tester) async {
    await tester.pumpWidget(envolver(const TareaFormScreen(proyectoId: 'p1')));
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Alta'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completada'));
    await tester.pump();

    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Alta')).selected, true);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completada')).selected, true);
  });

  testWidgets('sin fecha límite elegida, muestra "Sin fecha"', (tester) async {
    await tester.pumpWidget(envolver(const TareaFormScreen(proyectoId: 'p1')));
    await tester.pump();

    expect(find.text('Sin fecha'), findsOneWidget);
  });

  testWidgets('crear con título válido guarda con prioridad "Media" y estado "Pendiente" por defecto', (tester) async {
    await tester.pumpWidget(envolver(const TareaFormScreen(proyectoId: 'p1')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Desplegar reglas');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pumpAndSettle();

    final t = (await TareaService.streamTareas('p1').first).single;
    expect(t.titulo, 'Desplegar reglas');
    expect(t.prioridad, PrioridadTarea.media);
    expect(t.estado, EstadoTarea.pendiente);
    expect(t.fechaLimite, isNull);
  });

  testWidgets('editar una tarea existente precarga sus datos y permite eliminarla', (tester) async {
    await TareaService.crear(proyectoId: 'p1', titulo: 'A editar', prioridad: PrioridadTarea.alta);
    final existente = (await TareaService.streamTareas('p1').first).single;

    await tester.pumpWidget(envolver(TareaFormScreen(proyectoId: 'p1', tareaExistente: existente)));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'A editar'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Alta')).selected, true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await TareaService.streamTareas('p1').first, isEmpty);
  });
}
