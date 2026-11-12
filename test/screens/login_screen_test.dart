// test/screens/login_screen_test.dart
//
// Solo cubre la parte de UI/validación que no necesita una llamada real a
// FirebaseAuth (eso exigiría el emulador de Auth o mocks, fuera de alcance
// de la Fase 0) -- el envío con datos inválidos nunca llega a invocar
// FirebaseAuth porque el formulario lo bloquea antes.
import 'package:appsdoc/screens/auth/login_screen.dart';
import 'package:appsdoc/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(theme: buildAppsDocLightTheme(), home: child);

  testWidgets('arranca en modo "Entrar" y permite pasar a "Crear cuenta"', (tester) async {
    await tester.pumpWidget(envolver(const LoginScreen()));

    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Crear cuenta'), findsOneWidget);
  });

  testWidgets('un correo sin @ muestra el error de validación y no envía nada', (tester) async {
    await tester.pumpWidget(envolver(const LoginScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'no-es-un-correo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Correo no válido'), findsOneWidget);
  });

  testWidgets('una contraseña demasiado corta muestra el error de validación', (tester) async {
    await tester.pumpWidget(envolver(const LoginScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'alguien@ejemplo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });
}
