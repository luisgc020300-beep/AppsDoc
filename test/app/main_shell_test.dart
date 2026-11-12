// test/app/main_shell_test.dart
//
// No visita la pestaña "Perfil": AjustesScreen lee FirebaseAuth.instance
// directamente (sin seam de test), así que montarla exige un
// Firebase.initializeApp() real, fuera de alcance de un test de widgets
// puro. El resto de pestañas sí son alcanzables porque su estado pasa
// por servicios con debugFirestoreOverride, igual que el resto de la app.
import 'package:appsdoc/app/main_shell.dart';
import 'package:appsdoc/screens/actividad/actividad_screen.dart';
import 'package:appsdoc/screens/asistente/elegir_proyecto_asistente_screen.dart';
import 'package:appsdoc/screens/proyectos/proyectos_list_screen.dart';
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

  testWidgets('arranca en la pestaña Proyectos y cambia a Asistente y Actividad', (tester) async {
    await tester.pumpWidget(envolver(const MainShell()));
    await tester.pumpAndSettle();

    expect(find.byType(ProyectosListScreen), findsOneWidget);
    expect(find.byType(ElegirProyectoAsistenteScreen), findsNothing);

    await tester.tap(find.text('Asistente'));
    await tester.pumpAndSettle();
    expect(find.byType(ElegirProyectoAsistenteScreen), findsOneWidget);

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(find.byType(ActividadScreen), findsOneWidget);

    await tester.tap(find.text('Proyectos'));
    await tester.pumpAndSettle();
    // Al volver, la pestaña de Proyectos sigue montada (no se desmonta al
    // cambiar de pestaña) y conserva su estado.
    expect(find.byType(ProyectosListScreen), findsOneWidget);
  });
}
