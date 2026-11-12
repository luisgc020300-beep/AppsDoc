// test/screens/proyecto_form_screen_test.dart
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/screens/proyectos/proyecto_form_screen.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un nombre vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const ProyectoFormScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Crear proyecto'));
    await tester.pump();

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(await ProyectoService.streamProyectos().first, isEmpty);
  });

  testWidgets('al editar, no aparece el botón de eliminar cuando es un alta nueva', (tester) async {
    await tester.pumpWidget(envolver(const ProyectoFormScreen()));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('elegir un estado distinto lo refleja seleccionado', (tester) async {
    await tester.pumpWidget(envolver(const ProyectoFormScreen()));
    await tester.pump();

    final chipLanzado = find.widgetWithText(ChoiceChip, 'Lanzado');
    await tester.tap(chipLanzado);
    await tester.pump();

    final chip = tester.widget<ChoiceChip>(chipLanzado);
    expect(chip.selected, true);
  });

  testWidgets('crear con nombre válido guarda con el estado "Idea" por defecto', (tester) async {
    await tester.pumpWidget(envolver(const ProyectoFormScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Nuevo proyecto de prueba');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear proyecto'));
    await tester.pumpAndSettle();

    final proyecto = (await ProyectoService.streamProyectos().first).single;
    expect(proyecto.nombre, 'Nuevo proyecto de prueba');
    expect(proyecto.estado, EstadoProyecto.idea);
  });
}
