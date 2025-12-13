import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/click_task.dart';

class TaskCard extends StatelessWidget {
  final ClickTask task;
  final int index;
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.index,
    required this.isRunning,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {},
      child: Dismissible(
        key: ValueKey(task.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
          ),
        ),
        onDismissed: (_) => onDelete(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                gradient: _rowGradient(),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(isRunning ? 0.28 : 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                  if (isRunning)
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.35),
                      blurRadius: 26,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 14, right: 14, top: 12, bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildTaskTypeIcon(),
                          const SizedBox(width: 10),
                          _buildIndexLabel(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                // color: Colors.white,
                                color: Color(0xFFE5E7EB), // 比纯白更适合磨砂暗背景
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildIndexLabel() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.black.withOpacity(isRunning ? 0.25 : 0.18),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: Colors.white.withOpacity(isRunning ? 0.45 : 0.25),
  //       ),
  //     ),
  //     child: Text(
  //       '#${index + 1}',
  //       style: TextStyle(
  //         color: Colors.white.withOpacity(0.9),
  //         fontSize: 13,
  //         fontWeight: FontWeight.w700,
  //         letterSpacing: 0.2,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildIndexLabel() {
    final bool active = isRunning;

    // 主色（用来做外发光 + 渐变的一端）
    final Color accent = active
        ? const Color(0xFF38BDF8) // 运行中：偏天蓝
        : const Color(0xFF6366F1); // 未运行：偏靛蓝

    // 渐变：编号文字用这个
    final LinearGradient gradient = active
        ? LinearGradient(
      colors: [
        accent,                    // 天蓝
        const Color(0xFFA855F7),   // 紫
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : LinearGradient(
      colors: [
        accent,                    // 靛蓝
        const Color(0xFF22D3EE),   // 青绿
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // 深色磨砂玻璃底
        color: const Color(0xFF020617).withOpacity(0.72),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          // 黑色阴影，增加悬浮感
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          // 轻微彩色外发光（重点）
          BoxShadow(
            color: accent.withOpacity(0.45),
            blurRadius: 18,
            spreadRadius: 0.6,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          // 内部再来一点轻微高光，让玻璃感更明显
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return gradient.createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            '#${index + 1}',
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: Colors.white, // 实际会被 ShaderMask 的渐变覆盖
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTaskTypeIcon() {
    final bool isWorkflow = task.isWorkflow;
    final List<Color> gradientColors = isWorkflow
        ? [
            const Color(0xFFC084FC).withOpacity(0.55),
            Colors.white.withOpacity(0.08),
          ]
        : [
            const Color(0xFF60A5FA).withOpacity(0.55),
            Colors.white.withOpacity(0.08),
          ];

    final iconData = isWorkflow
        ? Icons.auto_graph_rounded
        : Icons.touch_app_rounded;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(isRunning ? 0.42 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: (isWorkflow
                    ? const Color(0xFFC084FC)
                    : const Color(0xFF60A5FA))
                .withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: Colors.white.withOpacity(0.95),
        size: 18,
      ),
    );
  }

  Gradient _rowGradient() {
    if (isRunning) {
      return const LinearGradient(
        colors: [
          Color(0xCC16A34A),
          Color(0xCC15803D),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }

    final bool isEvenRow = index.isEven;
    final List<Color> gradientColors = isEvenRow
        ? [
            const Color(0xFF60A5FA).withOpacity(0.3),
            Colors.white.withOpacity(0.06),
            const Color(0xFF7DD3FC).withOpacity(0.14),
          ]
        : [
            const Color(0xFFC084FC).withOpacity(0.3),
            Colors.white.withOpacity(0.06),
            const Color(0xFFF472B6).withOpacity(0.14),
          ];

    return LinearGradient(
      colors: gradientColors,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }
}
