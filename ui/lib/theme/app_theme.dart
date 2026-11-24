import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF07041A);
  static const Color backgroundSecondary = Color(0xFF0B0724);
  
  // Neon accents
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);

  // Glass colors
  static final Color glassFill = Colors.white.withOpacity(0.08);
  static final Color glassBorder = Colors.white.withOpacity(0.18);
  static final Color glassStrong = const Color(0xFF160E3A).withOpacity(0.85);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient textGradient = LinearGradient(
    colors: [Color(0xFFC4B5FD), Color(0xFF93C5FD), Color(0xFF67E8F9)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryBlue,
        surface: AppColors.backgroundSecondary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
