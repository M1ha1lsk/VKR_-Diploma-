import 'package:flutter/material.dart';

enum AppThemeVariant { light, dark }

class AppThemeSpec {
  const AppThemeSpec({
    required this.primary,
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
  });

  final Color primary;
  final Color background;
  final Color surface;
  final Color text;
  final Color accent;
}

class AppThemes {
  static const Map<AppThemeVariant, AppThemeSpec> specs = {
    AppThemeVariant.light: AppThemeSpec(
      primary: Color(0xFF0066CC),
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFF0F7FF),
      text: Color(0xFF1A1A1A),
      accent: Color(0xFF003366),
    ),
    AppThemeVariant.dark: AppThemeSpec(
      primary: Color(0xFFFFC107),
      background: Color(0xFF000000),
      surface: Color(0xFF2C2C2C),
      text: Color(0xFFFFFFFF),
      accent: Color(0xFFFFEB3B),
    ),
  };

  static ThemeData toThemeData(AppThemeVariant variant) {
    final spec = specs[variant]!;
    final isDark = variant == AppThemeVariant.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: spec.primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: spec.surface,
    ).copyWith(
      primary: spec.primary,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: spec.accent,
      onSecondary: isDark ? Colors.black : Colors.white,
      onSurface: spec.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: spec.background,
      appBarTheme: AppBarTheme(
        backgroundColor: spec.primary,
        foregroundColor: scheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        color: spec.surface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: spec.primary,
        foregroundColor: scheme.onPrimary,
      ),
      chipTheme: ChipThemeData.fromDefaults(
        secondaryColor: spec.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        labelStyle: TextStyle(color: spec.text),
      ),
    );
  }
}
