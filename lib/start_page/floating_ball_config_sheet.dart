import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../channels.dart';
import '../models/task_entity.dart';
import '../reset_hub.dart';
import 'ball_theme.dart';

/// 悬浮球配置面板（用于首页弹出层）
class FloatingBallConfigSheet extends StatefulWidget {
  const FloatingBallConfigSheet({
    super.key,
    this.showAppBar = true,
    this.onRequestClose,
    this.rootContext,
  });

  final bool showAppBar;
  final VoidCallback? onRequestClose;

  /// 可选：外层 Scaffold / 首页的 context，确保弹窗在最顶层
  final BuildContext? rootContext;

  @override
  State<FloatingBallConfigSheet> createState() => _FloatingBallConfigSheetState();
}

class _FloatingBallConfigSheetState extends State<FloatingBallConfigSheet> {
  int _themeIndex = 0;
  static const double _defaultBallSize = 45;
  static const double _defaultTextSize = 24;

  double _ballSizeDp = _defaultBallSize;

  bool _hasUserInteracted = false;

  static const double _minBallSize = 30;
  static const double _maxBallSize = 60;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _loadSavedBallSize();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(kFloatingBallThemeKey);
    if (savedId == null) return;

    final index = kBallThemes.indexWhere((t) => t.id == savedId);
    if (index != -1 && !_hasUserInteracted) {
      setState(() {
        _themeIndex = index;
      });
    }
  }

  Future<void> _saveCurrentTheme(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTheme = kBallThemes[_themeIndex];
    await prefs.setString(kFloatingBallThemeKey, currentTheme.id);

    final savedSize = await _persistBallSize();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.0,
                ),
              ),
              child: Text(
                '已保存主题：${currentTheme.name}' +
                    (savedSize != null ? ' · 大小 ${savedSize}dp' : ''),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );


    widget.onRequestClose?.call();
    if (widget.onRequestClose == null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _loadSavedBallSize() async {
    try {
      final result = await AutoClickChannels.autoClickChannel
          .invokeMethod<int>('getFloatingBallSize');
      if (result != null && mounted && !_hasUserInteracted) {
        setState(() {
          _ballSizeDp =
              result.toDouble().clamp(_minBallSize, _maxBallSize).toDouble();
        });
      }
    } catch (_) {
      // 忽略异常，维持默认值
    }
  }

  Future<int?> _persistBallSize() async {
    try {
      final result = await AutoClickChannels.autoClickChannel
          .invokeMethod<int>('setFloatingBallSize', {'dp': _ballSizeDp.round()});
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _resetAllConfigs(BuildContext dialogContext) async {
    // 1️⃣ 先让原生把所有悬浮球隐藏掉，避免遮住对话框
    try {
      await AutoClickChannels.autoClickChannel.invokeMethod('hideFloatingDots');
    } catch (_) {}

    // 使用传入的 dialogContext（优先 rootContext），确保对话框在编辑层之上
    final confirm = await showDialog<bool>(
      context: dialogContext,
      useRootNavigator: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ======= 标题 =======
                    const Text(
                      '确认重置',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ======= 内容 =======
                    const Text(
                      '将清空所有任务数据，并恢复悬浮球默认样式和大小。继续吗？',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ======= 按钮行 =======
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 取消按钮（低调的玻璃风格）
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),

                        // 重置按钮（主按钮玻璃风）
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.redAccent.withOpacity(0.55),
                                Colors.redAccent.withOpacity(0.25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  '重置',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      },
    );

    // 2️⃣ 对话框结束后，无论是否重置，都尝试恢复悬浮球显示
    try {
      await AutoClickChannels.autoClickChannel.invokeMethod('showFloatingDots');
    } catch (_) {}

    if (confirm != true || !mounted) return;

    try {
      // 停止当前悬浮球服务
      try {
        await AutoClickChannels.autoClickChannel.invokeMethod('stopFloatingDot');
      } catch (_) {}

      await ResetHub.instance.notifyBeforeDatabaseReset();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kFloatingBallThemeKey, kBallThemes.first.id);

      setState(() {
        _themeIndex = 0;
        _ballSizeDp = _defaultBallSize;
      });

      await _persistBallSize();

      final tasksBox = Hive.box<TaskEntity>('tasks');
      final stepsBox = Hive.box<StepEntity>('steps');
      await tasksBox.clear();
      await stepsBox.clear();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(dialogContext);
      // messenger.showSnackBar(
      //   const SnackBar(content: Text('已重置所有配置并清空数据库')),
      // );

      messenger.showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  '已重置所有配置并清空数据库',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          duration: Duration(seconds: 2),
        ),
      );


      if (Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('重置失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentTheme = kBallThemes[_themeIndex];

    // 优先使用外层 rootContext（首页），保证弹窗层级正确
    final dialogContext = widget.rootContext ?? context;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '预览',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: GradientBall(
                    theme: currentTheme,
                    size: _ballSizeDp,
                    text: '3',
                    defaultSize: _defaultBallSize,
                    defaultTextSize: _defaultTextSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(kBallThemes.length, (index) {
              final item = kBallThemes[index];
              final bool selected = _themeIndex == index;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _hasUserInteracted = true;
                    _themeIndex = index;
                  });
                },
                child: Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: colorScheme.surfaceVariant.withOpacity(0.28),
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary.withOpacity(0.9)
                          : colorScheme.outlineVariant.withOpacity(0.25),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: GradientBall(
                          theme: item,
                          size: 46,
                          text: '3',
                          defaultSize: _defaultBallSize,
                          defaultTextSize: _defaultTextSize,
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text(
            '调整大小',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _ballSizeDp.clamp(_minBallSize, _maxBallSize),
                  min: _minBallSize,
                  max: _maxBallSize,
                  divisions: (_maxBallSize - _minBallSize).round(),
                  label: '${_ballSizeDp.round()}dp',
                  onChanged: (value) {
                    setState(() {
                      _hasUserInteracted = true;
                      _ballSizeDp = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text('${_ballSizeDp.round()}dp'),
            ],
          ),
          const SizedBox(height: 24),
          _ActionButtons(
            onReset: () => _resetAllConfigs(dialogContext),
            showAppBar: widget.showAppBar,
            colorScheme: colorScheme,
          ),
          if (widget.showAppBar) const SizedBox(height: 72),
        ],
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const SizedBox.shrink(),
        ),
        body: content,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SaveFab(
            onSave: () => _saveCurrentTheme(dialogContext),
            colorScheme: colorScheme,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.of(context).size.height * 0.65,
        minWidth: 320,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    widget.onRequestClose?.call();
                    if (widget.onRequestClose == null &&
                        Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(color: colorScheme.outlineVariant.withOpacity(0.5), height: 1),
          Expanded(child: content),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                _ResetButton(
                  onReset: () => _resetAllConfigs(dialogContext),
                  colorScheme: colorScheme,
                ),
                const Spacer(),
                // ✅ 改成磨砂玻璃风格的保存按钮
                // 「保存」按钮（磨砂玻璃 + 更亮更清晰）
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.32),   // ✨ 更明显的玻璃边框
                      width: 1.2,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.55), // ✨ 主色更亮
                        colorScheme.primary.withOpacity(0.28),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.35),  // ✨ 增强发光
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: TextButton.icon(
                        onPressed: () => _saveCurrentTheme(dialogContext),
                        icon: Icon(
                          Icons.check_rounded,
                          color: Colors.white.withOpacity(0.95),  // ✨ 图标更亮
                        ),
                        label: Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.96), // ✨ 文字亮度增强
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: const StadiumBorder(),
                          overlayColor: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onReset,
    required this.showAppBar,
    required this.colorScheme,
  });

  final VoidCallback onReset;
  final bool showAppBar;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (showAppBar) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _ResetButton(onReset: onReset, colorScheme: colorScheme),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onReset, required this.colorScheme});

  final VoidCallback onReset;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),

        // ✨ 玻璃高光边框
        border: Border.all(
          color: Colors.white.withOpacity(0.30),
          width: 1.1,
        ),

        // ✨ 磨砂渐变
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.14),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        // ✨ 让重置按钮也“漂浮”起来
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重置'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              foregroundColor: colorScheme.primary,
              shape: const StadiumBorder(),
              overlayColor: colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveFab extends StatelessWidget {
  const _SaveFab({required this.onSave, required this.colorScheme});

  final VoidCallback onSave;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
        ),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.2),
            colorScheme.primary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: TextButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              foregroundColor: colorScheme.onPrimary,
              backgroundColor: colorScheme.primary.withOpacity(0.9),
              shape: const StadiumBorder(),
              overlayColor: colorScheme.onPrimary.withOpacity(0.08),
            ),
          ),
        ),
      ),
    );
  }
}
