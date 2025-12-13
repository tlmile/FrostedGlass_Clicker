import 'package:flutter/material.dart';

class ConfigButton extends StatefulWidget {
  final VoidCallback onTap;

  const ConfigButton({
    super.key,
    required this.onTap,
  });

  @override
  State<ConfigButton> createState() => _ConfigButtonState();
}

class _ConfigButtonState extends State<ConfigButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF60A5FA); // 蓝
    const Color accent2 = Color(0xFFA855F7); // 紫

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF020617).withOpacity(0.72),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accent.withOpacity(0.35),
                blurRadius: 14,
                spreadRadius: 0.6,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [
                      accent,
                      accent2,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
