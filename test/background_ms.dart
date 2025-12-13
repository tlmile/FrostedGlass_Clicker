import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

void main() => runApp(const GlassBgApp());

class GlassBgApp extends StatelessWidget {
  const GlassBgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const GlassBgHome(),
    );
  }
}

class GlassBgHome extends StatefulWidget {
  const GlassBgHome({super.key});

  @override
  State<GlassBgHome> createState() => _GlassBgHomeState();
}

class _GlassBgHomeState extends State<GlassBgHome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grainTicker =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _grainTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.2, -0.35),
                radius: 1.18,
                colors: [
                  Color(0xFF6A5CFF),
                  Color(0xFF14151C),
                ],
              ),
            ),
          ),

          // Glow blobs
          Positioned(
            left: -90,
            top: size.height * 0.22,
            child: const _GlowBlob(d: 240),
          ),
          Positioned(
            right: -110,
            bottom: size.height * 0.08,
            child: const _GlowBlob(d: 280),
          ),

          // Light blur layer (glass feeling)
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Grain / noise layer
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _grainTicker,
                builder: (_, __) {
                  return CustomPaint(
                    painter: _GrainPainter(time: _grainTicker.value),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft glow blob
class _GlowBlob extends StatelessWidget {
  final double d;
  const _GlowBlob({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

/// Grain / noise painter
class _GrainPainter extends CustomPainter {
  final double time;
  _GrainPainter({required this.time});

  final math.Random _rand = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;

    const int dots = 2200; // 👈 噪点密度（想更细腻可以加到 3000）

    for (int i = 0; i < dots; i++) {
      final dx = _rand.nextDouble() * size.width;
      final dy = _rand.nextDouble() * size.height;
      canvas.drawPoints(PointMode.points, [Offset(dx, dy)], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) {
    // 每一帧都刷新，形成轻微动态噪点
    return true;
  }
}
