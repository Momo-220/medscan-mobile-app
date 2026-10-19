import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(size * 0.35),
          border: Border.all(
            color: value
                ? AppColors.primary
                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            width: 1.6,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedScale(
          scale: value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              size: 15.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
