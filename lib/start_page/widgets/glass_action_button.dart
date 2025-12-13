import 'package:flutter/material.dart';

class GlassActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color textColor;

  const GlassActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradientColors,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
