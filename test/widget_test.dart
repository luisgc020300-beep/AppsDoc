// test/widget_test.dart
import 'dart:async';

import 'package:appsdoc/app/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthGate', () {
    testWidgets('sin sesión (stream emite null) muestra la pantalla de "sin sesión"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate<String>(
            authStateChanges: Stream.value(null),
            onAutenticado: (_) => const Text('autenticado'),
            onSinSesion: (_) => const Text('login'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(find.text('autenticado'), findsNothing);
    });

    testWidgets('con sesión (stream emite un valor no nulo) muestra la pantalla autenticada', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate<String>(
            authStateChanges: Stream.value('uid-falso'),
            onAutenticado: (_) => const Text('autenticado'),
            onSinSesion: (_) => const Text('login'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('autenticado'), findsOneWidget);
      expect(find.text('login'), findsNothing);
    });

    testWidgets('mientras el stream no ha emitido nada, muestra un indicador de carga', (tester) async {
      final controller = StreamController<String?>();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate<String>(
            authStateChanges: controller.stream,
            onAutenticado: (_) => const Text('autenticado'),
            onSinSesion: (_) => const Text('login'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await controller.close();
    });
  });
}
