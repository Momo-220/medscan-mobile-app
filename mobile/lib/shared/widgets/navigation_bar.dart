import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/localization.dart';
import 'pill_nav_icon.dart';

class CustomNavigationBar extends ConsumerStatefulWidget {
  final String currentPath;
  final Widget? mascot;

  const CustomNavigationBar({
    super.key,
    required this.currentPath,
    this.mascot,
  });

  @override
  ConsumerState<CustomNavigationBar> createState() => _CustomNavigationBarState();
}

class _CustomNavigationBarState extends ConsumerState<CustomNavigationBar> {
  late int _currentIndex;
  int _hoveredIndex = 0;
  bool _isDragging = false;
  double? _dragPositionX;

  int _resolveIndex(String path) {
    if (path == '/chat') return 1;
    if (path == '/pharmacy' || path == '/history') return 2;
    if (path == '/settings') return 3;
    return 0; // Default to /home
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _resolveIndex(widget.currentPath);
    _hoveredIndex = _currentIndex;
  }

  @override
  void didUpdateWidget(covariant CustomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      final resolved = _resolveIndex(widget.currentPath);
      if (resolved != _currentIndex) {
        setState(() {
          _currentIndex = resolved;
          _hoveredIndex = resolved;
        });
      }
    }
  }

  void _navigateToTab(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/pharmacy');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _hoveredIndex = index;
      });
      HapticFeedback.lightImpact();
      _navigateToTab(index);
    }
  }

  void _handleTapDown(TapDownDetails details, double tabWidth) {
    final touchedIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
    _hoveredIndex = touchedIndex;
  }

  void _handleTapUp(TapUpDetails details, double tabWidth) {
    final touchedIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
    _onTabSelected(touchedIndex);
  }

  void _handleDragStart(DragStartDetails details, double tabWidth) {
    final touchedIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
    setState(() {
      _isDragging = true;
      _dragPositionX = details.localPosition.dx;
      _hoveredIndex = touchedIndex;
    });
    HapticFeedback.selectionClick();
  }

  void _handleDragUpdate(DragUpdateDetails details, double tabWidth) {
    final newHovered = (details.localPosition.dx / tabWidth).floor().clamp(0, 3);
    if (newHovered != _hoveredIndex) {
      _hoveredIndex = newHovered;
      HapticFeedback.selectionClick();
    }
    setState(() {
      _dragPositionX = details.localPosition.dx;
    });
  }

  void _handleDragEnd() {
    if (!_isDragging) return;
    final targetIndex = _hoveredIndex;
    setState(() {
      _isDragging = false;
      _dragPositionX = null;
      _currentIndex = targetIndex;
    });
    HapticFeedback.lightImpact();
    _navigateToTab(targetIndex);
  }

  void _handleDragCancel() {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _dragPositionX = null;
      _hoveredIndex = _currentIndex;
    });
  }

  Widget _wrapWithCapsule({required Widget child, required bool isAndroid}) {
    if (isAndroid) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;

    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final double bottomMargin = safeAreaBottom > 0 ? safeAreaBottom + 8.0 : 20.0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final double horizontalMargin = screenWidth < 360 ? 12.0 : (screenWidth < 400 ? 16.0 : 20.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalMargin,
            right: horizontalMargin,
            bottom: bottomMargin,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Frosted Glassmorphism Floating Capsule (Optimized on Android for 60/120fps with zero saveLayer)
              _wrapWithCapsule(
                isAndroid: isAndroid,
                child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF1E293B).withValues(alpha: isAndroid ? 0.94 : 0.65),
                                const Color(0xFF0F172A).withValues(alpha: isAndroid ? 0.94 : 0.55),
                              ]
                            : [
                                Colors.white.withValues(alpha: isAndroid ? 0.96 : 0.72),
                                Colors.white.withValues(alpha: isAndroid ? 0.96 : 0.48),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.40)
                              : const Color(0xFF1E293B).withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double totalWidth = constraints.maxWidth;
                        final double tabWidth = totalWidth / 4;
                        final double basePillWidth = (tabWidth * 0.86).clamp(48.0, 60.0);
                        final double pillWidth = _isDragging ? (basePillWidth + 6.0) : basePillWidth;
                        const double pillHeight = 48.0;

                        double getPillLeftForIndex(int idx) {
                          return (idx * tabWidth) + (tabWidth - pillWidth) / 2;
                        }

                        final double minLeft = getPillLeftForIndex(0);
                        final double maxLeft = getPillLeftForIndex(3);

                        double pillLeft;
                        if (_isDragging && _dragPositionX != null) {
                          final double rawLeft = _dragPositionX! - (pillWidth / 2);
                          if (rawLeft < minLeft) {
                            pillLeft = minLeft - (minLeft - rawLeft) * 0.22;
                          } else if (rawLeft > maxLeft) {
                            pillLeft = maxLeft + (rawLeft - maxLeft) * 0.22;
                          } else {
                            pillLeft = rawLeft;
                          }
                        } else {
                          pillLeft = getPillLeftForIndex(_currentIndex);
                        }

                        final double pillTop = (constraints.maxHeight - pillHeight) / 2;
                        final int activeIndex = _isDragging ? _hoveredIndex : _currentIndex;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => _handleTapDown(details, tabWidth),
                          onTapUp: (details) => _handleTapUp(details, tabWidth),
                          onHorizontalDragStart: (details) => _handleDragStart(details, tabWidth),
                          onHorizontalDragUpdate: (details) => _handleDragUpdate(details, tabWidth),
                          onHorizontalDragEnd: (_) => _handleDragEnd(),
                          onHorizontalDragCancel: _handleDragCancel,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // 1. Fluid Sliding & Dragging Active Pill Indicator
                              AnimatedPositioned(
                                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 320),
                                curve: Curves.fastOutSlowIn,
                                left: pillLeft,
                                top: pillTop,
                                width: pillWidth,
                                height: pillHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: _isDragging ? 0.50 : 0.38),
                                        blurRadius: _isDragging ? 18 : 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 2. Navigation Items Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNavTab(
                                      context: context,
                                      index: 0,
                                      activeIndex: activeIndex,
                                      isDragging: _isDragging,
                                      inactiveIcon: CupertinoIcons.house,
                                      activeIcon: CupertinoIcons.house_fill,
                                      tooltip: ref.t('dashboard'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildNavTab(
                                      context: context,
                                      index: 1,
                                      activeIndex: activeIndex,
                                      isDragging: _isDragging,
                                      inactiveIcon: CupertinoIcons.chat_bubble_2,
                                      activeIcon: CupertinoIcons.chat_bubble_2_fill,
                                      tooltip: ref.t('chatbot'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildNavTab(
                                      context: context,
                                      index: 2,
                                      activeIndex: activeIndex,
                                      isDragging: _isDragging,
                                      customIconBuilder: (color) => PillNavIcon(color: color, size: 24),
                                      tooltip: ref.t('pharmacy'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildNavTab(
                                      context: context,
                                      index: 3,
                                      activeIndex: activeIndex,
                                      isDragging: _isDragging,
                                      inactiveIcon: CupertinoIcons.gear_alt,
                                      activeIcon: CupertinoIcons.gear_alt_fill,
                                      tooltip: ref.t('settings'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Mascot (if present)
              if (widget.mascot != null)
                Positioned(
                  left: 12,
                  bottom: 56,
                  child: IgnorePointer(
                    child: widget.mascot!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required BuildContext context,
    required int index,
    required int activeIndex,
    required bool isDragging,
    IconData? inactiveIcon,
    IconData? activeIcon,
    Widget Function(Color color)? customIconBuilder,
    required String tooltip,
  }) {
    final bool isSelected = activeIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const activeColor = Colors.white;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: double.infinity,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? (isDragging ? 1.15 : 1.08) : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: customIconBuilder != null
                ? customIconBuilder(isSelected ? activeColor : inactiveColor)
                : Icon(
                    isSelected ? (activeIcon ?? inactiveIcon!) : (inactiveIcon ?? activeIcon!),
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
