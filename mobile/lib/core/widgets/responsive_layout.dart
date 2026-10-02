import 'package:flutter/material.dart';

/// Helper class providing adaptive metrics, breakpoints, and dynamic clearances
/// for MedScan across all screen sizes (phones, foldables, tablets, Android & iOS).
class AppResponsive {
  /// Tablet breakpoint threshold
  static const double tabletBreakpoint = 600.0;
  
  /// Desktop / Large tablet breakpoint
  static const double desktopBreakpoint = 900.0;

  /// Optimal maximum width for content on tablets/desktops to prevent horizontal stretching
  static const double maxContentWidth = 680.0;

  /// Maximum width for floating navigation bars or bottom sheets on tablets
  static const double maxNavWidth = 520.0;

  /// Returns true if the screen width is considered a tablet or larger
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletBreakpoint;
  }

  /// Returns true if the screen is compact (e.g., iPhone SE, small Android < 375px)
  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 375.0;
  }

  /// Adaptive horizontal padding based on screen size
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) return 32.0;
    if (width >= tabletBreakpoint) return 24.0;
    if (width < 360.0) return 12.0;
    return 16.0;
  }

  /// Exact total height occupied by the custom navigation bar, its margins,
  /// the central floating scan button (+24px offset), and the device bottom safe area.
  static double bottomBarTotalHeight(BuildContext context) {
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final double bottomMargin = safeAreaBottom > 0 ? safeAreaBottom : 16.0;
    // Navigation bar height (85) + central FAB protruding above bar (24) + bottom margin
    return 85.0 + 24.0 + bottomMargin;
  }

  /// Safe bottom spacing to place below scrollable lists or input bars
  /// so that content floats with generous, clean breathing room above the navigation bar.
  static double bottomBarSpacing(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (isKeyboardOpen) {
      // When keyboard is visible, the floating nav bar is hidden; use standard padding
      return 12.0;
    }
    // Provide total bar height + 16px of pristine breathing room
    return bottomBarTotalHeight(context) + 16.0;
  }
}

/// A container that constrains content to an optimal reading width on tablets
/// and centers it cleanly, while taking full width with responsive margins on phones.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
