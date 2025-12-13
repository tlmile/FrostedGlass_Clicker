import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 入口方法 —— 用于显示磨砂玻璃点击配置弹窗
Future<void> showClickConfigDialog(
    BuildContext context, {
      required int initialClickCount,
      required int initialIntervalMs,
      bool initialIsRandom = false,
      int? initialRandomMinMs,
      int? initialRandomMaxMs,
      int? initialLoopCount,
      bool? initialLoopInfinite,
      bool showLoopControls = false,
      int? stepNumber,
      Color? stepLabelColor,

      /// ✅ 旧签名（与你 start_page.dart 完全一致）
      required Future<void> Function({
      required int clickCount,
      required int fixedIntervalMs,
      required bool isRandom,
      required int randomMaxMs,
      required int randomMinMs,
      int? loopCount,
      bool? loopInfinite,
      }) onConfirm,
    }) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (ctx) {
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _DraggableDialogWrapper(
              child: _GlassClickConfigDialog(
                initialClickCount: initialClickCount,
                initialIntervalMs: initialIntervalMs,
                initialIsRandom: initialIsRandom,
                initialRandomMinMs: initialRandomMinMs,
                initialRandomMaxMs: initialRandomMaxMs,
                initialLoopCount: initialLoopCount,
                initialLoopInfinite: initialLoopInfinite,
                showLoopControls: showLoopControls,
                stepNumber: stepNumber,
                stepLabelColor: stepLabelColor,
                onConfirm: onConfirm,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 可拖动包装（保持你原来的交互）
class _DraggableDialogWrapper extends StatefulWidget {
  final Widget child;

  const _DraggableDialogWrapper({required this.child});

  @override
  State<_DraggableDialogWrapper> createState() => _DraggableDialogWrapperState();
}

class _DraggableDialogWrapperState extends State<_DraggableDialogWrapper> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset += d.delta),
        child: widget.child,
      ),
    );
  }
}

/// 真正的磨砂玻璃弹窗内容（兼容旧签名最终版）
class _GlassClickConfigDialog extends StatefulWidget {
  final int initialClickCount;
  final int initialIntervalMs;
  final int? initialRandomMinMs;
  final int? initialRandomMaxMs;
  final bool initialIsRandom;
  final int? initialLoopCount;
  final bool? initialLoopInfinite;
  final bool showLoopControls;
  final int? stepNumber;
  final Color? stepLabelColor;

  /// ✅ 旧签名（与你 start_page.dart 完全一致）
  final Future<void> Function({
  required int clickCount,
  required int fixedIntervalMs,
  required bool isRandom,
  required int randomMaxMs,
  required int randomMinMs,
  int? loopCount,
  bool? loopInfinite,
  }) onConfirm;

  const _GlassClickConfigDialog({
    required this.initialClickCount,
    required this.initialIntervalMs,
    required this.initialIsRandom,
    required this.initialRandomMinMs,
    required this.initialRandomMaxMs,
    this.initialLoopCount,
    this.initialLoopInfinite,
    this.showLoopControls = false,
    required this.stepNumber,
    required this.stepLabelColor,
    required this.onConfirm,
  });

  @override
  State<_GlassClickConfigDialog> createState() => _GlassClickConfigDialogState();
}

class _GlassClickConfigDialogState extends State<_GlassClickConfigDialog> {
  late final TextEditingController _clickCountController;
  late final TextEditingController _intervalController;
  late final TextEditingController _randomMinController;
  late final TextEditingController _randomMaxController;
  TextEditingController? _loopCountController;

  bool _isRandom = false;
  bool _loopInfinite = false;
  bool _saving = false;

  // ========= 设计风格 Token（只在本文件内，不依赖外部 theme） =========
  static const _labelColor = Color(0xFF9AA3C7);
  static const _valueColor = Color(0xFFEAF1FF);
  static const _hintColor = Color(0x669AA3C7);
  static const _panelBase = Color(0xFF0E1326);

  static const _accent = Color(0xFF4DA3FF);
  static const _borderMid = Color(0x22FFFFFF);

  static const _radius = 22.0;

  @override
  void initState() {
    super.initState();
    _isRandom = widget.initialIsRandom;

    _clickCountController =
        TextEditingController(text: widget.initialClickCount.toString());
    _intervalController =
        TextEditingController(text: widget.initialIntervalMs.toString());

    _randomMinController = TextEditingController(
      text: (widget.initialRandomMinMs ?? 500).toString(),
    );
    _randomMaxController = TextEditingController(
      text: (widget.initialRandomMaxMs ?? 1500).toString(),
    );

    if (widget.showLoopControls) {
      final loopCount = widget.initialLoopCount;
      final loopInfinite =
          widget.initialLoopInfinite ?? (loopCount != null && loopCount == 0);
      _loopInfinite = loopInfinite;
      _loopCountController = TextEditingController(
        text: loopInfinite
            ? '0'
            : (loopCount ?? widget.initialClickCount).toString(),
      );
    }
  }

  @override
  void dispose() {
    _clickCountController.dispose();
    _intervalController.dispose();
    _randomMinController.dispose();
    _randomMaxController.dispose();
    _loopCountController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 小屏/键盘弹出防溢出
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: _panelBase.withOpacity(0.72),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _borderMid),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                const SizedBox(height: 14),

                _labeled(
                  "点击次数",
                  _GlassField(
                    controller: _clickCountController,
                    hintText: "1",
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(height: 12),

                _labeled("模式", _modeSelector()),
                const SizedBox(height: 12),

                if (!_isRandom) ...[
                  _labeled(
                    "间隔(ms)",
                    _GlassField(
                      controller: _intervalController,
                      hintText: "1000",
                      enabled: !_saving,
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧文字
                      const SizedBox(
                        width: 80, // 保证对齐其它 label
                        child: Text(
                          "间隔(ms)",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),

                      // 右侧输入区域
                      Expanded(
                        child: Row(
                          children: [
                            // 最小值
                            Expanded(
                              child: _GlassField(
                                controller: _randomMinController,
                                hintText: "500",
                                enabled: !_saving,
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "-",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),

                            // 最大值
                            Expanded(
                              child: _GlassField(
                                controller: _randomMaxController,
                                hintText: "1500",
                                enabled: !_saving,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                ],

                if (widget.showLoopControls) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 74,
                        child: Text(
                          "循环次数",
                          style: TextStyle(
                            color: _labelColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _GlassField(
                                controller: _loopCountController!,
                                hintText: "1",
                                enabled: !_saving && !_loopInfinite,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _inlineLoopInfiniteSwitch(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                _actionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final step = widget.stepNumber;
    if (step == null) return const SizedBox.shrink();
    final c = widget.stepLabelColor ?? _accent;

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        "第${step}步",
        style: TextStyle(
          color: c,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Row(
      children: [
        _GlassChip(
          label: "固定间隔",
          selected: !_isRandom,
          enabled: !_saving,
          onTap: () => setState(() => _isRandom = false),
        ),
        const SizedBox(width: 8),
        _GlassChip(
          label: "随机间隔",
          selected: _isRandom,
          enabled: !_saving,
          onTap: () => setState(() => _isRandom = true),
        ),
      ],
    );
  }

  Widget _inlineLoopInfiniteSwitch() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderMid),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.all_inclusive_rounded, color: _accent, size: 18),
              const SizedBox(width: 6),
              Switch(
                value: _loopInfinite,
                activeColor: _accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _loopInfinite = value;
                        }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _GlassSecondaryButton(
          label: "取消",
          enabled: !_saving,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 10),
        _GlassPrimaryButton(
          label: _saving ? "保存中…" : "保存",
          enabled: !_saving,
          onTap: () async {
            if (_saving) return;

            final clickCount = int.tryParse(_clickCountController.text) ?? 1;

            // 固定模式：读 interval
            final intervalMs = int.tryParse(_intervalController.text) ?? 1000;

            // 随机模式：读 min/max，并自动纠正 min<=max
            final minMs = int.tryParse(_randomMinController.text) ?? 500;
            final maxMs = int.tryParse(_randomMaxController.text) ?? 1500;
            final fixedMin = minMs <= maxMs ? minMs : maxMs;
            final fixedMax = minMs <= maxMs ? maxMs : minMs;

            int? loopCount;
            bool? loopInfinite;
            if (widget.showLoopControls) {
              loopInfinite = _loopInfinite;
              loopCount = _loopInfinite
                  ? 0
                  : int.tryParse(_loopCountController?.text ?? '') ?? 1;
            }

            setState(() => _saving = true);
            try {
              // ✅ 关键：兼容旧签名字段映射
              await widget.onConfirm(
                clickCount: clickCount,
                fixedIntervalMs: _isRandom ? 0 : intervalMs,
                isRandom: _isRandom,
                randomMinMs: _isRandom ? fixedMin : 0,
                randomMaxMs: _isRandom ? fixedMax : 0,
                loopCount: loopCount,
                loopInfinite: loopInfinite,
              );
              if (context.mounted) Navigator.pop(context);
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          },
        ),
      ],
    );
  }

  Widget _labeled(String label, Widget field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(
              color: _labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: field),
      ],
    );
  }
}

/// 玻璃输入框（统一字体/颜色/边框/焦点态）
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  const _GlassField({
    required this.controller,
    required this.hintText,
    required this.enabled,
  });

  static const _valueColor = Color(0xFFEAF1FF);
  static const _hintColor = Color(0x669AA3C7);
  static const _borderMid = Color(0x22FFFFFF);
  static const _accent = Color(0xFF4DA3FF);
  static const _fieldRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_fieldRadius);

    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: _valueColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          hintText: hintText,
          hintStyle: const TextStyle(
            color: _hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _borderMid),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _accent, width: 1.2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _borderMid),
          ),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _borderMid),
          ),
        ),
        cursorColor: _accent,
      ),
    );
  }
}

/// 模式选择 Chip（固定/随机）
class _GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _GlassChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  static const _labelColor = Color(0xFF9AA3C7);
  static const _accent = Color(0xFF4DA3FF);
  static const _borderMid = Color(0x22FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _accent.withOpacity(0.28)
                : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: selected ? _accent.withOpacity(0.85) : _borderMid,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 主按钮（保存）
class _GlassPrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _GlassPrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  static const _accent = Color(0xFF4DA3FF);
  static const _btnRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_btnRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: enabled
                  ? [
                _accent.withOpacity(0.92),
                _accent.withOpacity(0.55),
              ]
                  : [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: enabled
                  ? _accent.withOpacity(0.90)
                  : Colors.white.withOpacity(0.10),
            ),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: _accent.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white.withOpacity(0.70),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 次按钮（取消）
class _GlassSecondaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _GlassSecondaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  static const _borderMid = Color(0x22FFFFFF);
  static const _btnRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_btnRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withOpacity(enabled ? 0.06 : 0.04),
            border: Border.all(color: _borderMid),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled
                  ? const Color(0xFFEAF1FF)
                  : const Color(0xFFEAF1FF).withOpacity(0.60),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
            ),
          ),
        ),
      ),
    );
  }
}
