// test/theme_controller_test.dart
import 'package:appsdoc/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeController.debugReset();
  });

  test('load() sin nada guardado empieza en ThemeMode.system', () async {
    final controller = await ThemeController.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('setMode() guarda y notifica, y vuelve a cargar ya guardado', () async {
    final controller = await ThemeController.load();
    var notificado = false;
    controller.addListener(() => notificado = true);

    await controller.setMode(ThemeMode.dark);

    expect(controller.mode, ThemeMode.dark);
    expect(notificado, true);
  });

  test('setMode() con el mismo modo actual no notifica (no-op)', () async {
    final controller = await ThemeController.load();
    var notificado = false;
    controller.addListener(() => notificado = true);

    await controller.setMode(ThemeMode.system);

    expect(notificado, false);
  });

  test('instance devuelve la misma instancia que load() resolvió', () async {
    final controller = await ThemeController.load();
    expect(ThemeController.instance, same(controller));
  });
}
