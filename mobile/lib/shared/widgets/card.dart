import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class AppCard extends StatefulWidget {
  final Widget children;
  final bool hover;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool is3D;
  final bool isGradient;
  final double borderRadius;

  const AppCard({
    super.key,
    required this.children,
    this.hover = false,
    this.onTap,
    this.padding = const EdgeInsets.all(24.0),
    this.is3D = false,
    this.isGradient = false,
    this.borderRadius = 20.0,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define background decoration
    BoxDecoration decoration;

    final borderSide = BorderSide(
      color: isDark 
          ? const Color(0x1AFFFFFF) // rgba(255,255,255,0.1)
          : const Color(0xCCFFFFFF), // rgba(255,255,255,0.8)
      width: 1,
    );

    // Shadows
    final List<BoxShadow> shadows;
    if (widget.is3D || _isHovered) {
      shadows = isDark
          ? [
              const BoxShadow(
                color: Color(0x4D000000), // rgba(0,0,0,0.3)
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x66000000), // rgba(0,0,0,0.4)
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x4D000000), // rgba(0,0,0,0.3)
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ]
          : [
              const BoxShadow(
                color: Color(0x0F000000), // rgba(0,0,0,0.06)
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
              const BoxShadow(
                color: Color(0x1A000000), // rgba(0,0,0,0.1)
                blurRadius: 35,
                offset: Offset(0, 15),
              ),
              const BoxShadow(
                color: Color(0x14000000), // rgba(0,0,0,0.08)
                blurRadius: 50,
                offset: Offset(0, 25),
              ),
            ];
    } else {
      shadows = isDark
          ? [
              const BoxShadow(
                color: Color(0x4D000000), // rgba(0,0,0,0.3)
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x33000000), // rgba(0,0,0,0.2)
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ]
          : [
              const BoxShadow(
                color: Color(0x12000000), // rgba(0,0,0,0.07)
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x0D000000), // rgba(0,0,0,0.05)
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ];
    }

    if (widget.isGradient) {
      decoration = BoxDecoration(
        gradient: isDark ? AppColors.mainCardGradientDark : AppColors.mainCardGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.fromBorderSide(borderSide),
        boxShadow: shadows,
      );
    }

    // Dynamic translateY hover translation
    final double translateY = (widget.hover && _isHovered) ? -4.0 : 0.0;

    Widget cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, translateY, 0),
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          highlightColor: Colors.transparent,
          splashColor: widget.onTap != null ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          child: Padding(
            padding: widget.padding,
            child: widget.children,
          ),
        ),
      ),
    );

    if (widget.hover) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

class CardHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CardHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CardTitle({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: style ?? AppTextStyles.h3(isDark: isDark),
    );
  }
}

class CardContent extends StatelessWidget {
  final Widget child;

  const CardContent({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class CardFooter extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CardFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.only(top: 24.0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: padding,
      padding: const EdgeInsets.only(top: 24.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF0F7FF),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}
