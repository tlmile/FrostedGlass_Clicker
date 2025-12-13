// Combined fixed Dart file for AutoClick start page + floating ball config.
// You can split this back into multiple files if needed.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../channels.dart';
import '../models/click_task.dart';
import '../models/task_entity.dart';
import '../models/step_identifier.dart';
import '../reset_hub.dart';
import '../start_page/empty_state.dart';
import '../start_page/status_card.dart';
import '../start_page/task_card.dart';
import '../start_page/starry_backdrop.dart';

const String kFloatingBallThemeKey = 'floating_ball_theme_id';

/// 定位喵球主题配置
class BallTheme {
  final String id; // 用来保存到本地 & 传给原生
  final String name; // 显示的名称
  final List<Color> colors; // 渐变颜色 [中心色, 外圈色]
  final Color textColor; // 数字颜色

  const BallTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.textColor,
  });
}

const List<BallTheme> kBallThemes = [
  BallTheme(
    id: 'tech_blue',
    name: '科技蓝',
    colors: [
      Color(0xFF4DA8FF), // 中心亮蓝
      Color(0xFF0052CC), // 外圈深蓝
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'morandi_green',
    name: '莫兰迪绿',
    colors: [
      Color(0xFFD8E6D3),
      Color(0xFF6C8A73),
    ],
    textColor: Color(0xFF2B2A2A),
  ),
  BallTheme(
    id: 'coral',
    name: '珊瑚粉',
    colors: [
      Color(0xFFFFD6D6),
      Color(0xFFFF6F6F),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'bright_yellow',
    name: '亮黄',
    colors: [
      Color(0xFFFFF7B2),
      Color(0xFFFFD600),
    ],
    textColor: Color(0xFF2B2A2A),
  ),
  BallTheme(
    id: 'dark_gray',
    name: '暗夜灰',
    colors: [
      Color(0xFF4A4A4A),
      Color(0xFF1E1E1E),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'neon_purple',
    name: '霓虹紫',
    colors: [
      Color(0xFFE0C3FC),
      Color(0xFF8E2DE2),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'cyan',
    name: '青色',
    colors: [
      Color(0xFFB2FEFA),
      Color(0xFF0ED2F7),
    ],
    textColor: Color(0xFF034057),
  ),
  BallTheme(
    id: 'soft_orange',
    name: '柔和橙',
    colors: [
      Color(0xFFFFE0B2),
      Color(0xFFFF9800),
    ],
    textColor: Color(0xFF4A2C00),
  ),
];

class FloatingBallConfigPage extends StatefulWidget {
  const FloatingBallConfigPage({
    super.key,
    this.showAppBar = true,
    this.onRequestClose,
    this.rootContext,
  });

  final bool showAppBar;
  final VoidCallback? onRequestClose;

  /// 用于在弹出层中仍然能使用首页 / Scaffold 的 context 弹对话框
  final BuildContext? rootContext;

  @override
  State<FloatingBallConfigPage> createState() => _FloatingBallConfigPageState();
}

class _FloatingBallConfigPageState extends State<FloatingBallConfigPage> {
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
        content: Text(
          '已保存主题：${currentTheme.name}' +
              (savedSize != null ? ' · 大小 ${savedSize}dp' : ''),
        ),
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
        return AlertDialog(
          title: const Text('确认重置'),
          content: const Text('将清空所有任务数据，并恢复悬浮球默认样式和大小。继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('重置'),
            ),
          ],
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
        maxHeight: MediaQuery.of(context).size.height * 0.82,
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
                ElevatedButton.icon(
                  onPressed: () => _saveCurrentTheme(dialogContext),
                  style: ElevatedButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 6,
                    shadowColor: colorScheme.primary.withOpacity(0.45),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.14),
            Colors.white.withOpacity(0.07),
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

/// 渐变球组件（大数字 + 字体阴影）
class GradientBall extends StatelessWidget {
  final BallTheme theme;
  final double size;
  final String text;
  final double defaultSize;
  final double defaultTextSize;

  const GradientBall({
    super.key,
    required this.theme,
    this.size = 60,
    this.text = '3',
    this.defaultSize = 45,
    this.defaultTextSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = size >= defaultSize
        ? defaultTextSize
        : defaultTextSize * (size / defaultSize);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: theme.colors,
          center: Alignment.center,
          radius: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: theme.textColor,
          shadows: const [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 3,
              color: Colors.black38,
            ),
            Shadow(
              offset: Offset(-1, -1),
              blurRadius: 3,
              color: Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// StartPage 及相关组件
/// =========================

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _isFloatingEnabled = false;
  bool _isExecuting = false;
  String _statusMessage = '定位喵球未开启';
  BallTheme _currentBallTheme = kBallThemes.first;

  /// 当前运行中的悬浮球对应的任务 id（用于删除时关闭）
  String? _runningTaskId;
  String? _executingTaskId;

  late Box<TaskEntity> _tasksBox;
  late Box<StepEntity> _stepsBox;
  bool _hiveReady = false;

  /// 已保存的任务列表
  final List<ClickTask> _tasks = [];

  InputDecorationTheme _frostedInputDecorationTheme() {
    return InputDecorationTheme(
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF22C55E),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
    );
  }

  InputDecoration _buildGlassInputDecoration({
    String? hintText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
    ).applyDefaults(_frostedInputDecorationTheme());
  }

  @override
  void initState() {
    super.initState();
    _initHiveAndLoad();
    _loadCurrentBallTheme();
    ResetHub.instance.registerListener(_onBeforeFullReset);
  }

  @override
  void dispose() {
    ResetHub.instance.unregisterListener(_onBeforeFullReset);
    super.dispose();
  }

  Future<void> _loadCurrentBallTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(kFloatingBallThemeKey);

    final resolvedTheme = savedId == null
        ? kBallThemes.first
        : kBallThemes.firstWhere(
          (theme) => theme.id == savedId,
      orElse: () => kBallThemes.first,
    );

    setState(() {
      _currentBallTheme = resolvedTheme;
    });
  }

  Future<void> _onBeforeFullReset() async {
    if (_isExecuting) {
      await _stopExecution();
    }
    if (_isFloatingEnabled) {
      await _stopFloatingDot();
    }

    setState(() {
      _tasks.clear();
      _runningTaskId = null;
      _executingTaskId = null;
      _isExecuting = false;
      _statusMessage = '定位喵球未开启';
    });
  }

  String _buildDefaultTaskName(bool isWorkflow) {
    if (isWorkflow) {
      final wfCount = _tasks.where((t) => t.isWorkflow).length + 1;
      return 'workflow#$wfCount';
    } else {
      final singleCount = _tasks.where((t) => !t.isWorkflow).length + 1;
      return 'singleclick#$singleCount';
    }
  }

  String _buildFloatingId(String taskId, int stepIndex) {
    return '${taskId}_$stepIndex';
  }

  Widget _buildGlassTitle(TextTheme theme) {
    final baseStyle = theme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      color: Colors.white,
    );

    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFF91B6FF),
            Color(0xFF7AE0FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        'AutoClick',
        style: baseStyle,
      ),
    );
  }

  Future<void> _initHiveAndLoad() async {
    _tasksBox = Hive.box<TaskEntity>('tasks');
    _stepsBox = Hive.box<StepEntity>('steps');
    _hiveReady = true;
    await _reloadTasksFromHive();
  }

  int _nextListIndex() {
    if (!_hiveReady || _tasksBox.isEmpty) {
      return _tasks.length;
    }
    return _tasksBox.values
        .map((e) => e.listIndex)
        .fold<int>(0, math.max) +
        1;
  }

  List<StepEntity> _loadSteps(String taskId) {
    if (!_hiveReady) return [];
    final steps =
    _stepsBox.values.where((element) => element.taskId == taskId).toList();
    steps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    return steps;
  }

  Future<void> _reloadTasksFromHive({String? runningTaskId}) async {
    if (!_hiveReady) return;
    final entities = _tasksBox.values.toList()
      ..sort((a, b) => b.listIndex.compareTo(a.listIndex));

    final restored = <ClickTask>[];
    for (final entity in entities) {
      restored.add(entity.toClickTask(_loadSteps(entity.taskId)));
    }

    setState(() {
      _tasks
        ..clear()
        ..addAll(restored);
      _runningTaskId = runningTaskId ?? _runningTaskId;
    });
  }

  /// 弹出输入框要求用户填写任务名称，返回有效名称或 null
  Future<String?> _promptForTaskName({required bool isWorkflow}) async {
    final controller = TextEditingController(
      text: _buildDefaultTaskName(isWorkflow),
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 22,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '输入任务名',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildGlassInputDecoration(
                              hintText:
                              isWorkflow ? '例如：我的工作流' : '例如：单击任务',
                              errorText: errorText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                ),
                                child: const Text('取消'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  final trimmed = controller.text.trim();
                                  if (trimmed.isEmpty) {
                                    // 保持对话框打开并提示错误，确保用户提供有效名称
                                    setState(() {
                                      errorText = '任务名不能为空';
                                    });
                                    return;
                                  }
                                  Navigator.of(context).pop(trimmed);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF22C55E).withOpacity(0.9),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  '确定',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
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
              ),
            );
          },
        );
      },
    );
  }

  // 其余所有与 Hive / 执行 / 原生回调相关的方法，完全保持你原来的逻辑
  // 这里只是从你提供的代码原样搬过来，未做改动（除 _openFloatingBallConfigDialog）

  Future<void> _persistSingleClickTask({
    required String finalId,
    required String finalName,
    String? description,
    required int? x,
    required int? y,
    required int clickCount,
    required bool isRandom,
    required int? fixedIntervalMs,
    required int? randomMinMs,
    required int? randomMaxMs,
  }) async {
    if (!_hiveReady) return;

    final existing = _tasksBox.get(finalId);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = finalId
      ..taskType = 1
      ..listIndex = existing?.listIndex ?? _nextListIndex()
      ..name = finalName
      ..description = description ?? existing?.description
      ..createdAt = existing?.createdAt ?? DateTime.now()
      ..posX = x
      ..posY = y
      ..clickCount = clickCount
      ..isRandom = isRandom
      ..fixedIntervalMs = fixedIntervalMs
      ..randomMinMs = randomMinMs
      ..randomMaxMs = randomMaxMs;

    await _tasksBox.put(finalId, entity);

    // 单击任务时，删除同 taskId 的旧步骤数据
    final keysToDelete = _stepsBox.keys
        .where((key) => _stepsBox.get(key)?.taskId == finalId)
        .toList();
    await _stepsBox.deleteAll(keysToDelete);
  }

  Future<void> _persistWorkflowStep({
    required String finalId,
    required String finalName,
    String? description,
    required WorkflowStep step,
  }) async {
    if (!_hiveReady) return;

    final existing = _tasksBox.get(finalId);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = finalId
      ..taskType = 2
      ..listIndex = existing?.listIndex ?? _nextListIndex()
      ..name = finalName
      ..description = description ?? existing?.description
      ..createdAt = existing?.createdAt ?? DateTime.now()
      ..posX = null
      ..posY = null
      ..clickCount = null
      ..isRandom = null
      ..fixedIntervalMs = null
      ..randomMinMs = null
      ..randomMaxMs = null;

    await _tasksBox.put(finalId, entity);

    final isFirstStep = step.index == 1;

    final loopValue = isFirstStep
        ? (step.loopInfinite == true
        ? 0
        : (step.loopCount == null ? null : step.loopCount))
        : null;

    final stepEntity = StepEntity()
      ..taskId = finalId
      ..stepNumber = step.index
      ..posX = step.posX ?? 0
      ..posY = step.posY ?? 0
      ..clickCount = step.clickCount
      ..isRandom = step.isRandom
      ..fixedIntervalMs = step.fixedIntervalMs
      ..randomMinMs = step.randomMinMs
      ..randomMaxMs = step.randomMaxMs
      ..floatingId = step.floatingId ?? _buildFloatingId(finalId, step.index)
      ..loopCount = loopValue;

    await _stepsBox.put('${finalId}_${step.index}', stepEntity);
  }

  Future<void> _executeSingleFromHive(String taskId) async {
    if (!_hiveReady) return;
    final entity = _tasksBox.get(taskId);
    if (entity == null || entity.posX == null || entity.posY == null) {
      return;
    }

    final args = <String, Object?>{
      'taskId': entity.taskId,
      'x': entity.posX,
      'y': entity.posY,
      'clickCount': entity.clickCount ?? 1,
      'isRandom': entity.isRandom ?? false,
      if (entity.fixedIntervalMs != null)
        'fixedIntervalMs': entity.fixedIntervalMs,
      if (entity.randomMinMs != null) 'randomMinMs': entity.randomMinMs,
      if (entity.randomMaxMs != null) 'randomMaxMs': entity.randomMaxMs,
    };

    await AutoClickChannels.autoClickChannel
        .invokeMethod('executeSingleTask', args);
  }

  Future<void> _executeWorkflowFromHive(String taskId) async {
    if (!_hiveReady) return;
    final entity = _tasksBox.get(taskId);
    if (entity == null) return;

    final steps = _loadSteps(taskId);
    if (steps.isEmpty) return;

    final payload = <Map<String, Object?>>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final displayNumber = i + 1;
      payload.add({
        'x': s.posX,
        'y': s.posY,
        'index': s.stepNumber,
        'displayNumber': displayNumber,
        'stepIndex': s.stepNumber,
        'floatingId': s.floatingId ?? _buildFloatingId(taskId, s.stepNumber),
        'clickCount': s.clickCount,
        'isRandom': s.isRandom,
        if (s.fixedIntervalMs != null) 'fixedIntervalMs': s.fixedIntervalMs,
        if (s.randomMinMs != null) 'randomMinMs': s.randomMinMs,
        if (s.randomMaxMs != null) 'randomMaxMs': s.randomMaxMs,
        if (i == 0 && s.loopCount != null) 'loopCount': s.loopCount,
        if (i == 0 && s.loopCount != null)
          'loopInfinite': s.loopCount == 0,
      });
    }

    final int? loopCount = steps.isNotEmpty ? steps.first.loopCount : null;

    final args = <String, Object?>{
      'taskId': entity.taskId,
      'steps': payload,
    };
    if (loopCount != null) {
      args['loopCount'] = loopCount;
      args['loopInfinite'] = loopCount == 0;
    }

    debugPrint(
        '[ConfigPage] executeWorkflow task=${entity.taskId} loopCount=$loopCount loopInfinite=${loopCount == 0} steps=${payload.length}');

    await AutoClickChannels.autoClickChannel.invokeMethod('executeWorkflow', args);
  }

  Future<void> _persistWorkflowShell(ClickTask task) async {
    if (!_hiveReady) return;
    final existing = _tasksBox.get(task.id);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = task.id
      ..taskType = 2
      ..listIndex = existing?.listIndex ?? _nextListIndex()
      ..name = task.name
      ..description = task.description
      ..createdAt = existing?.createdAt ?? task.createdAt
      ..posX = null
      ..posY = null
      ..clickCount = null
      ..isRandom = null
      ..fixedIntervalMs = null
      ..randomMinMs = null
      ..randomMaxMs = null;
    await _tasksBox.put(task.id, entity);
  }

  /// 处理原生回调（悬浮球配置保存）
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
    // 由安卓端主动回传的“执行开始”事件，用于切换按钮可用状态
      case 'onExecutionStarted':
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);
        final String? taskId = map['taskId'] as String?;

        setState(() {
          _isExecuting = true;
          _executingTaskId = taskId;
          _statusMessage = '正在执行任务';
        });
        return null;

    // 由安卓端主动回传的“执行结束”事件（包含完成/被停止），重置执行状态
      case 'onExecutionFinished':
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);
        final String? reason = map['reason'] as String?;

        setState(() {
          _isExecuting = false;
          _executingTaskId = null;
          _statusMessage = reason == 'stopped' ? '已停止执行' : '执行完成';
        });
        return null;

      case 'onFloatingDotMoved':
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);
        final taskId = (map['taskId'] as String?) ?? _runningTaskId;
        final bool isWorkflow = (map['isWorkflow'] as bool?) ?? false;
        final int? stepIndex = (map['stepIndex'] as num?)?.toInt();
        final int? x = (map['x'] as num?)?.toInt();
        final int? y = (map['y'] as num?)?.toInt();

        if (taskId == null || x == null || y == null) {
          return null;
        }

        setState(() {
          final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
          if (taskIndex == -1) return;

          final task = _tasks[taskIndex];
          if (isWorkflow && stepIndex != null) {
            final steps = [...task.workflowSteps];
            final existing =
            steps.indexWhere((s) => s.index == stepIndex);
            if (existing != -1) {
              steps[existing] =
                  steps[existing].copyWith(posX: x, posY: y);
            } else {
              steps.add(
                WorkflowStep(
                  index: stepIndex,
                  posX: x,
                  posY: y,
                  floatingId: _buildFloatingId(taskId, stepIndex),
                ),
              );
            }
            steps.sort((a, b) => a.index.compareTo(b.index));
            _tasks[taskIndex] = task.copyWith(
              workflowSteps: steps,
              posX: null,
              posY: null,
            );
          } else {
            _tasks[taskIndex] = task.copyWith(posX: x, posY: y);
          }
        });

        if (_hiveReady) {
          if (isWorkflow && stepIndex != null) {
            dynamic matchedKey;
            for (final key in _stepsBox.keys) {
              final entity = _stepsBox.get(key);
              if (entity?.taskId == taskId &&
                  entity?.stepNumber == stepIndex) {
                matchedKey = key;
                break;
              }
            }

            final entity = (matchedKey != null
                ? _stepsBox.get(matchedKey)
                : StepEntity()) ??
                StepEntity()
                  ..taskId = taskId
                  ..stepNumber = stepIndex
                  ..clickCount = 1
                  ..isRandom = false;

            entity
              ..posX = x
              ..posY = y
              ..taskId = taskId
              ..stepNumber = stepIndex
              ..clickCount = entity.clickCount ?? 1
              ..isRandom = entity.isRandom ?? false
              ..floatingId =
                  entity.floatingId ?? _buildFloatingId(taskId, stepIndex);

            await _stepsBox.put(
                matchedKey ?? '${taskId}_$stepIndex', entity);
          } else {
            final entity = _tasksBox.get(taskId);
            if (entity != null) {
              entity
                ..posX = x
                ..posY = y;
              await _tasksBox.put(taskId, entity);
            }
          }
        }

        return null;

      case 'onFloatingConfigSaved':
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);

        final bool executeAfterSave =
            (map['executeAfterSave'] as bool?) ?? false;

        final String? taskId = map['taskId'] as String?;
        final bool isWorkflow = (map['isWorkflow'] as bool?) ?? false;

        final String? rawName = map['name'] as String?;
        final String? trimmed = rawName?.trim();

        ClickTask? existing;
        if (taskId != null) {
          try {
            existing = _tasks.firstWhere((t) => t.id == taskId);
          } catch (_) {
            existing = null;
          }
        }

        late final String finalName;
        if (trimmed != null && trimmed.isNotEmpty) {
          finalName = trimmed;
        } else if (existing != null &&
            existing.name.trim().isNotEmpty) {
          finalName = existing.name;
        } else {
          finalName = _buildDefaultTaskName(isWorkflow);
        }

        final String? description = map['description'] as String?;
        final String? themeId = map['themeId'] as String?;

        final int? x = (map['x'] as num?)?.toInt();
        final int? y = (map['y'] as num?)?.toInt();
        final int clickCount =
            (map['clickCount'] as num?)?.toInt() ?? 1;
        final bool isRandom =
            (map['isRandom'] as bool?) ?? false;
        final int? fixedIntervalMs =
        (map['fixedIntervalMs'] as num?)?.toInt();
        final int? randomMinMs =
        (map['randomMinMs'] as num?)?.toInt();
        final int? randomMaxMs =
        (map['randomMaxMs'] as num?)?.toInt();

        final int? loopCount =
        (map['loopCount'] as num?)?.toInt();
        final bool? loopInfinite =
        map['loopInfinite'] as bool?;

        // 先确定 finalId
        final String finalId =
            taskId ?? DateTime.now().millisecondsSinceEpoch.toString();

// 再确定 stepIndex
        int stepIndex;
        final num? rawStepIndex = map['stepIndex'] as num?;
        if (rawStepIndex != null) {
          stepIndex = rawStepIndex.toInt();
        } else if (isWorkflow) {
          if (_hiveReady) {
            final existingSteps = _loadSteps(finalId);
            if (existingSteps.isEmpty) {
              stepIndex = 1;
            } else {
              final maxStepNumber = existingSteps
                  .map((e) => e.stepNumber)
                  .fold<int>(0, math.max);
              stepIndex = maxStepNumber + 1;
            }
          } else if (existing != null) {
            final existingIndexes =
            existing.workflowSteps.map((s) => s.index).toList();
            if (existingIndexes.isEmpty) {
              stepIndex = 1;
            } else {
              stepIndex = existingIndexes.reduce(math.max) + 1;
            }
          } else {
            stepIndex = 1;
          }
        } else {
          // 单任务：stepIndex 统一用 1
          stepIndex = 1;
        }

        final String? floatingId =
            (map['floatingId'] as String?) ??
                _buildFloatingId(finalId, stepIndex);

        WorkflowStep? existingStep;
        if (existing != null) {
          try {
            existingStep = existing.workflowSteps
                .firstWhere((step) => step.index == stepIndex);
          } catch (_) {
            existingStep = null;
          }
        }

        final bool isFirstStep = stepIndex == 1;

        final step = WorkflowStep(
          index: stepIndex,
          posX: x ?? existingStep?.posX,
          posY: y ?? existingStep?.posY,
          clickCount: map.containsKey('clickCount')
              ? clickCount
              : (existingStep?.clickCount ?? clickCount),
          isRandom: map.containsKey('isRandom')
              ? isRandom
              : (existingStep?.isRandom ?? isRandom),
          fixedIntervalMs: map.containsKey('fixedIntervalMs')
              ? fixedIntervalMs
              : existingStep?.fixedIntervalMs,
          randomMinMs: map.containsKey('randomMinMs')
              ? randomMinMs
              : existingStep?.randomMinMs,
          randomMaxMs: map.containsKey('randomMaxMs')
              ? randomMaxMs
              : existingStep?.randomMaxMs,
          loopCount: isFirstStep
              ? (map.containsKey('loopCount')
              ? loopCount
              : existingStep?.loopCount)
              : existingStep?.loopCount,
          loopInfinite: isFirstStep
              ? (map.containsKey('loopInfinite')
              ? loopInfinite
              : existingStep?.loopInfinite)
              : existingStep?.loopInfinite,
          themeId: themeId ?? existingStep?.themeId,
          floatingId: floatingId ?? existingStep?.floatingId,
        );

        final task = ClickTask(
          id: finalId,
          name: finalName,
          description: description ?? '来自悬浮球配置保存',
          isWorkflow: isWorkflow,
          createdAt: DateTime.now(),
          workflowSteps: isWorkflow ? [step] : const [],
          posX: isWorkflow ? null : x,
          posY: isWorkflow ? null : y,
          clickCount: clickCount,
          isRandom: isRandom,
          fixedIntervalMs: fixedIntervalMs,
          randomMinMs: randomMinMs,
          randomMaxMs: randomMaxMs,
          loopCount: isWorkflow && isFirstStep ? loopCount : null,
          loopInfinite: isWorkflow && isFirstStep ? loopInfinite : null,
          themeId: themeId,
        );

        if (_hiveReady) {
          if (isWorkflow) {
            await _persistWorkflowStep(
              finalId: finalId,
              finalName: finalName,
              description: description,
              step: step,
            );
          } else {
            await _persistSingleClickTask(
              finalId: finalId,
              finalName: finalName,
              description: description,
              x: x,
              y: y,
              clickCount: clickCount,
              isRandom: isRandom,
              fixedIntervalMs: fixedIntervalMs,
              randomMinMs: randomMinMs,
              randomMaxMs: randomMaxMs,
            );
          }

          await _reloadTasksFromHive(runningTaskId: finalId);
        } else {
          setState(() {
            _runningTaskId = finalId;
            if (taskId != null) {
              final index =
              _tasks.indexWhere((t) => t.id == taskId);
              if (index != -1) {
                final original = _tasks[index];
                if (isWorkflow) {
                  final steps = [...original.workflowSteps];
                  final existingIndex =
                  steps.indexWhere((element) =>
                  element.index == stepIndex);
                  if (existingIndex != -1) {
                    steps[existingIndex] = step;
                  } else {
                    steps.add(step);
                  }
                  steps.sort((a, b) => a.index.compareTo(b.index));
                  _tasks[index] = original.copyWith(
                    name: finalName,
                    description:
                    description ?? original.description,
                    workflowSteps: steps,
                    posX: null,
                    posY: null,
                  );
                } else {
                  _tasks[index] = task;
                }
              } else {
                _tasks.insert(0, task);
              }
            } else {
              _tasks.insert(0, task);
            }
          });
        }

        if (executeAfterSave) {
          if (isWorkflow) {
            await _executeWorkflowFromHive(finalId);
          } else {
            await _executeSingleFromHive(finalId);
          }
        }
        return null;

      default:
        return null;
    }
  }

  Future<void> _startFloatingDot(
      {Map<String, Object?> extraConfig = const {}}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(kFloatingBallThemeKey);

      final Map<String, Object?> args = {
        'themeId': themeId,
        ...extraConfig,
      };

      args.putIfAbsent('displayNumber', () => 1);
      args.putIfAbsent('stepIndex', () => generateStepId());

      final isWorkflow = args['isWorkflow'] == true;
      final taskId = args['taskId'] as String?;
      // stepIndex：统一转成 int，默认 1（无论单任务还是工作流）
      final int stepIndex = (args['stepIndex'] as num?)?.toInt() ?? 1;
      args['stepIndex'] = stepIndex;

// displayNumber 默认跟 stepIndex 一致（如果外面没传）
      args.putIfAbsent('displayNumber', () => stepIndex);

// 工作流：如果没显式传 floatingId，则用 taskId + stepIndex
      if (isWorkflow && taskId != null) {
        args.putIfAbsent('floatingId', () => _buildFloatingId(taskId, stepIndex));
      }

      if (!isWorkflow &&
          !args.containsKey('x') &&
          !args.containsKey('workflowSteps')) {
        final center = _getScreenCenter();
        args['x'] = center.dx.round();
        args['y'] = center.dy.round();
      }

      if (isWorkflow) {
        if (!args.containsKey('x')) {
          final center = _getScreenCenter();
          args.putIfAbsent('x', () => center.dx.round());
          args.putIfAbsent('y', () => center.dy.round());
        }

        if (!args.containsKey('popupAnchorX') || !args.containsKey('popupAnchorY')) {
          final double baseX = (args['x'] as num?)?.toDouble() ??
              _getScreenCenter().dx;
          final double baseY = (args['y'] as num?)?.toDouble() ??
              _getScreenCenter().dy;
          final anchor = _calculatePopupAnchor(Offset(baseX, baseY));
          args.putIfAbsent('popupAnchorX', () => anchor.dx.round());
          args.putIfAbsent('popupAnchorY', () => anchor.dy.round());
        }
      }

      final result =
      await AutoClickChannels.autoClickChannel.invokeMethod<bool>(
        'startFloatingDot',
        args,
      );

      final runningTaskId = args['taskId'] as String?;

      setState(() {
        _isFloatingEnabled = result ?? false;
        _statusMessage =
        _isFloatingEnabled ? '定位喵球已开启' : '开启失败，请检查权限';
        _runningTaskId = _isFloatingEnabled ? runningTaskId : null;
      });

    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = '启动异常: ${e.message}';
      });
    }
  }

  Future<void> _stopFloatingDot() async {
    try {
      await AutoClickChannels.autoClickChannel
          .invokeMethod('stopFloatingDot');
      setState(() {
        _isFloatingEnabled = false;
        _statusMessage = '定位喵球未开启';
        _runningTaskId = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = '关闭异常: ${e.message}';
      });
    }
  }

  Future<void> _stopExecution() async {
    try {
      await AutoClickChannels.autoClickChannel
          .invokeMethod('stopExecution');
      setState(() {
        _statusMessage = '已停止执行';
        _runningTaskId = null;
        _isExecuting = false;
        _executingTaskId = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = '停止执行异常: ${e.message}';
      });
    }
  }


  Future<void> _openFloatingBallConfigDialog() async {
    await _stopFloatingDot();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '悬浮球配置',
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withOpacity(0.07),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: _frostedInputDecorationTheme(),
                      ),
                      child: FloatingBallConfigPage(
                        showAppBar: false,
                        onRequestClose: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    await _loadCurrentBallTheme();
  }


  Future<void> _createSingleClickTask() async {
    if (_isFloatingEnabled) {
      await _stopFloatingDot();
    }

    final name = await _promptForTaskName(isWorkflow: false);
    if (name == null) return;

    final now = DateTime.now();
    final taskId = now.millisecondsSinceEpoch.toString();
    final center = _getScreenCenter();

    // 先用用户输入的名称构建内存与 Hive 的初始记录
    final task = ClickTask(
      id: taskId,
      name: name,
      description: '单击任务',
      isWorkflow: false,
      createdAt: now,
      posX: center.dx.round(),
      posY: center.dy.round(),
      clickCount: 1,
      isRandom: false,
      fixedIntervalMs: 1000,
    );

    setState(() {
      _tasks.insert(0, task);
    });

    if (_hiveReady) {
      final entity = TaskEntity()
        ..taskId = taskId
        ..taskType = 1
        ..listIndex = _nextListIndex()
        ..name = name
        ..description = task.description
        ..createdAt = now
        ..posX = task.posX
        ..posY = task.posY
        ..clickCount = task.clickCount
        ..isRandom = task.isRandom
        ..fixedIntervalMs = task.fixedIntervalMs
        ..randomMinMs = task.randomMinMs
        ..randomMaxMs = task.randomMaxMs;

      // 将用户命名的任务立即写入 Hive，便于后续悬浮球弹窗更新
      await _tasksBox.put(taskId, entity);
    }

    await _startFloatingDot(
      extraConfig: {
        'taskId': taskId,
        'taskName': name,
        'x': task.posX,
        'y': task.posY,
        'clickCount': task.clickCount,
        'isRandom': task.isRandom,
        if (task.fixedIntervalMs != null)
          'fixedIntervalMs': task.fixedIntervalMs,
        'displayNumber': 1,
        'stepIndex': 1,
      },
    );
  }

  Future<void> _createWorkflowTask() async {
    if (_isFloatingEnabled) {
      await _stopFloatingDot();
    }

    final name = await _promptForTaskName(isWorkflow: true);
    if (name == null) return;

    final now = DateTime.now();
    final taskId = now.millisecondsSinceEpoch.toString();

    // 工作流初始状态：仅保存用户输入的名称与基本元数据，步骤待悬浮球配置
    final task = ClickTask(
      id: taskId,
      name: name,
      description: '多步点击任务（后续可跳到工作流配置页）',
      isWorkflow: true,
      createdAt: now,
      workflowSteps: const [],
    );

    setState(() {
      _tasks.insert(0, task);
    });

    if (_hiveReady) {
      final entity = TaskEntity()
        ..taskId = taskId
        ..taskType = 2
        ..listIndex = _nextListIndex()
        ..name = name
        ..description = task.description
        ..createdAt = now
        ..posX = null
        ..posY = null
        ..clickCount = null
        ..isRandom = null
        ..fixedIntervalMs = null
        ..randomMinMs = null
        ..randomMaxMs = null;

      // 立即写入 Hive，保证后续步骤配置可以直接覆盖对应任务
      await _tasksBox.put(taskId, entity);
    }

    final center = _getScreenCenter();
    final anchor = _calculatePopupAnchor(center);
    const firstStepIndex = 1;

    await _startFloatingDot(
      extraConfig: {
        'taskId': taskId,
        'taskName': name,
        'isWorkflow': true,
        'stepIndex': firstStepIndex,              // 第一步 = 1
        'displayNumber': firstStepIndex,          // 显示数字也用 1
        'nextDisplayNumber': firstStepIndex,
        'floatingId': _buildFloatingId(taskId, firstStepIndex),
        'showNextStep': true,
        'x': center.dx.round(),
        'y': center.dy.round(),
        'popupAnchorX': anchor.dx.round(),
        'popupAnchorY': anchor.dy.round(),
      },
    );

  }

  Future<void> _onTaskTap(ClickTask task) async {
    if (_hiveReady) {
      final entity = _tasksBox.get(task.id);
      if (entity != null &&
          (entity.taskType == 2 || task.isWorkflow)) {
        final steps = _loadSteps(task.id);
        final stepsPayload = <Map<String, Object?>>[];
        for (var i = 0; i < steps.length; i++) {
          final s = steps[i];
          final displayNumber = i + 1;
          final anchor = s.posX != null && s.posY != null
              ? _calculatePopupAnchor(
                  Offset(s.posX!.toDouble(), s.posY!.toDouble()),
                )
              : null;

          stepsPayload.add({
            'x': s.posX,
            'y': s.posY,
            if (anchor != null) 'popupAnchorX': anchor.dx.round(),
            if (anchor != null) 'popupAnchorY': anchor.dy.round(),
            'index': s.stepNumber,
            'displayNumber': displayNumber,
            'floatingId':
            s.floatingId ?? _buildFloatingId(task.id, s.stepNumber),
            'clickCount': s.clickCount,
            'isRandom': s.isRandom,
            if (s.fixedIntervalMs != null)
              'fixedIntervalMs': s.fixedIntervalMs,
            if (s.randomMinMs != null)
              'randomMinMs': s.randomMinMs,
            if (s.randomMaxMs != null)
              'randomMaxMs': s.randomMaxMs,
            if (s.stepNumber == 1 && s.loopCount != null)
              'loopCount': s.loopCount,
            if (s.stepNumber == 1 && s.loopCount != null)
              'loopInfinite': s.loopCount == 0,
          });
        }

        // 关键：用现有步骤的最大 stepNumber + 1 作为下一步的 stepIndex
        final int nextStepIndex;
        if (steps.isEmpty) {
          nextStepIndex = 1;
        } else {
          final maxStepNumber =
          steps.map((e) => e.stepNumber).fold<int>(0, math.max);
          nextStepIndex = maxStepNumber + 1;
        }
        final nextDisplayNumber = nextStepIndex;

        final center = _getScreenCenter();
        final anchor = _calculatePopupAnchor(center);

        await _startFloatingDot(
          extraConfig: {
            'taskId': task.id,
            'taskName': entity.name,
          'isWorkflow': true,
          if (stepsPayload.isNotEmpty) 'workflowSteps': stepsPayload,
          'showNextStep': true,
          'stepIndex': nextStepIndex,                           // 2,3,4...
          'displayNumber': nextDisplayNumber,
          'nextDisplayNumber': nextDisplayNumber,
          'floatingId': _buildFloatingId(task.id, nextStepIndex),
          'x': center.dx.round(),
          'y': center.dy.round(),
          'popupAnchorX': anchor.dx.round(),
          'popupAnchorY': anchor.dy.round(),
          },
        );
        return;
      } else if (entity != null) {
        await _startFloatingDot(
          extraConfig: {
            'taskId': task.id,
            'taskName': entity.name,
            if (entity.posX != null) 'x': entity.posX,
            if (entity.posY != null) 'y': entity.posY,
            'clickCount': entity.clickCount ?? task.clickCount,
            'isRandom': entity.isRandom ?? task.isRandom,
            if (entity.fixedIntervalMs != null)
              'fixedIntervalMs': entity.fixedIntervalMs,
            if (entity.randomMinMs != null)
              'randomMinMs': entity.randomMinMs,
            if (entity.randomMaxMs != null)
              'randomMaxMs': entity.randomMaxMs,
            'displayNumber': 1,
            'stepIndex': 1,
          },
        );
        return;
      }
    }

    if (task.isWorkflow) {
      final stepsPayload = task.workflowSteps
          .asMap()
          .entries
          .map(
            (entry) => entry.value
            .copyWith(
          floatingId: entry.value.floatingId ??
              _buildFloatingId(task.id, entry.value.index),
        )
            .toMap(displayNumber: entry.key + 1),
      )
          .toList();

      final existingIndexes =
      task.workflowSteps.map((s) => s.index).toList();

      final int nextStepIndex;
      if (existingIndexes.isEmpty) {
        nextStepIndex = 1;
      } else {
        nextStepIndex = existingIndexes.reduce(math.max) + 1;
      }
      final nextDisplayNumber = nextStepIndex;

      final center = _getScreenCenter();
      final anchor = _calculatePopupAnchor(center);

      await _startFloatingDot(
        extraConfig: {
          'taskId': task.id,
          'taskName': task.name,
          'isWorkflow': true,
          if (stepsPayload.isNotEmpty)
            'workflowSteps': stepsPayload,
          'showNextStep': true,
          'stepIndex': nextStepIndex,
          'displayNumber': nextDisplayNumber,
          'nextDisplayNumber': nextDisplayNumber,
          'floatingId': _buildFloatingId(task.id, nextStepIndex),
          'x': center.dx.round(),
          'y': center.dy.round(),
          'popupAnchorX': anchor.dx.round(),
          'popupAnchorY': anchor.dy.round(),
        },
      );
      return;
    }

    await _startFloatingDot(
      extraConfig: {
        'taskId': task.id,
        'taskName': task.name,
        if (task.posX != null) 'x': task.posX,
        if (task.posY != null) 'y': task.posY,
        'clickCount': task.clickCount,
        'isRandom': task.isRandom,
        if (task.fixedIntervalMs != null)
          'fixedIntervalMs': task.fixedIntervalMs,
        if (task.randomMinMs != null)
          'randomMinMs': task.randomMinMs,
        if (task.randomMaxMs != null)
          'randomMaxMs': task.randomMaxMs,
        'displayNumber': 1,
        'stepIndex': 1,
      },
    );
  }

  Offset _calculatePopupAnchor(Offset center) {
    // 让弹窗位于悬浮球的右侧正中，而不是正下方
    const offset = Offset(60, 0);
    return center + offset;
  }

  Offset _getScreenCenter() {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final pixelRatio = mediaQuery.devicePixelRatio;
    final padding = mediaQuery.viewPadding;

    final widthPx = size.width * pixelRatio;
    final heightPx = size.height * pixelRatio;
    final statusBarPx = padding.top * pixelRatio;
    final bottomPaddingPx = padding.bottom * pixelRatio;

    final usableHeightPx = heightPx - statusBarPx - bottomPaddingPx;

    return Offset(
      widthPx / 2,
      statusBarPx + usableHeightPx / 2,
    );
  }

  Future<void> _deleteTask(ClickTask task) async {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });

    if (_hiveReady) {
      await _tasksBox.delete(task.id);
      final keysToDelete = _stepsBox.keys
          .where((key) => _stepsBox.get(key)?.taskId == task.id)
          .toList();
      await _stepsBox.deleteAll(keysToDelete);
    }

    if (_runningTaskId != null && _runningTaskId == task.id) {
      await _stopFloatingDot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [
          // 顶部渐变背景 + 磨砂玻璃叠层
          Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFA8C5FF).withOpacity(0.32),
                  Colors.white.withOpacity(0.06),
                  const Color(0xFF7AE0FF).withOpacity(0.28),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: CustomPaint(
              painter: _GlassAccentPainter(
                seed: 1,
                colors: const [
                  Color(0xFF7BDFF2),
                  Color(0xFFFB7185),
                  Color(0xFFFFB347),
                  Color(0xFF7AE0FF),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter:
                      ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0EA5E9)
                                  .withOpacity(0.26),
                              const Color(0xFF8B5CF6)
                                  .withOpacity(0.18),
                              const Color(0xFF34D399)
                                  .withOpacity(0.16),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.24),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter:
                      ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                            18, 16, 18, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF67E8F9)
                                  .withOpacity(0.24),
                              const Color(0xFFFDE68A)
                                  .withOpacity(0.14),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildGlassTitle(
                                          theme.textTheme),
                                      const SizedBox(height: 4),
                                      Text(
                                        '自动点击 · 定位喵球 · 后台运行',
                                        style: TextStyle(
                                          color: const Color(0xFFCBD5E1),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 配置按钮（打开悬浮球配置 Overlay）
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: _openFloatingBallConfigDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF425369).withOpacity(0.78),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.10),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.20),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.10),
                                          blurRadius: 4,
                                          offset: const Offset(0, -1),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      size: 20,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // 悬浮点状态 + 停止执行按钮
                            StatusCard(
                              isActive: _isFloatingEnabled,
                              isExecuting: _isExecuting,
                              statusMessage: _statusMessage,
                              accentColor:
                              _currentBallTheme.colors.first,
                              onStop: _stopExecution,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 列表标题（磨砂玻璃）
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter:
                      ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.16),
                              const Color(0xFF9EB9FF)
                                  .withOpacity(0.14),
                              Colors.white.withOpacity(0.08),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              '任务列表',
                              style: TextStyle(
                                color: const Color(0xFFE2E8F0),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _tasks.isEmpty
                                  ? '暂无任务'
                                  : '${_tasks.length} 个任务',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: Colors.white
                                    .withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 任务列表
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                            sigmaX: 14, sigmaY: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(20),
                            color:
                            Colors.white.withOpacity(0.03),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.02),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.35),
                                blurRadius: 22,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter:
                                    StarryBackdropPainter(
                                      seed: 11,
                                      dotCount: 14,
                                      lineCount: 8,
                                      starCount: 10,
                                    ),
                                  ),
                                ),
                              ),
                              if (_tasks.isEmpty)
                                const Center(
                                  child: EmptyState(),
                                )
                              else
                                Positioned.fill(
                                  child: ListView.separated(
                                    padding:
                                    const EdgeInsets.fromLTRB(
                                        12, 12, 12, 96),
                                    itemBuilder:
                                        (context, index) {
                                      final task =
                                      _tasks[index];
                                      final isRunning =
                                          _isFloatingEnabled &&
                                              task.id ==
                                                  _runningTaskId;

                                      // 按创建顺序编号：最早创建的是 #1，越新的编号越大
                                      final displayIndex =
                                          _tasks.length -
                                              index -
                                              1;

                                      return TaskCard(
                                        task: task,
                                        index: displayIndex,
                                        isRunning: isRunning,
                                        onTap: () =>
                                            _onTaskTap(task),
                                        onDelete: () =>
                                            _deleteTask(task),
                                      );
                                    },
                                    separatorBuilder:
                                        (_, __) =>
                                    const SizedBox(
                                      height: 12,
                                    ),
                                    itemCount: _tasks.length,
                                  ),
                                ),
                            ],
                          ),
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

      // 底部两个按钮：单任务 / 工作流
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
              left: 16, right: 16, bottom: 12, top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter:
              ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: CustomPaint(
                painter: _GlassAccentPainter(
                  seed: 7,
                  colors: const [
                    Color(0xFFF9A8D4),
                    Color(0xFF93C5FD),
                    Color(0xFF34D399),
                    Color(0xFFFFB347),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.05),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0EA5E9)
                            .withOpacity(0.16),
                        const Color(0xFFE879F9)
                            .withOpacity(0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color:
                      Colors.white.withOpacity(0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withOpacity(0.45),
                        blurRadius: 20,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _GlassActionButton(
                          label: '单任务',
                          icon: Icons.touch_app_rounded,
                          onTap: _createSingleClickTask,
                          gradientColors: [
                            const Color(0xFF60A5FA)
                                .withOpacity(0.32),
                            Colors.white.withOpacity(0.06),
                          ],
                          borderColor: Colors.white
                              .withOpacity(0.2),
                          textColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GlassActionButton(
                          label: '工作流',
                          icon: Icons.auto_graph_rounded,
                          onTap: _createWorkflowTask,
                          gradientColors: [
                            const Color(0xFFC084FC)
                                .withOpacity(0.32),
                            Colors.white.withOpacity(0.06),
                          ],
                          borderColor: Colors.white
                              .withOpacity(0.2),
                          textColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color textColor;

  const _GlassActionButton({
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

class _GlassAccentPainter extends CustomPainter {
  final int seed;
  final List<Color> colors;

  _GlassAccentPainter({required this.seed, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    for (int i = 0; i < 8; i++) {
      final paint = Paint()
        ..color =
        colors[random.nextInt(colors.length)].withOpacity(0.55)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final delta = Offset(
        (random.nextDouble() - 0.5) * 26,
        (random.nextDouble() - 0.5) * 26,
      );

      canvas.drawLine(start, start + delta, paint);
    }

    for (int i = 0; i < 12; i++) {
      final color = colors[random.nextInt(colors.length)];
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final radius = random.nextDouble() * 1.8 + 0.6;

      final dotPaint = Paint()..color = color.withOpacity(0.72);
      canvas.drawCircle(center, radius, dotPaint);

      final arm = radius * 1.6;
      final starPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center - Offset(arm, 0),
          center + Offset(arm, 0), starPaint);
      canvas.drawLine(center - Offset(0, arm),
          center + Offset(0, arm), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// =========================
/// 可选：单独的 ConfigButton（如果你想在别处使用）
/// =========================

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
