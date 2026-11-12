// test/screens/actividad_screen_test.dart
import 'package:appsdoc/screens/actividad/actividad_screen.dart';
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
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-test';
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-test';
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-test';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('sin proyectos, muestra el estado vacío de actividad', (tester) async {
    await tester.pumpWidget(envolver(const ActividadScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay actividad'), findsOneWidget);
  });

  testWidgets('junta el historial de varios proyectos, cada evento con el nombre de su proyecto', (tester) async {
    final idUno = await ProyectoService.crear(nombre: 'Uno');
    await ProyectoService.crear(nombre: 'Dos');
    await ProyectoService.actualizar(idUno, descripcion: 'cambio reciente');

    await tester.pumpWidget(envolver(const ActividadScreen()));
    await tester.pumpAndSettle();

    // "Uno" creado y luego actualizado (2 eventos), "Dos" solo creado (1).
    expect(find.textContaining('Proyecto creado'), findsNWidgets(2));
    expect(find.textContaining('Proyecto actualizado'), findsOneWidget);
    expect(find.text('Uno'), findsNWidgets(2));
    expect(find.text('Dos'), findsOneWidget);
  });
}
