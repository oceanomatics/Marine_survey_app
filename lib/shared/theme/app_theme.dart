// lib/shared/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — Navy / Blue
  static const navy          = Color(0xFF0C2340);
  static const midBlue       = Color(0xFF185FA5);
  static const lightBlue     = Color(0xFFE6F1FB);
  static const skyBlue       = Color(0xFF378ADD);

  // Accent — Teal (vessel / machinery)
  static const teal          = Color(0xFF0F6E56);
  static const lightTeal     = Color(0xFFE1F5EE);

  // Accent — Coral (insurance / damage)
  static const coral         = Color(0xFF993C1D);
  static const lightCoral    = Color(0xFFFAECE7);

  // Accent — Amber (documents / media)
  static const amber         = Color(0xFF854F0B);
  static const lightAmber    = Color(0xFFFAEEDA);

  // Accent — Green (checklists)
  static const green         = Color(0xFF3B6D11);
  static const lightGreen    = Color(0xFFEAF3DE);

  // Accent — Purple (core / cases)
  static const purple        = Color(0xFF534AB7);
  static const lightPurple   = Color(0xFFEEEDFE);

  // Status colours
  static const success       = Color(0xFF2E7D32);
  static const warning       = Color(0xFFF57C00);
  static const error         = Color(0xFFC62828);
  static const info          = Color(0xFF1565C0);

  // Neutral
  static const textPrimary   = Color(0xFF1A1A18);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textTertiary  = Color(0xFF9E9C96);
  static const border        = Color(0xFFD3D1C7);
  static const surface       = Color(0xFFF8F7F3);
  static const background    = Color(0xFFFFFFFF);
  static const divider       = Color(0xFFEEECE6);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.midBlue,
      tertiary: AppColors.teal,
      surface: AppColors.background,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.navy,
      selectedIconTheme: IconThemeData(color: Colors.white),
      unselectedIconTheme: IconThemeData(color: Color(0xFF85B7EB)),
      selectedLabelTextStyle: TextStyle(color: Colors.white, fontSize: 11),
      unselectedLabelTextStyle:
          TextStyle(color: Color(0xFF85B7EB), fontSize: 11),
      indicatorColor: Color(0xFF185FA5),
    ),
    cardTheme: CardTheme(
      color: AppColors.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.midBlue, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightBlue,
      labelStyle: const TextStyle(
        color: AppColors.midBlue,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy),
      headlineMedium: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy),
      headlineSmall: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy),
      titleLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodyMedium: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
    ),
  );
}

/// Module colour mapping — used for section headers and badges
class ModuleColor {
  static Color bg(String module) => switch (module) {
    'cases'          => AppColors.lightPurple,
    'vessel'         => AppColors.lightTeal,
    'damage'         => AppColors.lightCoral,
    'invoices'       => AppColors.lightBlue,
    'documents'      => AppColors.lightAmber,
    'checklist'      => AppColors.lightGreen,
    'reports'        => const Color(0xFFF1EFE8),
    'correspondence' => const Color(0xFFE8E6FF),
    _                => AppColors.lightBlue,
  };

  static Color text(String module) => switch (module) {
    'cases'          => AppColors.purple,
    'vessel'         => AppColors.teal,
    'damage'         => AppColors.coral,
    'invoices'       => AppColors.midBlue,
    'documents'      => AppColors.amber,
    'checklist'      => AppColors.green,
    'reports'        => AppColors.textPrimary,
    'correspondence' => AppColors.purple,
    _                => AppColors.midBlue,
  };
}
