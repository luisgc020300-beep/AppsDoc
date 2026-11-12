// test/screens/pegar_auditoria_screen_test.dart
import 'package:appsdoc/models/origen_auditoria.dart';
import 'package:appsdoc/screens/asistente/pegar_auditoria_screen.dart';
import 'package:appsdoc/services/ai_assistant_service.dart';
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

Map<String, dynamic> _propuestaCanon() => {
  'resumen': 'Auditoría de seguridad pre-lanzamiento.',
  'hallazgos': [
    {'titulo': 'Falta rate limit', 'descripcion': 'En el endpoint de login', 'gravedad': 'alta'},
    {'titulo': 'Falta validación de entrada', 'descripcion': '', 'gravedad': 'media'},
  ],
  'tareas': [
    {'titulo': 'Añadir rate limit', 'descripcion': ''},
  ],
};

void main() {
  late String proyectoId;

  setUp(() async {
    final db = FakeFirebaseFirestore();
    ProyectoService.debugFirestoreOverride = db;
    ProyectoService.debugUidOverride = 'uid-test';
    FuncionalidadService.debugFirestoreOverride = db;
    FuncionalidadService.debugUidOverride = 'uid-test';
    DocumentoService.debugFirestoreOverride = db;
    DocumentoService.debugUidOverride = 'uid-test';
    TareaService.debugFirestoreOverride = db;
    TareaService.debugUidOverride = 'uid-test';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
    proyectoId = await ProyectoService.crear(nombre: 'REPARA');
  });

  tearDown(() {
    AiAssistantService.debugCallableOverride = null;
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('pegar texto y extraer muestra la propuesta para revisar', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      expect(nombre, 'extraerAuditoria');
      expect(datos['proyectoId'], proyectoId);
      return _propuestaCanon();
    };

    await tester.pumpWidget(envolver(PegarAuditoriaScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Texto de auditoría pegado desde Claude...');
    await tester.tap(find.widgetWithText(FilledButton, 'Extraer'));
    await tester.pumpAndSettle();

    expect(find.text('Auditoría de seguridad pre-lanzamiento.'), findsOneWidget);
    expect(find.text('Falta rate limit'), findsOneWidget);
    expect(find.text('Falta validación de entrada'), findsOneWidget);
    expect(find.text('Añadir rate limit'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
  });

  testWidgets('guardar la propuesta crea la auditoría con sus hallazgos y las tareas seleccionadas', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();

    await tester.pumpWidget(envolver(PegarAuditoriaScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Texto de auditoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Extraer'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final auditorias = await AuditoriaService.streamAuditorias(proyectoId).first;
    expect(auditorias, hasLength(1));
    expect(auditorias.single.origen, OrigenAuditoria.claude);
    expect(auditorias.single.resumen, 'Auditoría de seguridad pre-lanzamiento.');
    expect(auditorias.single.hallazgos, hasLength(2));
    expect(auditorias.single.hallazgos.map((h) => h.titulo), containsAll(['Falta rate limit', 'Falta validación de entrada']));

    final tareas = await TareaService.streamTareas(proyectoId).first;
    expect(tareas, hasLength(1));
    expect(tareas.single.titulo, 'Añadir rate limit');
  });

  testWidgets('desmarcar un hallazgo y una tarea antes de guardar los excluye', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();

    await tester.pumpWidget(envolver(PegarAuditoriaScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Texto de auditoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Extraer'));
    await tester.pumpAndSettle();

    // Desmarca el segundo hallazgo y la única tarea.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Falta validación de entrada'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Añadir rate limit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final auditorias = await AuditoriaService.streamAuditorias(proyectoId).first;
    expect(auditorias.single.hallazgos, hasLength(1));
    expect(auditorias.single.hallazgos.single.titulo, 'Falta rate limit');

    final tareas = await TareaService.streamTareas(proyectoId).first;
    expect(tareas, isEmpty);
  });

  testWidgets('un error en la extracción se muestra sin cambiar a la pantalla de revisión', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      throw AiAssistantException('No se pudo conectar con el servicio de IA.');
    };

    await tester.pumpWidget(envolver(PegarAuditoriaScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Texto de auditoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Extraer'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servicio de IA.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Extraer'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Guardar'), findsNothing);
  });
}
