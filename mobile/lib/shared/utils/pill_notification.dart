import 'package:flutter/material.dart';

void showPillError(BuildContext context, String message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final size = MediaQuery.of(context).size;
  
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      margin: EdgeInsets.only(
        bottom: size.height - 120 - MediaQuery.of(context).padding.top,
        left: 24,
        right: 24,
      ),
      duration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showPillSuccess(BuildContext context, String message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final size = MediaQuery.of(context).size;
  
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF064E3B) : const Color(0xFF10B981),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      margin: EdgeInsets.only(
        bottom: size.height - 120 - MediaQuery.of(context).padding.top,
        left: 24,
        right: 24,
      ),
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
