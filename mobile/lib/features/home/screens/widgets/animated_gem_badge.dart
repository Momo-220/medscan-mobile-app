import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/router/router.dart';

/// Animated Gem Badge for the Home Screen header.
/// 
/// Shows the full credit balance (e.g. "💎 30") upon arrival, pauses so the user
/// can read it, then smoothly retracts into an elegant circular token with an inner
/// blue accent ring surrounding the diamond. Replays automatically upon returning
/// from other screens and can be tapped to re-expand at any time.
class AnimatedGemBadge extends ConsumerStatefulWidget {
  final int credits;
  final VoidCallback onTap;

  const AnimatedGemBadge({
    super.key,
    required this.credits,
    required this.onTap,
  });

  @override
  ConsumerState<AnimatedGemBadge> createState() => _AnimatedGemBadgeState();
}

class _AnimatedGemBadgeState extends ConsumerState<AnimatedGemBadge>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  Timer? _collapseTimer;
  Timer? _recollapseTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0, // Start expanded
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    // Initial cycle: hold expanded for 1.8s then smoothly collapse
    _scheduleCollapse(delayMs: 1800);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      homeRouteObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _recollapseTimer?.cancel();
    homeRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  /// Called when the top route has been popped off and this route shows again.
  @override
  void didPopNext() {
    _playExpandCollapseCycle();
  }

  @override
  void didUpdateWidget(covariant AnimatedGemBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.credits != widget.credits && widget.credits > 0) {
      _playExpandCollapseCycle();
    }
  }

  void _scheduleCollapse({required int delayMs}) {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _controller.value > 0.0) {
        _controller.reverse();
      }
    });
  }

  void _playExpandCollapseCycle() {
    _collapseTimer?.cancel();
    _recollapseTimer?.cancel();
    if (!mounted) return;
    _controller.forward();
    _scheduleCollapse(delayMs: 1800);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (_controller.value < 0.5) {
      // Re-expand to show gems count, then re-collapse after 2.5s
      _collapseTimer?.cancel();
      _controller.forward();
      _recollapseTimer?.cancel();
      _recollapseTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) _controller.reverse();
      });
    } else {
      // Already expanded: trigger credits dialog
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, _) {
          final anim = _expandAnimation.value;

          return Container(
            height: 32,
            padding: EdgeInsets.symmetric(
              horizontal: 4.0 + (3.0 * anim),
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Inner blue ring surrounding the diamond icon (requested by user)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2563EB), // Blue circle ring
                      width: 1.5,
                    ),
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  ),
                  child: const Center(
                    child: Text(
                      '💎',
                      style: TextStyle(fontSize: 10, height: 1.0),
                    ),
                  ),
                ),

                // Smoothly folding text portion
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: anim,
                    child: Opacity(
                      opacity: anim.clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 5, right: 3),
                        child: Text(
                          '${widget.credits}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
