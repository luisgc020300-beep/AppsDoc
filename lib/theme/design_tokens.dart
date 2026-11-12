// lib/theme/design_tokens.dart
//
// Identidad visual de AppsDoc: panel de control técnico, limpio y serio --
// grafito/slate en vez de negro puro o blanco puro, un único acento
// (índigo) para todo lo interactivo, y los colores de estado ya definidos
// en EstadoProyecto para lo semántico. Nada decorativo sin significado.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta con significado, accesible vía `context.colors.x` -- se resuelve
/// al tema activo, igual patrón que ConviveColorsExt/ReparaColorsExt.
class AppsDocColorsExt extends ThemeExtension<AppsDocColorsExt> {
  const AppsDocColorsExt({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface; // tarjetas
  final Color surfaceMuted; // campos de entrada, filas alternas
  final Color textPrimary;
  final Color textMuted;
  final Color accent; // índigo -- único acento interactivo
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;

  static const dark = AppsDocColorsExt(
    background: Color(0xFF14171C),
    surface: Color(0xFF1C2029),
    surfaceMuted: Color(0xFF262B36),
    textPrimary: Color(0xFFE7EAF0),
    textMuted: Color(0xFF8A93A6),
    accent: Color(0xFF6C7BFF),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
  );

  static const light = AppsDocColorsExt(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDEFF3),
    textPrimary: Color(0xFF1A1D23),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFF4F46E5),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
  );

  @override
  AppsDocColorsExt copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppsDocColorsExt(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppsDocColorsExt lerp(ThemeExtension<AppsDocColorsExt>? other, double t) {
    if (other is! AppsDocColorsExt) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppsDocThemeContextX on BuildContext {
  AppsDocColorsExt get colors => Theme.of(this).extension<AppsDocColorsExt>()!;
}

class AppsDocText {
  AppsDocText._();

  /// Space Grotesk para títulos (geométrica, técnica) + Inter para el resto
  /// de la interfaz (muy legible en listas densas de datos).
  static TextTheme uiTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final palette = brightness == Brightness.dark ? AppsDocColorsExt.dark : AppsDocColorsExt.light;
    return GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary)
        .copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: palette.textPrimary),
          displayMedium: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w700, color: palette.textPrimary),
          headlineSmall: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600, color: palette.textPrimary),
          titleLarge: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary),
        );
  }

  /// Letra mono -- para identificadores técnicos (stack, ruta de repo,
  /// URLs), igual criterio que REPARA/Convive usan mono solo para datos
  /// "de recibo", nunca para texto general.
  static TextStyle mono({required Color color, double fontSize = 13, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(fontSize: fontSize, fontWeight: weight, color: color);
}

ThemeData _buildAppsDocTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? AppsDocColorsExt.dark : AppsDocColorsExt.light;
  final textTheme = AppsDocText.uiTextTheme(brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    extensions: [palette],
    colorScheme: ColorScheme(
      brightness: brightness,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.danger,
      onError: palette.onAccent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: palette.textMuted.withValues(alpha: 0.2),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      hintStyle: TextStyle(color: palette.textMuted.withValues(alpha: 0.8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

ThemeData buildAppsDocDarkTheme() => _buildAppsDocTheme(Brightness.dark);
ThemeData buildAppsDocLightTheme() => _buildAppsDocTheme(Brightness.light);
