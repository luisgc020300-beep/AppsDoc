// test/screens/analisis_repositorio_screen_test.dart
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/origen_auditoria.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/screens/analisis/analisis_repositorio_screen.dart';
import 'package:appsdoc/services/ai_assistant_service.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/idea_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _propuestaCanon() => {
  'resumen': 'App Flutter de gestión de proyectos personales.',
  'arquitecturaDetectada': 'Flutter + Firebase, servicios estáticos con seam de test.',
  'tecnologias': ['Flutter', 'Dart', 'Firebase'],
  'documentos': [
    {'titulo': 'Arquitectura general', 'categoria': 'arquitectura', 'contenido': '# Arquitectura\n\nDetalle...'},
  ],
  'funcionalidades': [
    {
      'nombre': 'Login',
      'descripcion': 'Email y contraseña',
      'estadoSugerido': 'completada',
      'confianza': 'alta',
      'evidencia': 'lib/screens/auth/login_screen.dart',
    },
  ],
  'hallazgos': [
    {'titulo': 'Falta rate limit', 'descripcion': 'En el endpoint de login', 'gravedad': 'alta'},
  ],
  'tareas': [
    {'titulo': 'Añadir tests de integración', 'descripcion': ''},
  ],
  'ideas': [
    {'titulo': 'Modo offline', 'descripcion': ''},
  ],
  'truncado': false,
  'archivosAnalizados': 12,
  'archivosOmitidos': 0,
  'commitAnalizado': 'abc1234',
  'rama': 'main',
};

// Construido a mano en vez de leerse con ProyectoService.streamProyecto(...).first:
// ese .snapshots().first, llamado en el cuerpo de testWidgets sobre un
// FakeFirebaseFirestore escrito en setUp(), deja el siguiente pumpWidget()
// colgado indefinidamente (interacción FakeAsync/stream de
// fake_cloud_firestore, no un bug de la pantalla). AnalisisRepositorioScreen
// solo necesita los datos, no la reactividad de un stream.
Proyecto _proyectoDePrueba(String id) => Proyecto(
  id: id,
  nombre: 'REPARA',
  estado: EstadoProyecto.idea,
  repoUrl: 'https://github.com/owner/repo',
  repoPropietario: 'owner',
  repoNombre: 'repo',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

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
    IdeaService.debugFirestoreOverride = db;
    IdeaService.debugUidOverride = 'uid-test';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';

    proyectoId = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(proyectoId, 'https://github.com/owner/repo');
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
    IdeaService.debugFirestoreOverride = null;
    IdeaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('estado inicial muestra el botón para analizar con el repositorio vinculado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();

    expect(find.textContaining('owner/repo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'), findsOneWidget);
  });

  testWidgets('analizar muestra la propuesta completa para revisar', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      expect(nombre, 'analizarRepositorio');
      expect(datos['proyectoId'], proyectoId);
      return _propuestaCanon();
    };
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();

    expect(find.text('App Flutter de gestión de proyectos personales.'), findsOneWidget);
    expect(find.text('Arquitectura general'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Falta rate limit'), findsOneWidget);
    expect(find.text('Añadir tests de integración'), findsOneWidget);
    expect(find.text('Modo offline'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Guardar selección'), findsOneWidget);
  });

  testWidgets('guardar la selección completa crea auditoría (origen análisis de repositorio), documento, funcionalidad, tarea e idea', (
    tester,
  ) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar selección'));
    await tester.pumpAndSettle();

    final auditorias = await AuditoriaService.streamAuditorias(proyectoId).first;
    expect(auditorias, hasLength(1));
    expect(auditorias.single.origen, OrigenAuditoria.analisisRepositorio);
    expect(auditorias.single.hallazgos, hasLength(1));

    final documentos = await DocumentoService.streamDocumentos(proyectoId).first;
    expect(documentos, hasLength(1));
    expect(documentos.single.titulo, 'Arquitectura general');

    final funcionalidades = await FuncionalidadService.streamFuncionalidades(proyectoId).first;
    expect(funcionalidades, hasLength(1));
    expect(funcionalidades.single.nombre, 'Login');

    final tareas = await TareaService.streamTareas(proyectoId).first;
    expect(tareas, hasLength(1));

    final ideas = await IdeaService.streamIdeas(proyectoId).first;
    expect(ideas, hasLength(1));
  });

  testWidgets('desmarcar un documento y una tarea antes de guardar los excluye', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Arquitectura general'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Añadir tests de integración'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar selección'));
    await tester.pumpAndSettle();

    final documentos = await DocumentoService.streamDocumentos(proyectoId).first;
    expect(documentos, isEmpty);
    final tareas = await TareaService.streamTareas(proyectoId).first;
    expect(tareas, isEmpty);
    // El resto de la selección (por defecto marcada) sigue guardándose.
    final funcionalidades = await FuncionalidadService.streamFuncionalidades(proyectoId).first;
    expect(funcionalidades, hasLength(1));
  });

  testWidgets('cambiar el estado sugerido de una funcionalidad guarda el estado elegido, no el sugerido por la IA', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();

    // La IA sugirió "completada" -- el usuario lo rebaja a "enProgreso"
    // antes de guardar, confirmando que el progreso nunca se concede sin
    // que una persona lo verifique.
    // find.byType(DropdownButton<dynamic>) nunca casa con
    // DropdownButton<EstadoFuncionalidad> -- DropdownButton es genérico y
    // el finder compara el runtimeType exacto, no con "is".
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButton<EstadoFuncionalidad>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En progreso').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar selección'));
    await tester.pumpAndSettle();

    final funcionalidades = await FuncionalidadService.streamFuncionalidades(proyectoId).first;
    expect(funcionalidades.single.estado.name, 'enProgreso');
  });

  testWidgets('un error al analizar se muestra sin salir de la pantalla inicial', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async {
      throw AiAssistantException('No se pudo contactar con el servicio de IA.');
    };
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo contactar con el servicio de IA.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'), findsOneWidget);
  });

  testWidgets('repetir el análisis vuelve a la pantalla inicial', (tester) async {
    AiAssistantService.debugCallableOverride = (nombre, datos) async => _propuestaCanon();
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(AnalisisRepositorioScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Repetir el análisis'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Analizar repositorio con IA'), findsOneWidget);
  });
}
