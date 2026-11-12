// lib/theme/design_tokens.dart
//
// Identidad visual de AppsDoc (Fase 8 -- rediseño completo): panel de
// control corporativo, premium y serio. Azul marino profundo como color
// de marca, azul eléctrico como único acento interactivo, blancos y grises
// azulados para superficies, verde discreto para progreso/éxito, y
// rojo/ámbar reservados exclusivamente para alertas. Todo pasa por
// ThemeData (component themes) en vez de estilos sueltos por pantalla --
// así una sola fuente de verdad gobierna las dos docenas de pantallas de
// la app.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta con significado, accesible vía `context.colors.x` -- se resuelve
/// al tema activo, igual patrón que ConviveColorsExt/ReparaColorsExt.
class AppsDocColorsExt extends ThemeExtension<AppsDocColorsExt> {
  const AppsDocColorsExt({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface; // tarjetas, cabeceras
  final Color surfaceMuted; // campos de entrada, filas alternas, chips
  final Color border; // bordes sutiles de tarjetas y separadores
  final Color textPrimary;
  final Color textMuted;
  final Color accent; // azul eléctrico -- único acento interactivo
  final Color accentMuted; // fondo tenue del acento (chips/badges seleccionados)
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;

  static const dark = AppsDocColorsExt(
    background: Color(0xFF0A1322),
    surface: Color(0xFF121E33),
    surfaceMuted: Color(0xFF1B2941),
    border: Color(0xFF293A58),
    textPrimary: Color(0xFFF2F5FA),
    textMuted: Color(0xFF93A3C4),
    accent: Color(0xFF4C8DFF),
    accentMuted: Color(0xFF1E335C),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFF2B84B),
    danger: Color(0xFFF87171),
  );

  static const light = AppsDocColorsExt(
    background: Color(0xFFF3F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEBF0F9),
    border: Color(0xFFDCE3F0),
    textPrimary: Color(0xFF0B1F3A),
    textMuted: Color(0xFF5B6B85),
    accent: Color(0xFF2F6FED),
    accentMuted: Color(0xFFE3ECFC),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF1B9C6E),
    warning: Color(0xFFB4790A),
    danger: Color(0xFFDC2626),
  );

  @override
  AppsDocColorsExt copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? accent,
    Color? accentMuted,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppsDocColorsExt(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
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

  /// Space Grotesk para títulos (geométrica, técnica, premium) + Inter
  /// para el resto de la interfaz (muy legible en listas densas de
  /// datos).
  static TextTheme uiTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final palette = brightness == Brightness.dark ? AppsDocColorsExt.dark : AppsDocColorsExt.light;
    return GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary)
        .copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: palette.textPrimary),
          displayMedium: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w700, color: palette.textPrimary),
          displaySmall: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: palette.textPrimary),
          headlineSmall: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600, color: palette.textPrimary),
          titleLarge: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary),
          titleMedium: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
          titleSmall: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textMuted,
            letterSpacing: 0.2,
          ),
          labelLarge: const TextStyle(fontWeight: FontWeight.w600),
        );
  }

  /// Letra mono -- para identificadores técnicos (stack, ruta de repo,
  /// URLs), igual criterio que REPARA/Convive usan mono solo para datos
  /// "de recibo", nunca para texto general.
  static TextStyle mono({required Color color, double fontSize = 13, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(fontSize: fontSize, fontWeight: weight, color: color);
}

ThemeData _buildAppsDocTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppsDocColorsExt.dark : AppsDocColorsExt.light;
  final textTheme = AppsDocText.uiTextTheme(brightness);
  final shadowColor = isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0xFF0B1F3A).withValues(alpha: 0.06);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
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
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: palette.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    dividerColor: palette.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.danger, width: 1.2),
      ),
      labelStyle: TextStyle(color: palette.textMuted),
      hintStyle: TextStyle(color: palette.textMuted.withValues(alpha: 0.8)),
      prefixIconColor: palette.textMuted,
      suffixIconColor: palette.textMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: palette.accent.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.border),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: palette.textMuted)),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceMuted,
      selectedColor: palette.accent,
      disabledColor: palette.surfaceMuted,
      labelStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: palette.onAccent, fontWeight: FontWeight.w500, fontSize: 13),
      side: BorderSide(color: palette.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: palette.border)),
      textStyle: textTheme.bodyMedium,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.textMuted,
      textColor: palette.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.textPrimary,
      contentTextStyle: TextStyle(color: palette.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent, circularTrackColor: palette.surfaceMuted),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.accent,
      unselectedLabelColor: palette.textMuted,
      indicatorColor: palette.accent,
      dividerColor: palette.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.accentMuted,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? palette.accent : palette.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? palette.accent : palette.textMuted),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.accent : Colors.transparent,
      ),
      side: BorderSide(color: palette.textMuted),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.accent : palette.textMuted,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.accent : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.accentMuted : palette.surfaceMuted,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: palette.surface,
      headerBackgroundColor: palette.accent,
      headerForegroundColor: palette.onAccent,
    ),
  );
}

ThemeData buildAppsDocDarkTheme() => _buildAppsDocTheme(Brightness.dark);
ThemeData buildAppsDocLightTheme() => _buildAppsDocTheme(Brightness.light);
