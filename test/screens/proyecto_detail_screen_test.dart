// test/screens/proyecto_detail_screen_test.dart
import 'dart:convert';

import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/screens/analisis/analisis_repositorio_screen.dart';
import 'package:appsdoc/screens/asistente/asistente_screen.dart';
import 'package:appsdoc/screens/documentacion/documento_form_screen.dart';
import 'package:appsdoc/screens/funcionalidades/funcionalidad_form_screen.dart';
import 'package:appsdoc/screens/ideas/idea_form_screen.dart';
import 'package:appsdoc/screens/proyectos/proyecto_detail_screen.dart';
import 'package:appsdoc/screens/tareas/tarea_form_screen.dart';
import 'package:appsdoc/services/auditoria_service.dart';
import 'package:appsdoc/services/documento_service.dart';
import 'package:appsdoc/services/expediente_service.dart';
import 'package:appsdoc/services/funcionalidad_service.dart';
import 'package:appsdoc/services/github_service.dart';
import 'package:appsdoc/services/historial_service.dart';
import 'package:appsdoc/services/idea_service.dart';
import 'package:appsdoc/services/proyecto_service.dart';
import 'package:appsdoc/services/tarea_service.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
    IdeaService.debugFirestoreOverride = db;
    IdeaService.debugUidOverride = 'uid-test';
    AuditoriaService.debugFirestoreOverride = db;
    AuditoriaService.debugUidOverride = 'uid-test';
    HistorialService.debugFirestoreOverride = db;
    HistorialService.debugUidOverride = 'uid-test';
    ExpedienteService.debugFirestoreOverride = db;
    ExpedienteService.debugUidOverride = 'uid-test';
  });

  tearDown(() {
    GithubService.debugHttpClientOverride = null;
    ExpedienteService.debugFirestoreOverride = null;
    ExpedienteService.debugUidOverride = null;
    ExpedienteService.debugCallableOverride = null;
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
    IdeaService.debugFirestoreOverride = null;
    IdeaService.debugUidOverride = null;
  });

  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  Future<void> pumpDetailScreen(WidgetTester tester, String proyectoId) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: proyectoId)));
    await tester.pumpAndSettle();
  }

  /// La ficha es un TabBar desplazable (Resumen, Funcionalidades,
  /// Documentación, Tareas, Ideas, Auditorías, Historial) -- cada pestaña
  /// es su propia página, así que hace falta cambiar de pestaña antes de
  /// interactuar con el contenido de cualquiera que no sea "Resumen" (la
  /// que se ve al entrar).
  Future<void> irATab(WidgetTester tester, String etiqueta) async {
    final tab = find.widgetWithText(Tab, etiqueta);
    // El TabBar es desplazable (7 pestañas) -- "Historial", la última,
    // queda fuera del ancho del viewport de test hasta que se desplaza.
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra la ficha del proyecto y los estados vacíos de todas las secciones', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');

    await pumpDetailScreen(tester, id);

    // Resumen (pestaña por defecto).
    expect(find.text('Mantenimiento del hogar'), findsOneWidget);
    expect(find.text('Repositorio'), findsOneWidget);
    expect(find.text('Sin repositorio vinculado.'), findsOneWidget);

    await irATab(tester, 'Funcionalidades');
    expect(find.text('Sin funcionalidades todavía.'), findsOneWidget);

    await irATab(tester, 'Documentación');
    expect(find.text('Sin documentos todavía.'), findsOneWidget);

    await irATab(tester, 'Tareas');
    expect(find.text('Sin tareas todavía.'), findsOneWidget);

    await irATab(tester, 'Ideas');
    expect(find.text('Sin ideas todavía.'), findsOneWidget);

    await irATab(tester, 'Auditorías');
    expect(find.text('Sin auditorías todavía.'), findsOneWidget);

    await irATab(tester, 'Historial');
    // El propio crear() del proyecto ya dejó un evento -- nunca está vacío.
    expect(find.text('Sin actividad todavía.'), findsNothing);
    expect(find.textContaining('Proyecto creado'), findsOneWidget);

    await irATab(tester, 'Expediente');
    expect(find.textContaining('Vincula un repositorio'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generar expediente'), findsNothing);
  });

  testWidgets('la pestaña Expediente ofrece generar uno cuando hay repositorio vinculado, y muestra el confirmado cuando existe', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await ProyectoService.vincularRepo(id, 'https://github.com/owner/repo');
    GithubService.debugHttpClientOverride = MockClient(
      (request) async => http.Response(jsonEncode({'default_branch': 'main', 'updated_at': '2026-11-01T10:00:00Z'}), 200),
    );
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Expediente');

    // find.widgetWithText compara runtimeType exacto -- FilledButton.tonalIcon
    // construye una subclase privada, así que hace falta un predicate con "is".
    expect(find.ancestor(of: find.text('Generar expediente'), matching: find.byWidgetPredicate((w) => w is FilledButton)), findsOneWidget);
    expect(find.textContaining('Todavía no hay un expediente confirmado'), findsOneWidget);

    ExpedienteService.debugCallableOverride = (datos) async => {
      'descripcionGeneral': {'resumen': 'Confirmado', 'propuestaValor': '', 'publicoObjetivo': '', 'estadoMadurez': ''},
      'pantallas': <Map<String, dynamic>>[],
      'catalogoFuncionalidades': <Map<String, dynamic>>[],
      'arquitectura': {'resumen': '', 'patrones': [], 'tecnologias': []},
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
        'segmentoObjetivo': '',
        'supuestos': [],
        'limitaciones': '',
        'nivelConfianza': 'baja',
      },
      'progresoValor': {'progresoPorcentajeLeido': 0, 'analisisTexto': ''},
      'metaGeneracion': {'modeloUsado': '', 'etapasEjecutadas': 0, 'archivosAnalizados': 0, 'archivosOmitidos': 0, 'truncado': false},
    };
    final expediente = await ExpedienteService.generar(proyectoId: id);
    await ExpedienteService.confirmar(id, expediente.id);
    await tester.pumpAndSettle();

    expect(find.text('Confirmado'), findsOneWidget);
    // find.widgetWithText compara runtimeType exacto, y .tonalIcon/.icon
    // construyen subclases privadas -- ButtonStyleButton es la superclase
    // común a FilledButton/OutlinedButton/TextButton, así que el test no
    // depende de cuál de los tres se use para cada acción.
    Finder botonConTexto(String texto) =>
        find.ancestor(of: find.text(texto), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(botonConTexto('Galería de capturas'), findsOneWidget);
    expect(botonConTexto('Generar de nuevo'), findsOneWidget);
    expect(botonConTexto('Corregir descripción'), findsOneWidget);
  });

  testWidgets('añadir una funcionalidad desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Funcionalidades');

    await tester.tap(find.byTooltip('Añadir funcionalidad'));
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

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Documentación');

    await tester.tap(find.byTooltip('Añadir documento'));
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

  testWidgets('añadir una tarea desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Tareas');

    await tester.tap(find.byTooltip('Añadir tarea'));
    await tester.pumpAndSettle();
    expect(find.byType(TareaFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Escribir reglas de Firestore');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pumpAndSettle();

    expect(find.byType(TareaFormScreen), findsNothing);
    expect(find.text('Escribir reglas de Firestore'), findsOneWidget);
    expect(find.text('Sin tareas todavía.'), findsNothing);
  });

  testWidgets('añadir una idea desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Ideas');

    await tester.tap(find.byTooltip('Añadir idea'));
    await tester.pumpAndSettle();
    expect(find.byType(IdeaFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Soporte offline');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear idea'));
    await tester.pumpAndSettle();

    expect(find.byType(IdeaFormScreen), findsNothing);
    expect(find.text('Soporte offline'), findsOneWidget);
    expect(find.text('Sin ideas todavía.'), findsNothing);
  });

  testWidgets('cambiar el estado de una tarea desde el menú de la lista no abre su ficha', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await TareaService.crear(proyectoId: id, titulo: 'Tarea rápida');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Tareas');

    expect(find.text('Pendiente'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<EstadoTarea>, 'Completada').last);
    await tester.pumpAndSettle();

    expect(find.byType(TareaFormScreen), findsNothing);
    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets('añadir una auditoría desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Auditorías');

    await tester.tap(find.byTooltip('Añadir auditoría'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Resumen'), 'Primera auditoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.pumpAndSettle();

    expect(find.text('Sin auditorías todavía.'), findsNothing);
    // La fila de la lista no muestra el resumen, solo fecha/origen -- lo
    // que sí confirma que se creó es que el historial recoja el evento.
    await irATab(tester, 'Historial');
    expect(find.textContaining('Auditoría creada'), findsOneWidget);
  });

  testWidgets('crear una tarea deja un evento en el historial, visible en esa misma pantalla', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await pumpDetailScreen(tester, id);
    await irATab(tester, 'Tareas');

    await tester.tap(find.byTooltip('Añadir tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Tarea con historial');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pumpAndSettle();

    await irATab(tester, 'Historial');
    expect(find.textContaining('Tarea creada: "Tarea con historial"'), findsOneWidget);
  });

  testWidgets('muestra el porcentaje y el desglose de los cuatro criterios de progreso', (tester) async {
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

  testWidgets('completar la única funcionalidad sube el progreso en vivo, sin recargar la pantalla', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');
    await FuncionalidadService.crear(proyectoId: id, nombre: 'Login');

    await pumpDetailScreen(tester, id);
    expect(find.text('45%'), findsOneWidget);

    await irATab(tester, 'Funcionalidades');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    await irATab(tester, 'Resumen');
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

  testWidgets('el botón "Analizar con IA" abre la pantalla de análisis del repositorio vinculado', (tester) async {
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
      find.ancestor(of: find.text('Analizar con IA'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnalisisRepositorioScreen), findsOneWidget);
    expect(find.textContaining('owner/repo'), findsOneWidget);
  });
}
