import 'package:flutter/material.dart';

class AppTheme {
  static const up = Color(0xFF22C55E);
  static const down = Color(0xFFEF4444);
  static const accent = Color(0xFF3B82F6);
  static const _darkBackground = Color(0xFF0A0E14);
  static const _darkSurface = Color(0xFF11161F);
  static const _lightBackground = Color(0xFFF6F7F9);
  static const _lightSurface = Color(0xFFFFFFFF);

  /// Colores para series de gráficos (distribución del portafolio).
  static const chartPalette = [
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF64748B),
  ];

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? _darkSurface : _lightSurface;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(height: 1.35),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.25)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.2)),
    );
  }
}
