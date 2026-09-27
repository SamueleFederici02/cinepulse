import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Sfondi Dark OLED
  static const Color background = Color(0xFF090B0E);
  static const Color surface = Color(0xFF12161C);
  static const Color surfaceElevated = Color(0xFF191F28);
  static const Color surfaceGlass = Color(0xCC191F28);

  // Accenti Primari: Cinematic Orange & Neon Flame
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color amberFlame = Color(0xFFFF8500);
  static const Color warmGold = Color(0xFFFFB300);
  static const Color electricCyan = Color(0xFF40BCF4);
  static const Color softRed = Color(0xFFFF334B);
  static const Color velvetPurple = Color(0xFF9D4EDD);

  // Testi & Neutri
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color borderHighlight = Color(0x40FF6B00);

  // Brand Streaming
  static const Color netflixRed = Color(0xFFE50914);
  static const Color primeBlue = Color(0xFF00A8E1);
  static const Color disneyBlue = Color(0xFF113CCF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryOrange,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryOrange,
        secondary: AppColors.amberFlame,
        tertiary: AppColors.electricCyan,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle, width: 0.8),
        ),
      ),
    );
  }
}
