import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

enum ButtonVariant { primary, secondary, ghost, danger }
enum ButtonSize { sm, md, lg }

class Button extends StatelessWidget {
  final ButtonVariant variant;
  final ButtonSize size;
  final bool loading;
  final Widget? icon;
  final Widget child;
  final VoidCallback? onTap;
  final bool disabled;
  final double? width;

  const Button({
    super.key,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.loading = false,
    this.icon,
    required this.child,
    this.onTap,
    this.disabled = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine colors
    Color? backgroundColor;
    Color? textColor;
    BorderSide borderSide = BorderSide.none;
    List<BoxShadow>? shadow;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = AppColors.primary;
        textColor = Colors.white;
        shadow = [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ];
        break;
      case ButtonVariant.secondary:
        backgroundColor = isDark ? AppColors.cardDark : AppColors.card;
        textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
        borderSide = BorderSide(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF0F7FF),
          width: 1,
        );
        break;
      case ButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        textColor = AppColors.primary;
        break;
      case ButtonVariant.danger:
        backgroundColor = Colors.red[500];
        textColor = Colors.white;
        shadow = [
          BoxShadow(
            color: Colors.red[500]!.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ];
        break;
    }

    // Determine padding and text style
    EdgeInsetsGeometry padding;
    TextStyle textStyle;

    switch (size) {
      case ButtonSize.sm:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        textStyle = AppTextStyles.small(
          color: textColor,
          fontWeight: FontWeight.w600,
        );
        break;
      case ButtonSize.md:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        textStyle = AppTextStyles.body(
          color: textColor,
          fontWeight: FontWeight.w600,
        );
        break;
      case ButtonSize.lg:
        padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        textStyle = AppTextStyles.body(
          color: textColor,
          fontWeight: FontWeight.w600,
        ).copyWith(fontSize: 18);
        break;
    }

    final bool isButtonEnabled = !disabled && !loading && onTap != null;

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        DefaultTextStyle(
          style: textStyle,
          child: child,
        ),
      ],
    );

    return Opacity(
      opacity: isButtonEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isButtonEnabled ? onTap : null,
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
            boxShadow: shadow,
          ),
          child: Center(
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
