import 'package:flutter/material.dart';

class ServiceStatusPill extends StatelessWidget {
  final bool isActive;

  const ServiceStatusPill({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFFBBF24);
    final bgColor = isActive ? const Color(0xFF064E3B) : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? '悬浮点运行中' : '服务就绪',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
