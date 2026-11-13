// test/screens/elegir_proyecto_asistente_screen_test.dart
import 'package:appsdoc/screens/asistente/asistente_screen.dart';
import 'package:appsdoc/screens/asistente/elegir_proyecto_asistente_screen.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/mensaje_asistente_service.dart';
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
    MensajeAsistenteService.debugFirestoreOverride = db;
    MensajeAsistenteService.debugUidOverride = 'uid-test';
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
    MensajeAsistenteService.debugFirestoreOverride = null;
    MensajeAsistenteService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('sin proyectos, invita a crear uno primero', (tester) async {
    await tester.pumpWidget(envolver(const ElegirProyectoAsistenteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Crea un proyecto primero'), findsOneWidget);
  });

  testWidgets('lista los proyectos y tocar uno abre su asistente', (tester) async {
    await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.crear(nombre: 'Convive');

    await tester.pumpWidget(envolver(const ElegirProyectoAsistenteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('REPARA'), findsOneWidget);
    expect(find.text('Convive'), findsOneWidget);

    await tester.tap(find.text('REPARA'));
    await tester.pumpAndSettle();

    expect(find.byType(AsistenteScreen), findsOneWidget);
    expect(find.textContaining('REPARA'), findsWidgets);
  });
}
