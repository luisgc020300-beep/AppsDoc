// test/screens/auditoria_form_screen_test.dart
import 'package:appsdoc/models/estado_hallazgo.dart';
import 'package:appsdoc/models/origen_auditoria.dart';
import 'package:appsdoc/screens/auditorias/auditoria_form_screen.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('un resumen vacío muestra el error de validación y no crea nada', (tester) async {
    await tester.pumpWidget(envolver(const AuditoriaFormScreen(proyectoId: 'p1')));

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.pump();

    expect(find.text('El resumen es obligatorio'), findsOneWidget);
    expect(await AuditoriaService.streamAuditorias('p1').first, isEmpty);
  });

  testWidgets('al crear una nueva, no aparece el botón de eliminar', (tester) async {
    await tester.pumpWidget(envolver(const AuditoriaFormScreen(proyectoId: 'p1')));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('crear con resumen válido guarda con origen "Manual" por defecto', (tester) async {
    await tester.pumpWidget(envolver(const AuditoriaFormScreen(proyectoId: 'p1')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Resumen'), 'Resumen de prueba');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.pumpAndSettle();

    final auditoria = (await AuditoriaService.streamAuditorias('p1').first).single;
    expect(auditoria.resumen, 'Resumen de prueba');
    expect(auditoria.origen, OrigenAuditoria.manual);
  });

  testWidgets('elegir el origen "Claude" lo refleja seleccionado', (tester) async {
    await tester.pumpWidget(envolver(const AuditoriaFormScreen(proyectoId: 'p1')));
    await tester.pump();

    final chipClaude = find.widgetWithText(ChoiceChip, 'Claude');
    await tester.tap(chipClaude);
    await tester.pump();

    expect(tester.widget<ChoiceChip>(chipClaude).selected, true);
  });

  testWidgets('ver una auditoría existente muestra su resumen de solo lectura y permite eliminarla', (tester) async {
    await AuditoriaService.crear(proyectoId: 'p1', fecha: DateTime(2026, 11, 10), resumen: 'Ya existente');
    final existente = (await AuditoriaService.streamAuditorias('p1').first).single;

    await tester.pumpWidget(envolver(AuditoriaFormScreen(proyectoId: 'p1', auditoriaExistente: existente)));
    await tester.pump();

    expect(find.text('Ya existente'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing, reason: 'una auditoría existente no se edita en sus campos de cabecera');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await AuditoriaService.streamAuditorias('p1').first, isEmpty);
  });

  testWidgets('añadir un hallazgo lo hace aparecer en la lista con estado "Abierto"', (tester) async {
    await AuditoriaService.crear(proyectoId: 'p1', fecha: DateTime.now(), resumen: 'X');
    final existente = (await AuditoriaService.streamAuditorias('p1').first).single;

    await tester.pumpWidget(envolver(AuditoriaFormScreen(proyectoId: 'p1', auditoriaExistente: existente)));
    await tester.pumpAndSettle();

    expect(find.text('Sin hallazgos todavía.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Falta validación');
    await tester.tap(find.widgetWithText(TextButton, 'Añadir'));
    await tester.pumpAndSettle();

    expect(find.text('Falta validación'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
  });

  testWidgets('cambiar el estado de un hallazgo desde su menú lo actualiza', (tester) async {
    final id = await AuditoriaService.crear(proyectoId: 'p1', fecha: DateTime.now(), resumen: 'X');
    await AuditoriaService.agregarHallazgo('p1', id, titulo: 'Hallazgo de prueba');
    final existente = (await AuditoriaService.streamAuditorias('p1').first).single;

    await tester.pumpWidget(envolver(AuditoriaFormScreen(proyectoId: 'p1', auditoriaExistente: existente)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<EstadoHallazgo>, 'Resuelto').last);
    await tester.pumpAndSettle();

    final actualizada = (await AuditoriaService.streamAuditorias('p1').first).single;
    expect(actualizada.hallazgos.single.estado, EstadoHallazgo.resuelto);
  });

  testWidgets('quitar un hallazgo lo elimina de la lista', (tester) async {
    final id = await AuditoriaService.crear(proyectoId: 'p1', fecha: DateTime.now(), resumen: 'X');
    await AuditoriaService.agregarHallazgo('p1', id, titulo: 'A quitar');
    final existente = (await AuditoriaService.streamAuditorias('p1').first).single;

    await tester.pumpWidget(envolver(AuditoriaFormScreen(proyectoId: 'p1', auditoriaExistente: existente)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final actualizada = (await AuditoriaService.streamAuditorias('p1').first).single;
    expect(actualizada.hallazgos, isEmpty);
  });
}
