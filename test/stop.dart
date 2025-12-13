import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Compact Square Stop Countdown',
      theme: ThemeData.light(),
      home: const SimulationPage(),
    );
  }
}

// --- 模拟的底层页面 ---
class SimulationPage extends StatelessWidget {
  const SimulationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("底层业务页面 (数据列表)")),
      body: Stack(
        children: [
          // 1. 底层内容
          ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.data_usage),
                title: Text('业务数据行 Item $index'),
                subtitle: const Text('这里是页面原本的内容...'),
              );
            },
          ),

          // 2. 黑色半透明遮罩 (为了突出倒计时)
          Container(color: Colors.black54),

          // 3. 我们的倒计时组件 (默认尺寸 150)
          const Center(
            child: SunCountdownOverlay(
              size: 150,
              seconds: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 封装好的太阳倒计时组件 ---
class SunCountdownOverlay extends StatefulWidget {
  final double size;
  final int seconds;
  final VoidCallback? onFinished;

  const SunCountdownOverlay({
    super.key,
    this.size = 150, // 默认尺寸 150
    this.seconds = 10,
    this.onFinished,
  });

  @override
  State<SunCountdownOverlay> createState() => _SunCountdownOverlayState();
}

class _SunCountdownOverlayState extends State<SunCountdownOverlay>
    with TickerProviderStateMixin {
  late AnimationController _countdownController;
  late AnimationController _pulseController;

  // 颜色配置
  final Color _coreColor = const Color(0xFFFFFDE7); // 数字核心亮白黄
  final Color _haloColor = const Color(0xFFFFB74D); // 光晕橙黄色
  final Color _stopButtonColor = const Color(0xFFE53935); // 方框的亮红色
  final Color _stopIconColor = const Color(0xFFC62828); // 图标的深红色

  @override
  void initState() {
    super.initState();

    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _countdownController.reverse(from: 1.0);
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleReset() {
    // 停止后点击，重新开始倒计时
    _countdownController.reverse(from: 1.0);
    if (!_pulseController.isAnimating) _pulseController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 绘制太阳光晕
          AnimatedBuilder(
            animation: Listenable.merge([_countdownController, _pulseController]),
            builder: (context, child) {
              bool isDone = _countdownController.value == 0;
              if (isDone && _pulseController.isAnimating) {
                _pulseController.stop();
              }
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: MiniSunPainter(
                  pulse: _pulseController.value,
                  progress: _countdownController.value,
                  isDone: isDone,
                  primaryColor: _haloColor,
                  // 增加一个参数，控制停止后中心光晕是否仍然显示橙色
                  showHaloOnStop: true,
                ),
              );
            },
          ),

          // 2. 中间的数字或方形停止按钮
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              int currentSec =
              (_countdownController.value * widget.seconds).ceil();
              bool isDone = _countdownController.value == 0;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: isDone
                    ? _buildStopButton() // 方形停止按钮
                    : Text(
                  "$currentSec",
                  key: ValueKey(currentSec),
                  style: TextStyle(
                    fontSize: widget.size * 0.45,
                    fontWeight: FontWeight.w900,
                    color: _coreColor,
                    shadows: [
                      BoxShadow(color: _haloColor.withOpacity(0.8), blurRadius: 10)
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 构建方形停止按钮
  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _handleReset,
      child: Container(
        // 尺寸略微缩小，使其更精致
        width: widget.size * 0.20, // 缩小尺寸
        height: widget.size * 0.20, // 缩小尺寸
        decoration: BoxDecoration(
          color: _stopButtonColor, // 亮红色
          shape: BoxShape.rectangle, // 核心改成了方形
          borderRadius: BorderRadius.circular(widget.size * 0.08), // 略微圆角
          boxShadow: [
            BoxShadow(
                color: _haloColor.withOpacity(0.7), // 保持周围是橙色光晕
                blurRadius: 10, // 较轻的阴影
                spreadRadius: 3
            )
          ],
        ),
        child: Icon(
          Icons.stop_rounded,
          color: _stopIconColor, // 深红色的停止图标，与背景亮红形成层次感
          size: widget.size * 0.12, // 图标尺寸稍微小一点
        ),
      ),
    );
  }
}

// --- 核心绘制逻辑 ---
class MiniSunPainter extends CustomPainter {
  final double pulse;
  final double progress;
  final bool isDone;
  final Color primaryColor;
  final bool showHaloOnStop;

  MiniSunPainter({
    required this.pulse,
    required this.progress,
    required this.isDone,
    required this.primaryColor,
    this.showHaloOnStop = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. 绘制静态核心 (保持橙黄光晕效果)
    // 如果 isDone 且不需要显示 halo，则减弱 intensity，否则保持光芒
    final double intensity = (!isDone || showHaloOnStop) ?
    0.4 + (1.0 - progress) * 0.6 :
    0.2;

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFDE7).withOpacity(0.9 * intensity),
          primaryColor.withOpacity(0.3 * intensity),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.7));

    canvas.drawCircle(center, maxRadius * 0.7, corePaint);

    // 2. 绘制扩散波纹 (倒计时结束则停止扩散)
    if (isDone) return;

    for (int i = 0; i < 2; i++) {
      double waveProgress = (pulse + i * 0.5) % 1.0;
      double currentRadius = waveProgress * maxRadius;

      double opacity = (1.0 - waveProgress) * intensity;
      opacity = opacity.clamp(0.0, 1.0);

      final Paint wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = maxRadius * 0.1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = primaryColor.withOpacity(opacity * 0.5);

      canvas.drawCircle(center, currentRadius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniSunPainter old) {
    return old.pulse != pulse || old.progress != progress || old.isDone != isDone;
  }
}
