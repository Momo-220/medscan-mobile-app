import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const Color primary = Color(0xFF5B9FED);
  static const Color primaryDark = Color(0xFF3B7FD4);
  static const Color primaryLight = Color(0xFFA8D5FF);

  static const Color background = Color(0xFFE8F2FF);
  static const Color backgroundSecondary = Color(0xFFF0F7FF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color deepBlue = Color(0xFF1A3B5D);
  static final Color deepBlueMuted = const Color(0xFF1A3B5D).withOpacity(0.25);

  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFFA0AEC0);

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);

  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textMutedDark = Color(0xFF94A3B8);

  // Alert/Status Colors
  static const Color alertHigh = Color(0xFFE53E3E);
  static const Color alertMedium = Color(0xFFDD6B20);
  static const Color alertLow = Color(0xFF319795);

  static const Color badgeGreen = Color(0xFFB8E86F);
  static const Color badgeGreenBg = Color(0xFFE8F5E9);

  // Gradients
  static const LinearGradient mainCardGradient = LinearGradient(
    colors: [Color(0xFFA8D5FF), Color(0xFF8FC5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mainCardGradientDark = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scanButtonGradient = LinearGradient(
    colors: [Color(0xFF5B9FED), Color(0xFF3B7FD4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient uploadButtonGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cameraButtonGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gemsBadgeGradient = LinearGradient(
    colors: [Color(0x33FACC15), Color(0x33F97316)], // yellow-400/20 to orange-500/20
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
