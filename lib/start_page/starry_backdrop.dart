import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 深邃夜空 + 超多星星（远中近层次 + 四角亮星 + 更均匀分布）
///
/// 直接替换原文件即可使用。
class StarryBackdropPainter extends CustomPainter {
  final int seed;
  final Color color; // 基础星星色
  final int dotCount; // 小星星基数
  final int lineCount; // 星云数量
  final int starCount; // 亮星数量

  const StarryBackdropPainter({
    required this.seed,
    this.color = Colors.white,
    this.dotCount = 60,
    this.lineCount = 9,
    this.starCount = 44,
  });

  /// 星星颜色调色盘（白 / 黄 / 蓝）
  static const List<Color> _starPalette = [
    Color(0xFFF9FAFB), // 近白
    Color(0xFFFDE68A), // 暖黄
    Color(0xFFBFDBFE), // 冷蓝
  ];

  Color _pickStarColor(math.Random random, double opacity) {
    final base = _starPalette[random.nextInt(_starPalette.length)];
    return base.withOpacity(opacity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    _drawDeepNight(canvas, size);                 // 深蓝夜空
    _drawLayeredSmallStars(canvas, size, random); // 多层小星星（远中近，均匀分布）
    _drawNebula(canvas, size, random);            // 星云
    _drawBrightStars(canvas, size, random);       // 亮星（带四角星效果）
  }

  /// 深蓝夜空底色
  void _drawDeepNight(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF01040E),
          Color(0xFF020617),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  /// 小星星（远 / 中 / 近三层 + 更均匀的空间分布）
  void _drawLayeredSmallStars(Canvas canvas, Size size, math.Random random) {
    final int total = dotCount * 50;

    final int farCount = (total * 0.45).round();      // 最远：最小最暗
    final int midCount = (total * 0.35).round();      // 中间层
    final int nearCount = total - farCount - midCount; // 最近：略大略亮

    // 远处星星：非常小、非常暗
    _drawLayerStarsGrid(
      canvas: canvas,
      size: size,
      random: random,
      count: farCount,
      minRadius: 0.08,
      maxRadius: 0.20,
      minOpacity: 0.06,
      maxOpacity: 0.18,
      blurSigma: 0.18,
    );

    // 中距离星星：尺寸 & 亮度适中
    _drawLayerStarsGrid(
      canvas: canvas,
      size: size,
      random: random,
      count: midCount,
      minRadius: 0.16,
      maxRadius: 0.40,
      minOpacity: 0.14,
      maxOpacity: 0.36,
      blurSigma: 0.25,
    );

    // 最近星星：略大、略亮
    _drawLayerStarsGrid(
      canvas: canvas,
      size: size,
      random: random,
      count: nearCount,
      minRadius: 0.26,
      maxRadius: 0.70,
      minOpacity: 0.22,
      maxOpacity: 0.45,
      blurSigma: 0.32,
    );
  }

  /// 单层星星：基于网格的“均匀分布 + 小范围随机”
  void _drawLayerStarsGrid({
    required Canvas canvas,
    required Size size,
    required math.Random random,
    required int count,
    required double minRadius,
    required double maxRadius,
    required double minOpacity,
    required double maxOpacity,
    required double blurSigma,
  }) {
    if (count <= 0) return;

    // 按画布宽高比估算一个比较合适的网格
    final double aspect = size.width / (size.height == 0 ? 1 : size.height);
    int cols = math.max(1, math.sqrt(count * aspect).round());
    int rows = (count / cols).ceil();

    final double cellW = size.width / cols;
    final double cellH = size.height / rows;

    for (int i = 0; i < count; i++) {
      final int row = i ~/ cols;
      final int col = i % cols;

      if (row >= rows) break;

      // 每个格子内部再做一点随机偏移
      final double x = (col + random.nextDouble()) * cellW;
      final double y = (row + random.nextDouble()) * cellH;

      if (x < 0 || x > size.width || y < 0 || y > size.height) {
        continue;
      }

      final double radius =
          minRadius + random.nextDouble() * (maxRadius - minRadius);
      final double opacity =
          minOpacity + random.nextDouble() * (maxOpacity - minOpacity);

      final paint = Paint()
        ..color = _pickStarColor(random, opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  /// 柔和星云（非常淡，只增强空间感）
  void _drawNebula(Canvas canvas, Size size, math.Random random) {
    final int count = lineCount.clamp(3, 14);

    for (int i = 0; i < count; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final double width = 60 + random.nextDouble() * 90;
      final double height = 25 + random.nextDouble() * 45;

      final rect = Rect.fromCenter(center: center, width: width, height: height);

      final double opacity = 0.015 + random.nextDouble() * 0.03;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            _pickStarColor(random, opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.8);
      canvas.translate(-center.dx, -center.dy);

      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }

  /// 前景亮星（部分更大，有明显四角星效果）
  void _drawBrightStars(Canvas canvas, Size size, math.Random random) {
    final int count = starCount.clamp(6, 26);

    for (int i = 0; i < count; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      // 40% 的亮星更大，形状更明显
      final bool isBigStar = random.nextDouble() < 0.4;

      // 核心半径
      final double coreRadius = isBigStar
          ? 1.2 + random.nextDouble() * 1.3    // 大亮星：1.2 ~ 2.5
          : 0.7 + random.nextDouble() * 0.6;   // 小亮星：0.7 ~ 1.3

      final Color core = _pickStarColor(random, 0.95);

      // 外圈光晕（大星更明显）
      final Paint glowPaint = Paint()
        ..color = core.withOpacity(isBigStar ? 0.26 : 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

      canvas.drawCircle(
        center,
        coreRadius * (isBigStar ? 3.2 : 2.2),
        glowPaint,
      );

      // 核心
      canvas.drawCircle(center, coreRadius, Paint()..color = core);

      // 横竖光线
      final double ray = coreRadius * (isBigStar ? 2.4 : 1.6) +
          random.nextDouble() * (isBigStar ? 1.0 : 0.4);

      final Paint rayPaint = Paint()
        ..color = core.withOpacity(0.8)
        ..strokeWidth = isBigStar ? 0.55 : 0.4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(center.dx - ray, center.dy),
        Offset(center.dx + ray, center.dy),
        rayPaint,
      );

      canvas.drawLine(
        Offset(center.dx, center.dy - ray),
        Offset(center.dx, center.dy + ray),
        rayPaint,
      );

      // 斜向光线（只有大亮星有）
      if (isBigStar) {
        final double thinRay = coreRadius * (1.6 + random.nextDouble() * 0.8);

        final Paint thinRayPaint = Paint()
          ..color = core.withOpacity(0.55)
          ..strokeWidth = 0.4
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(center.dx - thinRay, center.dy - thinRay),
          Offset(center.dx + thinRay, center.dy + thinRay),
          thinRayPaint,
        );

        canvas.drawLine(
          Offset(center.dx - thinRay, center.dy + thinRay),
          Offset(center.dx + thinRay, center.dy - thinRay),
          thinRayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarryBackdropPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.color != color ||
        oldDelegate.dotCount != dotCount ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.starCount != starCount;
  }
}
