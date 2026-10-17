import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom pixel-perfect diagonal capsule pill icon matching the user's exact design:
/// - 45-degree angle
/// - Smooth rounded capsule outline
/// - Center divider line
/// - Subtle light reflection arc in the top chamber
class PillNavIcon extends StatelessWidget {
  final Color color;
  final double size;

  const PillNavIcon({
    super.key,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PillNavIconPainter(color: color),
      ),
    );
  }
}

class _PillNavIconPainter extends CustomPainter {
  final Color color;

  _PillNavIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate 45 degrees counter-clockwise (tilted from top-left to bottom-right)
    canvas.rotate(-math.pi / 4);

    // Proportions matching the reference icon
    const double pillWidth = 9.8;
    const double pillHeight = 21.0;
    const double radius = pillWidth / 2;

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: pillWidth,
        height: pillHeight,
      ),
      const Radius.circular(radius),
    );

    // 1. Draw capsule body outline
    canvas.drawRRect(pillRect, paint);

    // 2. Draw center divider line
    canvas.drawLine(
      const Offset(-pillWidth / 2, 0),
      const Offset(pillWidth / 2, 0),
      paint,
    );

    // 3. Draw small highlight curve in the top-left chamber
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final capCenter = Offset(0, -pillHeight / 2 + radius);
    final highlightRect = Rect.fromCircle(
      center: capCenter,
      radius: 2.3,
    );
    canvas.drawArc(
      highlightRect,
      -math.pi * 0.82,
      math.pi * 0.64,
      false,
      highlightPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillNavIconPainter oldDelegate) => color != oldDelegate.color;
}
