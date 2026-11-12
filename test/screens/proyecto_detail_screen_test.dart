// test/screens/proyecto_detail_screen_test.dart
import 'package:appsdoc/screens/documentacion/documento_form_screen.dart';
import 'package:appsdoc/screens/funcionalidades/funcionalidad_form_screen.dart';
import 'package:appsdoc/screens/proyectos/proyecto_detail_screen.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
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
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-test';
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('muestra la ficha del proyecto y los estados vacíos de ambas secciones', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    expect(find.text('Mantenimiento del hogar'), findsOneWidget);
    expect(find.text('Funcionalidades'), findsOneWidget);
    expect(find.text('Documentación'), findsOneWidget);
    expect(find.text('Sin funcionalidades todavía.'), findsOneWidget);
    expect(find.text('Sin documentos todavía.'), findsOneWidget);
  });

  testWidgets('añadir una funcionalidad desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(FuncionalidadFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Invitar profesional');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear funcionalidad'));
    await tester.pumpAndSettle();

    expect(find.byType(FuncionalidadFormScreen), findsNothing);
    expect(find.text('Invitar profesional'), findsOneWidget);
    expect(find.text('Sin funcionalidades todavía.'), findsNothing);
  });

  testWidgets('añadir un documento desde la sección lo hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).last);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentoFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Arquitectura de notificaciones');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear documento'));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentoFormScreen), findsNothing);
    expect(find.text('Arquitectura de notificaciones'), findsOneWidget);
    expect(find.text('Sin documentos todavía.'), findsNothing);
  });

  testWidgets('eliminar el proyecto desde "editar" cierra también la pantalla de detalle', (tester) async {
    final id = await ProyectoService.crear(nombre: 'Efímero');

    await tester.pumpWidget(
      envolver(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProyectoDetailScreen(proyectoId: id))),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(ProyectoDetailScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
