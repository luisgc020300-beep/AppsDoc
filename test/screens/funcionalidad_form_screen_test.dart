// test/screens/funcionalidad_form_screen_test.dart
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/screens/funcionalidades/funcionalidad_form_screen.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FuncionalidadService.debugFirestoreOverride = FakeFirebaseFirestore();
    FuncionalidadService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un nombre vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const FuncionalidadFormScreen(proyectoId: 'p1')));

    await tester.tap(find.widgetWithText(FilledButton, 'Crear funcionalidad'));
    await tester.pump();

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(await FuncionalidadService.streamFuncionalidades('p1').first, isEmpty);
  });

  testWidgets('al crear una nueva, no aparece el botón de eliminar', (tester) async {
    await tester.pumpWidget(envolver(const FuncionalidadFormScreen(proyectoId: 'p1')));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('crear con nombre válido guarda con el estado "Planificada" por defecto y respeta las notas', (tester) async {
    await tester.pumpWidget(envolver(const FuncionalidadFormScreen(proyectoId: 'p1')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Exportar PDF');
    await tester.enterText(find.widgetWithText(TextFormField, 'Notas'), 'pedir librería de PDF');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear funcionalidad'));
    await tester.pumpAndSettle();

    final f = (await FuncionalidadService.streamFuncionalidades('p1').first).single;
    expect(f.nombre, 'Exportar PDF');
    expect(f.notas, 'pedir librería de PDF');
    expect(f.estado, EstadoFuncionalidad.planificada);
  });

  testWidgets('editar una funcionalidad existente precarga sus datos y permite eliminarla', (tester) async {
    final id = await FuncionalidadService.crear(proyectoId: 'p1', nombre: 'A editar', notas: 'nota vieja');
    final existente = (await FuncionalidadService.streamFuncionalidades('p1').first).single;
    expect(existente.id, id);

    await tester.pumpWidget(envolver(FuncionalidadFormScreen(proyectoId: 'p1', funcionalidadExistente: existente)));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'A editar'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'nota vieja'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await FuncionalidadService.streamFuncionalidades('p1').first, isEmpty);
  });
}
