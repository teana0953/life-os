import 'package:flutter/material.dart';

/// An original round, blushing-cheek mascot face — not a reproduction of
/// any existing character. Draws from the active [Theme]'s color scheme so
/// it follows light/dark without hard-coded colors.
class Mascot extends StatelessWidget {
  final double size;

  const Mascot({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(
          faceColor: colorScheme.primary,
          outlineColor: colorScheme.outline,
          blushColor: colorScheme.secondary,
          eyeColor: colorScheme.onPrimary,
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Color faceColor;
  final Color outlineColor;
  final Color blushColor;
  final Color eyeColor;

  _MascotPainter({
    required this.faceColor,
    required this.outlineColor,
    required this.blushColor,
    required this.eyeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - size.shortestSide * 0.04;

    final facePaint = Paint()..color = faceColor;
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.03;
    canvas.drawCircle(center, radius, facePaint);
    canvas.drawCircle(center, radius, outlinePaint);

    // Blush cheeks.
    final blushPaint = Paint()..color = blushColor.withValues(alpha: 0.8);
    final blushRadius = radius * 0.16;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.5, center.dy + radius * 0.15),
      blushRadius,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.5, center.dy + radius * 0.15),
      blushRadius,
      blushPaint,
    );

    // Round eyes.
    final eyePaint = Paint()..color = eyeColor;
    final eyeRadius = radius * 0.09;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.28, center.dy - radius * 0.1),
      eyeRadius,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.28, center.dy - radius * 0.1),
      eyeRadius,
      eyePaint,
    );

    // Simple curved smile.
    final smilePaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round;
    final smileRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.05),
      width: radius * 0.5,
      height: radius * 0.4,
    );
    canvas.drawArc(smileRect, 0.25, 2.6, false, smilePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return faceColor != oldDelegate.faceColor ||
        outlineColor != oldDelegate.outlineColor ||
        blushColor != oldDelegate.blushColor ||
        eyeColor != oldDelegate.eyeColor;
  }
}
