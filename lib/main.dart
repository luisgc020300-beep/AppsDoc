// lib/main.dart
//
// AppsDoc -- herramienta personal para gestionar todos tus proyectos
// (documentación, funcionalidades, tareas, ideas, auditorías, progreso).
// Fase 0: base Firebase + Auth + tema + navegación inicial. La gestión de
// proyectos real llega en la Fase 1.
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/appsdoc_app.dart';
import 'firebase_options.dart';
import 'theme/theme_controller.dart';

// Permite probar contra el Emulator Suite local sin tocar el proyecto
// Firebase real (`appsdoc-app`) -- mismo criterio que RiskRunner/REPARA.
const bool _usarEmulador = bool.fromEnvironment('USE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmulador) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  }
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
      );
    } catch (e) {
      debugPrint('App Check no se pudo activar: $e');
    }

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  final themeController = await ThemeController.load();
  runApp(AppsDocApp(themeController: themeController));
}
