import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTextStyles {
  // Heading font is Poppins
  static TextStyle displayHero({Color? color, bool isDark = false}) => GoogleFonts.poppins(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle h1({Color? color, bool isDark = false}) => GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle h2({Color? color, bool isDark = false}) => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle h3({Color? color, bool isDark = false}) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  // Body font is Inter
  static TextStyle body({Color? color, bool isDark = false, FontWeight? fontWeight}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: fontWeight ?? FontWeight.w400, // Slightly bolder base weight (w400 instead of w300)
        height: 1.6,
        color: color ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
      );

  static TextStyle bodySemiBold({Color? color, bool isDark = false}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.6,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle bodyBold({Color? color, bool isDark = false}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        height: 1.6,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle small({Color? color, bool isDark = false, FontWeight? fontWeight}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: fontWeight ?? FontWeight.w500, // Medium weight for small text readability
        height: 1.4,
        color: color ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
      );

  static TextStyle smallBold({Color? color, bool isDark = false}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
      );

  static TextStyle micro({Color? color, bool isDark = false}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textMutedDark : AppColors.textMuted),
      );
}
