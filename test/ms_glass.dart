import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AutoClickGlassApp());

/// Safe clamp to avoid exceptions when upper < lower.
double safeClamp(double value, double lower, double upper) {
  if (value.isNaN) return lower;
  if (lower.isNaN || upper.isNaN) return lower;
  if (upper < lower) upper = lower;
  return value.clamp(lower, upper).toDouble();
}

class AutoClickGlassApp extends StatelessWidget {
  const AutoClickGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const AutoClickHome(),
    );
  }
}

class AutoClickHome extends StatefulWidget {
  const AutoClickHome({super.key});

  @override
  State<AutoClickHome> createState() => _AutoClickHomeState();
}

class _AutoClickHomeState extends State<AutoClickHome>
    with SingleTickerProviderStateMixin {
  // Auto click (in-app)
  Timer? _timer;
  bool _running = false;
  int _count = 0;
  double _intervalMs = 180;

  // Pulse animation for each tick
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    lowerBound: 0,
    upperBound: 1,
  );

  // Floating ball
  bool _panelOpen = false;
  Offset _ballPos = const Offset(24, 140);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _clampBallToScreen());
  }

  @override
  void dispose() {
    _stop();
    _pulse.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() => _count++);
    _pulse.forward(from: 0);
    HapticFeedback.selectionClick();
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _intervalMs.round().clamp(30, 5000)),
          (_) => _tick(),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _running = false);
  }

  void _toggleRun() => _running ? _stop() : _start();

  void _reset() {
    _stop();
    setState(() => _count = 0);
    HapticFeedback.lightImpact();
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    HapticFeedback.mediumImpact();
  }

  void _clampBallToScreen() {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    const ballSize = 62.0;
    final maxX = math.max(8.0, size.width - ballSize - 8.0);
    final maxY = math.max(8.0, size.height - ballSize - 8.0);

    final dx = safeClamp(_ballPos.dx, 8.0, maxX);
    final dy = safeClamp(_ballPos.dy, 8.0, maxY);
    setState(() => _ballPos = Offset(dx, dy));
  }

  void _snapBall() {
    final size = MediaQuery.sizeOf(context);
    const ballSize = 62.0;

    final maxX = math.max(8.0, size.width - ballSize - 8.0);
    final maxY = math.max(8.0, size.height - ballSize - 8.0);

    var dx = safeClamp(_ballPos.dx, 8.0, maxX);
    var dy = safeClamp(_ballPos.dy, 8.0, maxY);

    // Snap to left/right edge
    final toLeft = dx < size.width / 2;
    dx = toLeft ? 8.0 : maxX;

    setState(() => _ballPos = Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    const panelW = 300.0;
    const panelH = 220.0;
    const ballSize = 62.0;

    // Decide panel side
    final bool openToLeft = (_ballPos.dx + ballSize + 12 + panelW) > size.width;
    final double panelLeft = openToLeft
        ? (_ballPos.dx - 12 - panelW)
        : (_ballPos.dx + ballSize + 12);

    // Safe panel top clamp (fixes your crash)
    final rawTop = _ballPos.dy - (panelH - ballSize) / 2;
    final minTop = 12.0;
    final maxTop = math.max(minTop, size.height - panelH - 12.0);
    final panelTop = safeClamp(rawTop, minTop, maxTop);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.2, -0.35),
                radius: 1.18,
                colors: [Color(0xFF6A5CFF), Color(0xFF14151C)],
              ),
            ),
          ),
          Positioned(left: -90, top: size.height * 0.22, child: const _GlowBlob(d: 240)),
          Positioned(right: -110, bottom: size.height * 0.08, child: const _GlowBlob(d: 280)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AutoClick • Glass Home",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _running ? "Running • ${_intervalMs.round()}ms" : "Stopped • ${_intervalMs.round()}ms",
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.72)),
                  ),
                  const SizedBox(height: 18),

                  Expanded(
                    child: Center(
                      child: _GlassCard(
                        width: 360,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, __) {
                                final t = Curves.easeOut.transform(_pulse.value);
                                final ringScale = 1.0 + 0.06 * t;
                                final ringOpacity = (1.0 - t).clamp(0.0, 1.0);

                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.scale(
                                      scale: ringScale,
                                      child: Container(
                                        width: 168,
                                        height: 168,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            width: 2,
                                            color: Colors.white.withOpacity(0.10 + 0.22 * ringOpacity),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 156,
                                      height: 156,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.06),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$_count',
                                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _GlassButton(
                                    onTap: _toggleRun,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                        const SizedBox(width: 8),
                                        Text(_running ? "Pause" : "Start"),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GlassButton(
                                    onTap: _tick,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.touch_app_rounded),
                                        SizedBox(width: 8),
                                        Text("Tap once"),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _GlassButton(
                              onTap: () {},
                              onLongPress: _reset,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.restart_alt_rounded),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Long press to reset",
                                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, color: Colors.white.withOpacity(0.85)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Slider(
                                    value: _intervalMs,
                                    min: 50,
                                    max: 1000,
                                    divisions: 95,
                                    label: "${_intervalMs.round()}ms",
                                    onChanged: (v) {
                                      setState(() => _intervalMs = v);
                                      if (_running) {
                                        _stop();
                                        _start();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tip：右侧悬浮球可拖动，点击展开控制面板。",
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: _panelOpen ? panelLeft : (openToLeft ? panelLeft + 18 : panelLeft - 18),
            top: panelTop,
            child: IgnorePointer(
              ignoring: !_panelOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _panelOpen ? 1 : 0,
                child: _GlassCard(
                  width: panelW,
                  height: panelH,
                  child: _PanelContent(
                    running: _running,
                    count: _count,
                    intervalMs: _intervalMs,
                    onToggleRun: _toggleRun,
                    onTickOnce: _tick,
                    onReset: _reset,
                    onClose: _togglePanel,
                  ),
                ),
              ),
            ),
          ),

          // Draggable floating ball
          Positioned(
            left: _ballPos.dx,
            top: _ballPos.dy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() => _ballPos += d.delta),
              onPanEnd: (_) => _snapBall(),
              onTap: _togglePanel,
              child: _FloatingBall(running: _running, open: _panelOpen),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final bool running;
  final int count;
  final double intervalMs;
  final VoidCallback onToggleRun;
  final VoidCallback onTickOnce;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const _PanelContent({
    required this.running,
    required this.count,
    required this.intervalMs,
    required this.onToggleRun,
    required this.onTickOnce,
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.white.withOpacity(0.72);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bubble_chart_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Floating Controller",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("Status: ${running ? "Running" : "Stopped"}", style: TextStyle(color: subtle)),
          Text("Count: $count", style: TextStyle(color: subtle)),
          Text("Interval: ${intervalMs.round()} ms", style: TextStyle(color: subtle)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GlassButton(
                  height: 44,
                  onTap: onToggleRun,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      const SizedBox(width: 6),
                      Text(running ? "Pause" : "Start"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassButton(
                  height: 44,
                  onTap: onTickOnce,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded),
                      SizedBox(width: 6),
                      Text("Once"),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GlassButton(
            height: 44,
            onTap: onReset,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restart_alt_rounded),
                SizedBox(width: 6),
                Text("Reset"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "注：autoclick 仅在应用内触发动作（计数/回调），非系统级点击。",
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.62)),
          ),
        ],
      ),
    );
  }
}

class _FloatingBall extends StatefulWidget {
  final bool running;
  final bool open;

  const _FloatingBall({required this.running, required this.open});

  @override
  State<_FloatingBall> createState() => _FloatingBallState();
}

class _FloatingBallState extends State<_FloatingBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rot = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _rot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringOpacity = widget.running ? 0.35 : 0.18;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _rot,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _rot.value * math.pi * 2,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 2,
                          color: Colors.white.withOpacity(ringOpacity),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Icon(
                widget.open
                    ? Icons.dashboard_customize_rounded
                    : (widget.running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;

  const _GlassCard({required this.child, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double height;

  const _GlassButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

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
          colors: [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.0)],
        ),
      ),
    );
  }
}
