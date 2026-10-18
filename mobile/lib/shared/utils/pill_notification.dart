import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium floating "Dynamic Island"-style toast shown at the top of the screen.
/// Uses an OverlayEntry (not a SnackBar) so it never collides with the
/// bottom navigation bar or the chat input field.

OverlayEntry? _currentToast;
Timer? _toastTimer;

enum _PillType { success, error, info }

void showPillSuccess(BuildContext context, String message) =>
    _showPill(context, message, _PillType.success);

void showPillError(BuildContext context, String message) =>
    _showPill(context, message, _PillType.error);

void showPillInfo(BuildContext context, String message) =>
    _showPill(context, message, _PillType.info);

void _showPill(BuildContext context, String message, _PillType type) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _toastTimer?.cancel();
  _currentToast?.remove();
  _currentToast = null;

  type == _PillType.error
      ? HapticFeedback.heavyImpact()
      : HapticFeedback.lightImpact();

  final key = GlobalKey<_PillToastState>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PillToast(
      key: key,
      message: message,
      type: type,
      onDismissed: () {
        if (_currentToast == entry) {
          entry.remove();
          _currentToast = null;
        }
      },
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);

  _toastTimer = Timer(
    Duration(seconds: type == _PillType.error ? 4 : 3),
    () => key.currentState?.dismiss(),
  );
}

class _PillToast extends StatefulWidget {
  final String message;
  final _PillType type;
  final VoidCallback onDismissed;

  const _PillToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  @override
  State<_PillToast> createState() => _PillToastState();
}

class _PillToastState extends State<_PillToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  bool _dismissing = false;

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    final (Color accent, IconData icon) = switch (widget.type) {
      _PillType.success => (const Color(0xFF10B981), CupertinoIcons.checkmark_alt),
      _PillType.error => (const Color(0xFFEF4444), CupertinoIcons.exclamationmark),
      _PillType.info => (const Color(0xFF3B82F6), CupertinoIcons.info),
    };

    return Positioned(
      top: topPadding + 8,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * -40),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            ),
          );
        },
        child: Center(
          child: GestureDetector(
            onTap: dismiss,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Builder(
                builder: (context) {
                  final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                  final notificationPill = Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: isAndroid ? 0.96 : 0.88)
                          : Colors.white.withValues(alpha: isAndroid ? 0.98 : 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accent.withValues(alpha: 0.85), accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isAndroid) {
                    return notificationPill;
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: notificationPill,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
