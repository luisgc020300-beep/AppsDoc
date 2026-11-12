// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appsdoc/main.dart';

void main() {
  testWidgets('arranca mostrando la lista de apps con la semilla inicial', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AppsDocApp());
    await tester.pumpAndSettle();

    expect(find.text('AppsDoc'), findsOneWidget);
    expect(find.text('RiskRunner'), findsOneWidget);
    expect(find.text('Convive'), findsOneWidget);
    expect(find.text('REPARA'), findsOneWidget);
  });

  testWidgets('tocar una app abre su detalle con nombre editable', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AppsDocApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('RiskRunner'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'RiskRunner'), findsOneWidget);
  });
}
