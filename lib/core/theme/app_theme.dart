import 'package:flutter/material.dart';

class AppTheme {
  static const Color _ink = Color(0xFF18313C);
  static const Color _navy = Color(0xFF2D5364);
  static const Color _teal = Color(0xFF5B8C85);
  static const Color _terracotta = Color(0xFFC46E4B);
  static const Color _sand = Color(0xFFF4F1EA);
  static const Color _white = Color(0xFFFFFCF8);

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _navy,
      onPrimary: Colors.white,
      secondary: _terracotta,
      onSecondary: Colors.white,
      error: Color(0xFFB2412D),
      onError: Colors.white,
      surface: _white,
      onSurface: _ink,
      surfaceContainerHighest: Color(0xFFDCE5E8),
      onSurfaceVariant: Color(0xFF5E737B),
      outline: Color(0xFFB2C0C5),
      outlineVariant: Color(0xFFD6E0E3),
      shadow: Color(0x3318313C),
      scrim: Color(0x8018313C),
      inverseSurface: _ink,
      onInverseSurface: _sand,
      inversePrimary: Color(0xFF93B4C2),
      tertiary: _teal,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD7E7E3),
      onTertiaryContainer: _ink,
      primaryContainer: Color(0xFFD8E6EB),
      onPrimaryContainer: _ink,
      secondaryContainer: Color(0xFFF6DDD4),
      onSecondaryContainer: _ink,
      errorContainer: Color(0xFFFADBD5),
      onErrorContainer: Color(0xFF5E1A10),
      surfaceDim: Color(0xFFE9E4DB),
      surfaceBright: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAF7F1),
      surfaceContainer: Color(0xFFF5F1EA),
      surfaceContainerHigh: Color(0xFFEFE9E0),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _sand,
      canvasColor: _sand,
      dividerColor: colorScheme.outlineVariant,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: _sand,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: _ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _navy, width: 1.4),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: _ink,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF4C646D),
          height: 1.45,
        ),
      ),
    );
  }
}
