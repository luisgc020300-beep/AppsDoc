// test/screens/documento_form_screen_test.dart
import 'package:appsdoc/models/categoria_documento.dart';
import 'package:appsdoc/screens/documentacion/documento_form_screen.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-test';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-test';
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-test';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un título vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const DocumentoFormScreen(proyectoId: 'p1')));

    await tester.tap(find.widgetWithText(FilledButton, 'Crear documento'));
    await tester.pump();

    expect(find.text('El título es obligatorio'), findsOneWidget);
    expect(await DocumentoService.streamDocumentos('p1').first, isEmpty);
  });

  testWidgets('elegir una categoría distinta la refleja seleccionada', (tester) async {
    await tester.pumpWidget(envolver(const DocumentoFormScreen(proyectoId: 'p1')));
    await tester.pump();

    final chipArquitectura = find.widgetWithText(ChoiceChip, 'Arquitectura');
    await tester.tap(chipArquitectura);
    await tester.pump();

    final chip = tester.widget<ChoiceChip>(chipArquitectura);
    expect(chip.selected, true);
  });

  testWidgets('crear con título válido guarda con categoría "Nota" por defecto', (tester) async {
    await tester.pumpWidget(envolver(const DocumentoFormScreen(proyectoId: 'p1')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Nota rápida');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contenido'), 'contenido de prueba');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear documento'));
    await tester.pumpAndSettle();

    final d = (await DocumentoService.streamDocumentos('p1').first).single;
    expect(d.titulo, 'Nota rápida');
    expect(d.contenido, 'contenido de prueba');
    expect(d.categoria, CategoriaDocumento.nota);
  });

  testWidgets('editar un documento existente precarga sus datos y permite eliminarlo', (tester) async {
    await DocumentoService.crear(proyectoId: 'p1', titulo: 'A editar', categoria: CategoriaDocumento.decision);
    final existente = (await DocumentoService.streamDocumentos('p1').first).single;

    await tester.pumpWidget(envolver(DocumentoFormScreen(proyectoId: 'p1', documentoExistente: existente)));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'A editar'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Decisión'));
    expect(chip.selected, true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await DocumentoService.streamDocumentos('p1').first, isEmpty);
  });
}
