// test/screens/proyecto_detail_screen_test.dart
import 'dart:convert';

import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/screens/asistente/asistente_screen.dart';
import 'package:appsdoc/screens/expediente/expediente_revision_screen.dart';
import 'package:appsdoc/screens/proyectos/proyecto_detail_screen.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/captura_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/expediente_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/github_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/mensaje_asistente_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _respuestaExpedienteCanon({String resumen = 'Confirmado'}) => {
  'descripcionGeneral': {'resumen': resumen, 'propuestaValor': 'Así se usa.', 'publicoObjetivo': '', 'estadoMadurez': ''},
  'pantallas': [
    {'nombre': 'Login', 'descripcionFuncion': '', 'archivoPrincipal': '', 'navegacion': '', 'pantallasRelacionadas': []},
  ],
  'catalogoFuncionalidades': [
    {'nombre': 'Iniciar sesión', 'descripcion': '', 'confianza': 'verificada', 'evidencia': '', 'archivosRelacionados': []},
  ],
  'posibilidadesFuturas': [
    {'nombre': 'Recordatorios por email', 'descripcion': ''},
  ],
  'arquitectura': {'resumen': 'Flutter + Firebase.', 'patrones': [], 'tecnologias': []},
  'calidad': {'resumen': '', 'hallazgos': []},
  'seguridad': {'resumen': '', 'hallazgos': []},
  'valoracionEconomica': {
    'conservador': {},
    'intermedio': {},
    'optimista': {},
    'supuestos': [],
    'limitaciones': '',
    'nivelConfianza': 'baja',
  },
  'potencialUsuarios': {
    'conservador': {},
    'intermedio': {},
    'optimista': {},
    'segmentoObjetivo': 'Gente con poco tiempo.',
    'supuestos': [],
    'limitaciones': '',
    'nivelConfianza': 'baja',
  },
  'progresoValor': {'progresoPorcentajeLeido': 0, 'analisisTexto': ''},
  'metaGeneracion': {'modeloUsado': '', 'etapasEjecutadas': 0, 'archivosAnalizados': 0, 'archivosOmitidos': 0, 'truncado': false},
};

void main() {
  setUp(() {
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
    ExpedienteService.debugFirestoreOverride = db;
    ExpedienteService.debugUidOverride = 'uid-test';
    CapturaService.debugFirestoreOverride = db;
    CapturaService.debugUidOverride = 'uid-test';
    MensajeAsistenteService.debugFirestoreOverride = db;
    MensajeAsistenteService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    GithubService.debugHttpClientOverride = null;
    ExpedienteService.debugFirestoreOverride = null;
    ExpedienteService.debugUidOverride = null;
    ExpedienteService.debugCallableOverride = null;
    CapturaService.debugFirestoreOverride = null;
    CapturaService.debugUidOverride = null;
    MensajeAsistenteService.debugFirestoreOverride = null;
    MensajeAsistenteService.debugUidOverride = null;
    ProyectoService.debugFirestoreOverride = null;
    ProyectoService.debugUidOverride = null;
    FuncionalidadService.debugFirestoreOverride = null;
    FuncionalidadService.debugUidOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    DocumentoService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  Future<void> pumpDetailScreen(WidgetTester tester, String proyectoId) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();
  }

  /// La ficha es un TabBar desplazable con 5 pestañas (Funcionalidades,
  /// Ideas, Documentos, Pantallas, Potencial) -- cada una es su propia
  /// página. La ficha básica/GitHub/progreso ya no es una pestaña: es una
  /// cabecera fija visible siempre, sin necesidad de cambiar de pestaña.
  Future<void> irATab(WidgetTester tester, String etiqueta) async {
    final tab = find.widgetWithText(Tab, etiqueta);
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra la cabecera fija y los estados vacíos de las 5 pestañas', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');

    await pumpDetailScreen(tester, id);

    // Cabecera fija: visible de entrada, sin cambiar de pestaña.
    expect(find.text('Mantenimiento del hogar'), findsOneWidget);
    expect(find.text('Repositorio'), findsOneWidget);
    expect(find.text('Sin repositorio vinculado.'), findsOneWidget);
    expect(find.text('Preparación para publicar'), findsOneWidget);

    for (final etiqueta in ['Funcionalidades', 'Ideas', 'Documentos', 'Pantallas', 'Potencial']) {
      await irATab(tester, etiqueta);
      expect(find.textContaining('Vincula un repositorio'), findsOneWidget, reason: 'pestaña "$etiqueta" sin repo vinculado');
    }

    // "Documentos" además conserva la sección de auditorías manuales, sin
    // repo ni expediente.
    await irATab(tester, 'Documentos');
    expect(find.text('Auditorías manuales'), findsOneWidget);
    expect(find.textContaining('Sin auditorías manuales todavía'), findsOneWidget);
  });

  testWidgets('con repo vinculado pero sin analizar, cada pestaña ofrece "Analizar con IA"', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient(
      (request) async => http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200),
    );

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Ideas');

    expect(find.textContaining('Todavía no se ha analizado'), findsOneWidget);
    Finder botonConTexto(String texto) =>
        find.ancestor(of: find.text(texto), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    await tester.tap(botonConTexto('Analizar con IA').first);
    await tester.pumpAndSettle();

    expect(find.byType(ExpedienteRevisionScreen), findsOneWidget);
  });

  testWidgets('analizar, confirmar y ver el resultado repartido en las 5 pestañas', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient(
      (request) async => http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200),
    );
    ExpedienteService.debugCallableOverride = (datos) async => _respuestaExpedienteCanon();

    await pumpDetailScreen(tester, id);

    Finder botonConTexto(String texto) =>
        find.ancestor(of: find.text(texto), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    await tester.tap(botonConTexto('Analizar con IA').first);
    await tester.pumpAndSettle();
    await tester.tap(botonConTexto('Generar expediente'));
    await tester.pumpAndSettle();
    await tester.tap(botonConTexto('Confirmar expediente'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpedienteRevisionScreen), findsNothing);

    await irATab(tester, 'Funcionalidades');
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('Así se usa.'), findsOneWidget);

    await irATab(tester, 'Ideas');
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Recordatorios por email'), findsOneWidget);

    await irATab(tester, 'Documentos');
    expect(find.text('Flutter + Firebase.'), findsOneWidget);

    await irATab(tester, 'Pantallas');
    expect(find.text('Login'), findsOneWidget);

    await irATab(tester, 'Potencial');
    expect(find.text('Gente con poco tiempo.'), findsOneWidget);
  });

  testWidgets('"Corregir" en Funcionalidades abre la edición manual de la descripción confirmada', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient(
      (request) async => http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200),
    );
    ExpedienteService.debugCallableOverride = (datos) async => _respuestaExpedienteCanon();
    final borrador = await ExpedienteService.generar(proyectoId: id);
    await ExpedienteService.confirmar(id, borrador.id);

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Funcionalidades');
    // TextButton.icon construye una subclase privada -- find.widgetWithText
    // compara runtimeType exacto, así que hace falta un predicate con "is".
    await tester.tap(find.ancestor(of: find.text('Corregir'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    await tester.pumpAndSettle();

    expect(find.text('Corregir descripción general'), findsOneWidget);
  });

  testWidgets('añadir una auditoría manual en Documentos la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Documentos');

    await tester.tap(find.byTooltip('Añadir auditoría'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Resumen'), 'Primera auditoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin auditorías manuales todavía'), findsNothing);
  });

  testWidgets('eliminar el proyecto desde "editar" cierra también la pantalla de detalle', (tester) async {
    final id = await ProyectoService.crear(nombre: 'Efímero');
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

  testWidgets('muestra el porcentaje y el desglose de los cuatro criterios de progreso en la cabecera', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);

    expect(find.text('Preparación para publicar'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Funcionalidades completadas'), findsOneWidget);
    expect(find.text('0/40'), findsOneWidget);
    expect(find.text('Sin hallazgos críticos abiertos'), findsOneWidget);
    expect(find.text('30/30'), findsOneWidget);
    expect(find.text('Tareas al día'), findsOneWidget);
    expect(find.text('15/15'), findsOneWidget);
    expect(find.text('Documentación base'), findsOneWidget);
    expect(find.text('0/15'), findsOneWidget);
  });

  testWidgets('completar una funcionalidad existente sube el progreso en vivo, en la cabecera, sin cambiar de pestaña', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    final funcionalidadId = await FuncionalidadService.crear(proyectoId: id, nombre: 'Login');

    await pumpDetailScreen(tester, id);
    expect(find.text('45%'), findsOneWidget);

    await FuncionalidadService.actualizar(id, funcionalidadId, estado: EstadoFuncionalidad.completada);
    await tester.pumpAndSettle();

    expect(find.text('85%'), findsOneWidget);
    expect(find.text('45%'), findsNothing);
  });

  testWidgets('vincular un repositorio muestra su resumen de GitHub (rama, último commit, actualizado)', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    GithubService.debugHttpClientOverride = MockClient((request) async {
      if (request.url.path == '/repos/owner/repo') {
        return http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200);
      }
      return http.Response(
        jsonEncode({
          'commit': {
            'message': 'fix: progreso real',
            'committer': {'date': '2026-11-10T08:30:00Z'},
          },
        }),
        200,
      );
    });

    await pumpDetailScreen(tester, id);

    await tester.tap(find.widgetWithText(FilledButton, 'Vincular repositorio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://github.com/owner/repo');
    await tester.tap(find.widgetWithText(FilledButton, 'Vincular'));
    await tester.pumpAndSettle();

    expect(find.text('owner/repo'), findsOneWidget);
    expect(find.textContaining('main'), findsWidgets);
    expect(find.textContaining('fix: progreso real'), findsOneWidget);
    expect(find.text('Conectado'), findsOneWidget);
  });

  testWidgets('una URL que no es de GitHub no se vincula y muestra el error en el propio diálogo', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);

    await tester.tap(find.widgetWithText(FilledButton, 'Vincular repositorio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://gitlab.com/owner/repo');
    await tester.tap(find.widgetWithText(FilledButton, 'Vincular'));
    await tester.pumpAndSettle();

    expect(find.text('Esa URL no parece la de un repositorio de GitHub'), findsOneWidget);
    expect(find.text('Sin repositorio vinculado.'), findsOneWidget);
  });

  testWidgets('un repositorio inexistente o privado muestra el mensaje de error, con botón para reintentar', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    var peticiones = 0;
    GithubService.debugHttpClientOverride = MockClient((request) async {
      peticiones++;
      return http.Response('not found', 404);
    });

    await pumpDetailScreen(tester, id);

    expect(find.text('El repositorio no existe o es privado.'), findsOneWidget);
    final peticionesTrasElPrimerIntento = peticiones;

    await tester.tap(find.byTooltip('Reintentar'));
    await tester.pumpAndSettle();

    expect(peticiones, greaterThan(peticionesTrasElPrimerIntento));
  });

  testWidgets('desvincular quita el resumen y vuelve al estado sin conectar', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient((request) async {
      if (request.url.path == '/repos/owner/repo') {
        return http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200);
      }
      return http.Response(
        jsonEncode({
          'commit': {
            'message': 'x',
            'committer': {'date': '2026-11-10T08:30:00Z'},
          },
        }),
        200,
      );
    });

    await pumpDetailScreen(tester, id);
    expect(find.text('owner/repo'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Desvincular repositorio'));
    await tester.pumpAndSettle();
    expect(find.text('¿Desvincular repositorio?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Desvincular'));
    await tester.pumpAndSettle();

    expect(find.text('Sin repositorio vinculado.'), findsOneWidget);
    expect(find.text('owner/repo'), findsNothing);
  });

  testWidgets('el icono de asistente abre la pantalla del asistente de IA para este proyecto', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);

    await tester.tap(find.byTooltip('Asistente'));
    await tester.pumpAndSettle();

    expect(find.byType(AsistenteScreen), findsOneWidget);
    expect(find.textContaining('REPARA'), findsWidgets);
  });

  testWidgets('el botón "Analizar con IA" de la cabecera abre ExpedienteRevisionScreen (una sola operación de IA)', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient(
      (request) async => http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200),
    );

    await pumpDetailScreen(tester, id);

    // find.widgetWithText compara runtimeType exacto -- FilledButton.tonalIcon
    // construye una subclase privada (_FilledButtonWithIcon), así que un
    // FilledButton "a secas" nunca casa con él. Hace falta un predicate con
    // "is" para aceptar esa subclase.
    await tester.tap(
      find.ancestor(of: find.text('Analizar con IA'), matching: find.byWidgetPredicate((w) => w is FilledButton)).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpedienteRevisionScreen), findsOneWidget);
  });
}
