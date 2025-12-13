import 'dart:ui';

import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final bool isActive;
  final bool isExecuting;
  final String statusMessage;
  final Color accentColor;

  /// 以前用来“开启悬浮点”的回调，现在保留为可选，方便兼容旧调用点
  final VoidCallback? onStart;

  /// 当前主按钮：停止执行（你需求里说要放在原来开启悬浮点的位置）
  final VoidCallback onStop;

  const StatusCard({
    super.key,
    required this.isActive,
    required this.isExecuting,
    required this.statusMessage,
    required this.accentColor,
    this.onStart, // ❗ 不再 required
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5EEAD4).withOpacity(0.22),
                const Color(0xFF818CF8).withOpacity(0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildLeadingIcon(),
              const SizedBox(width: 12),
              Expanded(child: _buildTextContent()),
              const SizedBox(width: 12),
              _buildStopButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    final Color centerColor = isActive ? accentColor : Colors.white;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316),
            const Color(0xFF38BDF8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: centerColor,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE9EEFF),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// ★ 这里就是原来“开启悬浮点”的位置，现在只显示“停止执行”
  Widget _buildStopButton() {
    final bool enabled = isExecuting;

    // 根据 isExecuting 切换按钮的启用状态与样式。
    // 只有正在执行时才可点击停止；否则禁用并显示灰态。
    return TextButton(
      onPressed: enabled ? onStop : null,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? Colors.white : Colors.white54,
        backgroundColor:
            enabled ? const Color(0xFF22C55E).withOpacity(0.9) : Colors.grey.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        '停止执行',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: enabled ? Colors.white : Colors.white54,
        ),
      ),
    );
  }
}
