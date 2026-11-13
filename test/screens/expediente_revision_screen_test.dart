// test/screens/expediente_revision_screen_test.dart
import 'package:appsdoc/models/estado_expediente.dart';
import 'package:appsdoc/models/estado_proyecto.dart';
import 'package:appsdoc/models/proyecto.dart';
import 'package:appsdoc/screens/expediente/expediente_revision_screen.dart';
import 'package:appsdoc/services/expediente_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resultadoFuncion() => {
  'descripcionGeneral': {
    'resumen': 'App Flutter de gestión de proyectos personales.',
    'propuestaValor': 'Centraliza la documentación técnica.',
    'publicoObjetivo': 'Desarrolladores independientes.',
    'estadoMadurez': 'en desarrollo activo',
  },
  'pantallas': [
    {'nombre': 'Detalle de proyecto', 'archivoPrincipal': 'lib/screens/proyectos/proyecto_detail_screen.dart', 'descripcionFuncion': 'Muestra el proyecto.', 'navegacion': '', 'pantallasRelacionadas': []},
  ],
  'catalogoFuncionalidades': [
    {'nombre': 'Login', 'descripcion': 'Email y contraseña', 'confianza': 'verificada', 'evidencia': 'lib/screens/auth/login_screen.dart', 'archivosRelacionados': []},
  ],
  'arquitectura': {'resumen': 'Flutter + Firebase.', 'patrones': ['Servicios estáticos'], 'tecnologias': ['Flutter', 'Firebase']},
  'calidad': {'resumen': 'Código razonable.', 'hallazgos': []},
  'seguridad': {'resumen': 'Sin problemas confirmados.', 'hallazgos': []},
  'valoracionEconomica': {
    'conservador': {'costeDesarrolloEstimado': 5000, 'costeReconstruccionEstimado': 4000, 'valorProductoEstimado': 3000, 'moneda': 'EUR', 'razonamiento': 'Alcance reducido.'},
    'intermedio': {'costeDesarrolloEstimado': 10000, 'costeReconstruccionEstimado': 8000, 'valorProductoEstimado': 7000, 'moneda': 'EUR', 'razonamiento': 'Medio.'},
    'optimista': {'costeDesarrolloEstimado': 20000, 'costeReconstruccionEstimado': 15000, 'valorProductoEstimado': 15000, 'moneda': 'EUR', 'razonamiento': 'Con tracción.'},
    'supuestos': ['Tarifa media de mercado.'],
    'limitaciones': 'Sin datos de mercado reales.',
    'nivelConfianza': 'media',
  },
  'potencialUsuarios': {
    'conservador': {'usuariosEstimados': 50, 'razonamiento': 'Solo el equipo.'},
    'intermedio': {'usuariosEstimados': 500, 'razonamiento': 'Adopción moderada.'},
    'optimista': {'usuariosEstimados': 5000, 'razonamiento': 'Con marketing.'},
    'segmentoObjetivo': 'Desarrolladores independientes.',
    'supuestos': ['Sin competencia directa.'],
    'limitaciones': 'Estimación especulativa.',
    'nivelConfianza': 'baja',
  },
  'progresoValor': {'progresoPorcentajeLeido': 45, 'analisisTexto': 'El progreso es moderado.'},
  'metaGeneracion': {'modeloUsado': 'claude-sonnet-5-5', 'etapasEjecutadas': 5, 'archivosAnalizados': 30, 'archivosOmitidos': 2, 'truncado': false},
  'repoCommitAnalizado': 'abc1234',
  'repoRama': 'main',
};

// Construido a mano, no leído de Firestore -- ver la nota de depuración de
// Fase 9 en analisis_repositorio_screen_test.dart: streamProyecto(...).first
// llamado en el cuerpo de testWidgets antes del primer pumpWidget cuelga el
// siguiente pumpWidget() indefinidamente.
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
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    ExpedienteService.debugFirestoreOverride = db;
    ExpedienteService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    ExpedienteService.debugFirestoreOverride = null;
    ExpedienteService.debugUidOverride = null;
    ExpedienteService.debugCallableOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('estado inicial muestra el botón para generar con el repositorio vinculado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(ExpedienteRevisionScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();

    expect(find.textContaining('owner/repo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generar expediente'), findsOneWidget);
  });

  testWidgets('generar muestra el borrador completo para revisar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ExpedienteService.debugCallableOverride = (datos) async {
      expect(datos['proyectoId'], proyectoId);
      return _resultadoFuncion();
    };
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(ExpedienteRevisionScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generar expediente'));
    await tester.pumpAndSettle();

    expect(find.text('App Flutter de gestión de proyectos personales.'), findsOneWidget);
    expect(find.textContaining('Detalle de proyecto'), findsOneWidget);
    expect(find.textContaining('Login'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirmar expediente'), findsOneWidget);
  });

  testWidgets('confirmar guarda la versión como confirmada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(ExpedienteRevisionScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generar expediente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar expediente'));
    await tester.pumpAndSettle();

    final actual = await ExpedienteService.streamActualConfirmado(proyectoId).first;
    expect(actual, isNotNull);
    expect(actual!.estado, EstadoExpediente.confirmado);
  });

  testWidgets('descartar y repetir vuelve a la pantalla inicial sin dejar el borrador', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(ExpedienteRevisionScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generar expediente'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Descartar y repetir'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Generar expediente'), findsOneWidget);
    expect(await ExpedienteService.streamVersiones(proyectoId).first, isEmpty);
  });

  testWidgets('un error al generar se muestra sin salir de la pantalla inicial', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ExpedienteService.debugCallableOverride = (datos) async {
      throw ExpedienteException('No se pudo generar el expediente. Inténtalo de nuevo.');
    };
    final proyecto = _proyectoDePrueba(proyectoId);

    await tester.pumpWidget(envolver(ExpedienteRevisionScreen(proyecto: proyecto)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generar expediente'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo generar el expediente. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generar expediente'), findsOneWidget);
  });
}
