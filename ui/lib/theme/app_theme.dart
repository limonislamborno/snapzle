import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {

  static const Color background = Color(0xFFF7F5F0);
  static const Color backgroundSecondary = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDE9E3);

  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryOrange = Color(0xFFEA580C);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPink = Color(0xFFDB2777);
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color accentEmerald = Color(0xFF059669);
  static const Color accentAmber = Color(0xFFD97706);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color glassFill = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0xFFE2E8F0);
  static const Color glassStrong = Color(0xFFFFFFFF);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryOrange, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient textGradient = LinearGradient(
    colors: [primaryOrange, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get appTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryOrange,
        surface: AppColors.backgroundSecondary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textMuted,
      ),
    );
  }
}
