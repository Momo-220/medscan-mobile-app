import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class CustomInput extends StatelessWidget {
  final String? label;
  final String? error;
  final Widget? icon;
  final Widget? suffixIcon;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  const CustomInput({
    super.key,
    this.label,
    this.error,
    this.icon,
    this.suffixIcon,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.small(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          autofocus: autofocus,
          style: AppTextStyles.body(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: icon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            errorText: error,
            errorStyle: AppTextStyles.small(color: Colors.red[500]),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red[500]!, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red[500]!, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
