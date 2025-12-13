import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlassAccentPainter extends CustomPainter {
  final int seed;
  final List<Color> colors;

  GlassAccentPainter({required this.seed, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    for (int i = 0; i < 8; i++) {
      final paint = Paint()
        ..color =
            colors[random.nextInt(colors.length)].withOpacity(0.55)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final delta = Offset(
        (random.nextDouble() - 0.5) * 26,
        (random.nextDouble() - 0.5) * 26,
      );

      canvas.drawLine(start, start + delta, paint);
    }

    for (int i = 0; i < 12; i++) {
      final color = colors[random.nextInt(colors.length)];
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final radius = random.nextDouble() * 1.8 + 0.6;

      final dotPaint = Paint()..color = color.withOpacity(0.72);
      canvas.drawCircle(center, radius, dotPaint);

      final arm = radius * 1.6;
      final starPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center - Offset(arm, 0),
          center + Offset(arm, 0), starPaint);
      canvas.drawLine(center - Offset(0, arm),
          center + Offset(0, arm), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
