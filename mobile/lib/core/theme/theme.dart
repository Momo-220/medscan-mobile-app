import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.card,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w300),
        bodyMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w300),
        titleLarge: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0xCCFFFFFF), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        background: AppColors.background,
        surface: AppColors.card,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardColor: AppColors.cardDark,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w300),
        bodyMedium: GoogleFonts.inter(color: AppColors.textSecondaryDark, fontWeight: FontWeight.w300),
        titleLarge: GoogleFonts.poppins(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textMutedDark, fontSize: 14),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        background: AppColors.backgroundDark,
        surface: AppColors.cardDark,
      ),
    );
  }
}
