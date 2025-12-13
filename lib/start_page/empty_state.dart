import 'package:flutter/material.dart';

import 'starry_backdrop.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seed = DateTime.now().millisecondsSinceEpoch;

    return SizedBox(
      height: 230,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StarryBackdropPainter(
                seed: seed,
                dotCount: 10,
                lineCount: 5,
                starCount: 7,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFB347),
                      Color(0xFFFFD18B),
                      Color(0xFFFFE7C2),
                      Color(0xFFFFF7EB),
                    ],
                    stops: [0.08, 0.36, 0.68, 1],
                    center: Alignment.center,
                    radius: 0.88,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '暂无任务',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  // color: Color(#6B7280),
                  color: Color(0xFF6B7280),

                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }
}
