import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const purple = Color(0xFF534AB7);
  static const purpleLight = Color(0xFFEEEDFE);
  static const purpleDark = Color(0xFF3C3489);

  // Semantic — light
  static const surfaceLight = Color(0xFFFFFFFF);
  static const bgLight = Color(0xFFF5F5F5);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0x0F000000); // black @ 6%
  static const textPrimLight = Color(0xFF1A1A1A);
  static const textSecLight = Color(0xFF5F5E5A);
  static const textHintLight = Color(0xFF888780);

  // Semantic — dark
  static const surfaceDark = Color(0xFF1C1C1E);
  static const bgDark = Color(0xFF111113);
  static const cardDark = Color(0xFF2C2C2E);
  static const borderDark = Color(0x1FFFFFFF); // white @ 12%
  static const textPrimDark = Color(0xFFECECEC);
  static const textSecDark = Color(0xFFB4B2A9);
  static const textHintDark = Color(0xFF888780);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrim = isDark ? AppColors.textPrimDark : AppColors.textPrimLight;
    final textSec = isDark ? AppColors.textSecDark : AppColors.textSecLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.purple,
      onPrimary: Colors.white,
      secondary: AppColors.purpleLight,
      onSecondary: AppColors.purpleDark,
      surface: surface,
      onSurface: textPrim,
      error: const Color(0xFFE24B4A),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrim),
        titleTextStyle: TextStyle(
          color: textPrim,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.purple,
        unselectedItemColor: textSec,
        showUnselectedLabels: true,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.5,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        thickness: 0.5,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSec),
        hintStyle: TextStyle(color: textSec),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          side: const BorderSide(color: AppColors.purple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.purple),
      ),

      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrim),
        bodyMedium: TextStyle(color: textPrim),
        bodySmall: TextStyle(color: textSec),
        labelSmall: TextStyle(color: textSec),
      ),
    );
  }
}
