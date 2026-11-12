// test/screens/proyectos_list_screen_test.dart
import 'package:appsdoc/screens/proyectos/proyecto_form_screen.dart';
import 'package:appsdoc/screens/proyectos/proyectos_list_screen.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ProyectoService.debugFirestoreOverride = FakeFirebaseFirestore();
    ProyectoService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('sin proyectos, muestra el estado vacío real', (tester) async {
    await tester.pumpWidget(envolver(const ProyectosListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tienes ningún proyecto'), findsOneWidget);
  });

  testWidgets('crear un proyecto desde el FAB lo hace aparecer en la lista', (tester) async {
    await tester.pumpWidget(envolver(const ProyectosListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(ProyectoFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'RiskRunner');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear proyecto'));
    await tester.pumpAndSettle();

    expect(find.byType(ProyectoFormScreen), findsNothing);
    expect(find.text('RiskRunner'), findsOneWidget);
  });

  testWidgets('tocar un proyecto existente abre su ficha con los datos precargados', (tester) async {
    await ProyectoService.crear(nombre: 'Convive', descripcion: 'Piso compartido');

    await tester.pumpWidget(envolver(const ProyectosListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Convive'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Convive'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Piso compartido'), findsOneWidget);
  });

  testWidgets('eliminar con confirmación hace que el proyecto desaparezca de la lista', (tester) async {
    await ProyectoService.crear(nombre: 'A borrar');

    await tester.pumpWidget(envolver(const ProyectosListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A borrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este proyecto?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(ProyectoFormScreen), findsNothing);
    expect(find.text('Todavía no tienes ningún proyecto'), findsOneWidget);
  });
}
