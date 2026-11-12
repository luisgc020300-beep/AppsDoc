// test/screens/proyecto_detail_screen_test.dart
import 'package:appsdoc/models/estado_tarea.dart';
import 'package:appsdoc/screens/documentacion/documento_form_screen.dart';
import 'package:appsdoc/screens/funcionalidades/funcionalidad_form_screen.dart';
import 'package:appsdoc/screens/ideas/idea_form_screen.dart';
import 'package:appsdoc/screens/proyectos/proyecto_detail_screen.dart';
import 'package:appsdoc/screens/tareas/tarea_form_screen.dart';
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
  });

  tearDown(() {
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

  testWidgets('muestra la ficha del proyecto y los estados vacíos de ambas secciones', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    expect(find.text('Mantenimiento del hogar'), findsOneWidget);
    expect(find.text('Funcionalidades'), findsOneWidget);
    expect(find.text('Documentación'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('Auditorías'), findsOneWidget);
    expect(find.text('Sin funcionalidades todavía.'), findsOneWidget);
    expect(find.text('Sin documentos todavía.'), findsOneWidget);
    expect(find.text('Sin tareas todavía.'), findsOneWidget);
    expect(find.text('Sin ideas todavía.'), findsOneWidget);
    expect(find.text('Sin auditorías todavía.'), findsOneWidget);

    // Historial es la última sección -- queda fuera del viewport por
    // defecto del test. La pantalla es una sola lista larga de secciones
    // (sin tabs), así que hace falta bajar para verla.
    await tester.scrollUntilVisible(find.text('Historial'), 300);
    expect(find.text('Historial'), findsOneWidget);
    // El propio crear() del proyecto ya dejó un evento -- nunca está vacío.
    expect(find.text('Sin actividad todavía.'), findsNothing);
    expect(find.textContaining('Proyecto creado'), findsOneWidget);
  });

  testWidgets('añadir una funcionalidad desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).first);
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

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).at(1));
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

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).at(2));
    await tester.pumpAndSettle();
    expect(find.byType(TareaFormScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Escribir reglas de Firestore');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pumpAndSettle();

    expect(find.byType(TareaFormScreen), findsNothing);
    expect(find.text('Escribir reglas de Firestore'), findsOneWidget);
    expect(find.text('Sin tareas todavía.'), findsNothing);
  });

  testWidgets('añadir una idea desde la sección la hace aparecer en la lista', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).at(3));
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

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).at(4));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Resumen'), 'Primera auditoría');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear auditoría'));
    await tester.pumpAndSettle();

    expect(find.text('Sin auditorías todavía.'), findsNothing);
    // La fila de la lista no muestra el resumen, solo fecha/origen -- lo
    // que sí confirma que se creó es que el historial recoja el evento.
    // Historial es la última sección, fuera del viewport por defecto.
    await tester.scrollUntilVisible(find.textContaining('Auditoría creada'), 300);
    expect(find.textContaining('Auditoría creada'), findsOneWidget);
  });

  testWidgets('crear una tarea deja un evento en el historial, visible en esa misma pantalla', (tester) async {
    final id = await ProyectoService.crear(nombre: 'REPARA');

    await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Tarea con historial');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear tarea'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Tarea creada: "Tarea con historial"'), 300);
    expect(find.textContaining('Tarea creada: "Tarea con historial"'), findsOneWidget);
  });
}
