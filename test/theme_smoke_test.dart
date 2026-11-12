// test/theme_smoke_test.dart
//
// Ningún otro test ejercita buildAppsDocDarkTheme() -- todos construyen su
// MaterialApp con el tema claro. Esto no sustituye una comprobación visual
// real (no hay herramienta de captura de pantalla disponible en esta
// sesión), pero sí confirma que las pantallas principales construyen sin
// excepciones con AMBOS temas -- el fallo más básico ("un color no
// definido para el tema contrario", "un contexto sin AppsDocColorsExt")
// saltaría aquí.
import 'package:appsdoc/app/main_shell.dart';
import 'package:appsdoc/screens/actividad/actividad_screen.dart';
import 'package:appsdoc/screens/auth/login_screen.dart';
import 'package:appsdoc/screens/proyectos/proyecto_detail_screen.dart';
import 'package:appsdoc/screens/proyectos/proyectos_list_screen.dart';
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
    TareaService.debugFirestoreOverride = null;
    TareaService.debugUidOverride = null;
    IdeaService.debugFirestoreOverride = null;
    IdeaService.debugUidOverride = null;
    AuditoriaService.debugFirestoreOverride = null;
    AuditoriaService.debugUidOverride = null;
    HistorialService.debugFirestoreOverride = null;
    HistorialService.debugUidOverride = null;
  });

  for (final tema in [
    ('claro', buildAppsDocLightTheme),
    ('oscuro', buildAppsDocDarkTheme),
  ]) {
    final (nombreTema, construirTema) = tema;
    // construirTema() se llama dentro de cada test (nunca aquí, a nivel de
    // main()): buildAppsDocLightTheme()/DarkTheme() cargan fuentes de
    // Google Fonts vía ServicesBinding, que solo existe una vez arrancado
    // el binding de test -- cosa que todavía no ha pasado a este nivel.
    Widget envolver(Widget child) => MaterialApp(theme: construirTema(), home: child);

    testWidgets('Login renderiza sin excepciones en tema $nombreTema', (tester) async {
      await tester.pumpWidget(envolver(const LoginScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('listado de proyectos (con datos) renderiza sin excepciones en tema $nombreTema', (tester) async {
      await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');
      await ProyectoService.vincularRepo((await ProyectoService.streamProyectos().first).first.id, 'https://github.com/owner/repo');

      await tester.pumpWidget(envolver(const ProyectosListScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalle de proyecto con todas sus pestañas renderiza sin excepciones en tema $nombreTema', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final id = await ProyectoService.crear(nombre: 'REPARA', descripcion: 'Mantenimiento del hogar');
      await FuncionalidadService.crear(proyectoId: id, nombre: 'Login');
      await TareaService.crear(proyectoId: id, titulo: 'Tarea de prueba');

      await tester.pumpWidget(envolver(ProyectoDetailScreen(proyectoId: id)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final etiqueta in ['Funcionalidades', 'Documentación', 'Tareas', 'Ideas', 'Auditorías', 'Historial']) {
        final tab = find.widgetWithText(Tab, etiqueta);
        await tester.ensureVisible(tab);
        await tester.pumpAndSettle();
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'pestaña $etiqueta, tema $nombreTema');
      }
    });

    testWidgets('Actividad renderiza sin excepciones en tema $nombreTema', (tester) async {
      await ProyectoService.crear(nombre: 'REPARA');

      await tester.pumpWidget(envolver(const ActividadScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MainShell (Proyectos/Asistente/Actividad) renderiza sin excepciones en tema $nombreTema', (tester) async {
      await ProyectoService.crear(nombre: 'REPARA');

      await tester.pumpWidget(envolver(const MainShell()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Actividad'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
