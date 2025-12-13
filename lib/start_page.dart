import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../channels.dart';
import '../models/click_task.dart';
import '../models/task_entity.dart';
import '../models/step_identifier.dart';
import '../reset_hub.dart';
import '../services/task_storage.dart';
import 'start_page/status_card.dart';
import 'start_page/task_card.dart';
import 'start_page/starry_backdrop.dart';
import 'start_page/ball_theme.dart';
import 'start_page/floating_ball_config_sheet.dart';
import 'start_page/widgets/glass_action_button.dart';
import 'start_page/widgets/glass_accent_painter.dart';
import 'start_page/widgets/config_button.dart';
import 'start_page/widgets/click_config_dialog.dart'; // 👈 新增：点击配置弹窗

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
  late TaskStorage _taskStorage;
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
    AutoClickChannels.autoClickChannel
        .setMethodCallHandler(_handleNativeCallback);
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

  BallTheme _resolveBallTheme(String? themeId) {
    if (themeId == null) return _currentBallTheme;

    return kBallThemes.firstWhere(
          (theme) => theme.id == themeId,
      orElse: () => _currentBallTheme,
    );
  }

  int? _resolveWorkflowDisplayNumber(
      List<WorkflowStep> steps,
      int stepIndex,
      ) {
    final sorted = [...steps]..sort((a, b) => a.index.compareTo(b.index));
    final pos = sorted.indexWhere((step) => step.index == stepIndex);

    if (pos != -1) return pos + 1;

    return sorted.isNotEmpty ? sorted.length + 1 : 1;
  }

  Future<void> _initHiveAndLoad() async {
    _tasksBox = Hive.box<TaskEntity>('tasks');
    _stepsBox = Hive.box<StepEntity>('steps');
    _taskStorage = TaskStorage(_tasksBox, _stepsBox);
    _hiveReady = true;
    await _reloadTasksFromHive();
  }

  Future<void> _reloadTasksFromHive({String? runningTaskId}) async {
    if (!_hiveReady) return;
    final restored = await _taskStorage.restoreTasks();

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
    await _taskStorage.saveSingleClickTask(
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

  Future<void> _persistWorkflowStep({
    required String finalId,
    required String finalName,
    String? description,
    required WorkflowStep step,
  }) async {
    if (!_hiveReady) return;
    await _taskStorage.saveWorkflowStep(
      finalId: finalId,
      finalName: finalName,
      description: description,
      step: step,
      floatingIdBuilder: (index) => _buildFloatingId(finalId, index),
    );
  }

  Future<void> _executeSingleFromHive(String taskId) async {
    if (!_hiveReady) return;

    final args = _taskStorage.buildSingleExecutionArgs(taskId);
    if (args == null) return;

    await AutoClickChannels.autoClickChannel
        .invokeMethod('executeSingleTask', args);
  }

  Future<void> _executeWorkflowFromHive(String taskId) async {
    if (!_hiveReady) return;
    final workflowData = _taskStorage.buildWorkflowExecutionData(
      taskId,
          (stepIndex) => _buildFloatingId(taskId, stepIndex),
    );
    if (workflowData == null) return;

    final args = <String, Object?>{
      'taskId': taskId,
      'steps': workflowData.steps,
    };
    if (workflowData.loopCount != null) {
      args['loopCount'] = workflowData.loopCount;
      args['loopInfinite'] = workflowData.loopCount == 0;
    }

    debugPrint(
        '[AutoClick] executeWorkflow from Hive task=$taskId loopCount=${workflowData.loopCount} loopInfinite=${workflowData.loopCount == 0} steps=${workflowData.steps.length}');

    await AutoClickChannels.autoClickChannel
        .invokeMethod('executeWorkflow', args);
  }

  Future<void> _persistWorkflowShell(ClickTask task) async {
    if (!_hiveReady) return;
    await _taskStorage.saveWorkflowShell(task);
  }

  /// 处理原生回调（悬浮球配置 / 执行 / 编辑）
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
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
            StepEntity? existingStep;
            for (final step in _taskStorage.loadSteps(taskId)) {
              if (step.stepNumber == stepIndex) {
                existingStep = step;
                break;
              }
            }

            final updatedStep = WorkflowStep(
              index: stepIndex,
              posX: x,
              posY: y,
              clickCount: existingStep?.clickCount ?? 1,
              isRandom: existingStep?.isRandom ?? false,
              fixedIntervalMs: existingStep?.fixedIntervalMs,
              randomMinMs: existingStep?.randomMinMs,
              randomMaxMs: existingStep?.randomMaxMs,
              loopCount: existingStep?.loopCount,
              loopInfinite: existingStep?.loopCount == 0,
              floatingId:
              existingStep?.floatingId ?? _buildFloatingId(taskId, stepIndex),
            );

            await _taskStorage.saveWorkflowStep(
              finalId: taskId,
              finalName: _tasks.firstWhere((t) => t.id == taskId).name,
              description: _tasks.firstWhere((t) => t.id == taskId).description,
              step: updatedStep,
              floatingIdBuilder: (index) => _buildFloatingId(taskId, index),
            );
          } else {
            final entity = _taskStorage.getTaskEntity(taskId);
            if (entity != null) {
              await _taskStorage.saveSingleClickTask(
                finalId: taskId,
                finalName: entity.name,
                description: entity.description,
                x: x,
                y: y,
                clickCount: entity.clickCount ?? 1,
                isRandom: entity.isRandom ?? false,
                fixedIntervalMs: entity.fixedIntervalMs,
                randomMinMs: entity.randomMinMs,
                randomMaxMs: entity.randomMaxMs,
              );
            }
          }
        }

        return null;

      case 'onFloatingConfigSaved':
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);

        // 打一行日志，方便你以后排查
        print('[onFloatingConfigSaved] map = $map');

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
        } else if (existing != null && existing.name.trim().isNotEmpty) {
          finalName = existing.name;
        } else {
          finalName = _buildDefaultTaskName(isWorkflow);
        }

        final String? description = map['description'] as String?;
        final String? themeId = map['themeId'] as String?;

        final int? x = (map['x'] as num?)?.toInt();
        final int? y = (map['y'] as num?)?.toInt();
        final int clickCount = (map['clickCount'] as num?)?.toInt() ?? 1;
        final bool isRandom = (map['isRandom'] as bool?) ?? false;
        final int? fixedIntervalMs =
        (map['fixedIntervalMs'] as num?)?.toInt();
        final int? randomMinMs =
        (map['randomMinMs'] as num?)?.toInt();
        final int? randomMaxMs =
        (map['randomMaxMs'] as num?)?.toInt();

        final int? rawLoopCount = (map['loopCount'] as num?)?.toInt();
        final bool? loopInfinite = map['loopInfinite'] as bool?;
        final int? loopCount = loopInfinite == true
            ? 0
            : (rawLoopCount == null
                ? null
                : (rawLoopCount < 1 ? 1 : rawLoopCount));

        final int stepIndex =
            (map['stepIndex'] as num?)?.toInt() ?? generateStepId();

        final String? floatingId =
            (map['floatingId'] as String?) ??
                (taskId != null
                    ? _buildFloatingId(taskId, stepIndex)
                    : null);

        final String finalId =
            taskId ?? DateTime.now().millisecondsSinceEpoch.toString();

        WorkflowStep? existingStep;
        if (existing != null) {
          try {
            existingStep = existing.workflowSteps
                .firstWhere((step) => step.index == stepIndex);
          } catch (_) {
            existingStep = null;
          }
        }

        final int? displayNumberFromNative =
            (map['displayNumber'] as num?)?.toInt();
        final existingIndexes = existing?.workflowSteps
            .map((step) => step.index)
            .where((index) => index != stepIndex)
            .toList() ??
            [];
        existingIndexes.add(stepIndex);
        existingIndexes.sort();
        final bool isFirstStep = (displayNumberFromNative == 1) ||
            (existingIndexes.isEmpty ? true : existingIndexes.first == stepIndex);

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

        debugPrint(
            "[onFloatingConfigSaved] stepIndex=$stepIndex displayNumber=${map['displayNumber']} isFirstStep=$isFirstStep loopCount=$loopCount loopInfinite=$loopInfinite rawLoop=$rawLoopCount");

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
          loopCount: loopCount,
          loopInfinite: loopInfinite,
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
              final index = _tasks.indexWhere((t) => t.id == taskId);
              if (index != -1) {
                final original = _tasks[index];
                if (isWorkflow) {
                  final steps = [...original.workflowSteps];
                  final existingIndex =
                  steps.indexWhere((element) => element.index == stepIndex);
                  if (existingIndex != -1) {
                    steps[existingIndex] = step;
                  } else {
                    steps.add(step);
                  }
                  steps.sort((a, b) => a.index.compareTo(b.index));
                  _tasks[index] = original.copyWith(
                    name: finalName,
                    description: description ?? original.description,
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

        // ⭐⭐ 关键修改点：执行时
        if (executeAfterSave) {
          if (isWorkflow) {
            // 工作流：继续走你原来的从 Hive 读取执行逻辑
            await _executeWorkflowFromHive(finalId);
          } else {
            // 单任务：直接用本次弹窗的最新配置执行，不再从 Hive 重建，避免读到旧值
            final args = <String, Object?>{
              'taskId': finalId,
              'x': x,
              'y': y,
              'clickCount': clickCount,
              'isRandom': isRandom,
              if (fixedIntervalMs != null) 'fixedIntervalMs': fixedIntervalMs,
              if (randomMinMs != null) 'randomMinMs': randomMinMs,
              if (randomMaxMs != null) 'randomMaxMs': randomMaxMs,
            };

            print('[onFloatingConfigSaved] executeSingleTask args = $args');

            await AutoClickChannels.autoClickChannel.invokeMethod(
              'executeSingleTask',
              args,
            );
          }
        }

        if (isWorkflow) {
          final Offset? anchorOffset = step.posX != null && step.posY != null
              ? _calculatePopupAnchor(
            Offset(step.posX!.toDouble(), step.posY!.toDouble()),
          )
              : null;

          await AutoClickChannels.autoClickChannel.invokeMethod(
            'updateFloatingConfig',
            {
              'taskId': finalId,
              'isWorkflow': true,
              'stepIndex': stepIndex,
              'floatingId': floatingId,
              'showNextStep': false,
              if (anchorOffset != null) 'popupAnchorX': anchorOffset.dx.round(),
              if (anchorOffset != null) 'popupAnchorY': anchorOffset.dy.round(),
            },
          );
        }
        return null;



      case 'onFloatingEditRequested':
      // 👇 新增：悬浮球点「编辑」时，弹出点击配置对话框
        final raw = call.arguments;
        if (raw is! Map) return null;

        final map = Map<Object?, Object?>.from(raw);
        final String? taskId = map['taskId'] as String?;
        final bool isWorkflow = (map['isWorkflow'] as bool?) ?? false;
        final int? stepIndex = (map['stepIndex'] as num?)?.toInt();
        final int? displayNumber = (map['displayNumber'] as num?)?.toInt();
        final String? themeId = map['themeId'] as String?;
        final int? popupAnchorXFromNative =
        (map['popupAnchorX'] as num?)?.toInt();
        final int? popupAnchorYFromNative =
        (map['popupAnchorY'] as num?)?.toInt();

        if (taskId == null) {
          debugPrint('[AutoClick] onFloatingEditRequested: taskId 为空');
          return null;
        }

        // 先在当前内存任务列表里找
        ClickTask? task;
        try {
          task = _tasks.firstWhere((t) => t.id == taskId);
        } catch (_) {
          task = null;
        }

        // 如果没找到并且 Hive 已初始化，尝试从 Hive 重载一次
        if (task == null && _hiveReady) {
          final restored = await _taskStorage.restoreTasks();
          try {
            task = restored.firstWhere((t) => t.id == taskId);
            setState(() {
              _tasks
                ..clear()
                ..addAll(restored);
            });
          } catch (_) {
            task = null;
          }
        }

        if (task == null) {
          debugPrint('[AutoClick] onFloatingEditRequested: 未找到任务 $taskId');
          return null;
        }

        // 计算初始值
        int initialClickCount;
        bool initialIsRandom;
        int initialFixedInterval;
        int initialRandomMin;
        int initialRandomMax;
        int? initialLoopCount;
        bool? initialLoopInfinite;

        WorkflowStep? targetStep;
        int? resolvedDisplayOrder;
        bool isFirstDisplayStep = false;

        if (isWorkflow) {
          if (stepIndex == null) {
            debugPrint('[AutoClick] isWorkflow=true 但 stepIndex 为空');
            return null;
          }

          try {
            targetStep = task.workflowSteps
                .firstWhere((s) => s.index == stepIndex);
          } catch (_) {
            targetStep = WorkflowStep(index: stepIndex);
          }

          resolvedDisplayOrder = displayNumber ??
              _resolveWorkflowDisplayNumber(task.workflowSteps, stepIndex);
          isFirstDisplayStep = resolvedDisplayOrder == 1;

          print(
              '[edit] taskId=$taskId stepIndex=$stepIndex displayNumber=$displayNumber resolvedDisplayOrder=$resolvedDisplayOrder isFirstDisplayStep=$isFirstDisplayStep');

          initialClickCount = targetStep!.clickCount;
          initialIsRandom = targetStep.isRandom;
          initialFixedInterval = targetStep.fixedIntervalMs ?? 1000;
          initialRandomMin = targetStep.randomMinMs ?? 500;
          initialRandomMax = targetStep.randomMaxMs ?? 1500;

          if (isFirstDisplayStep) {
            initialLoopCount = targetStep.loopCount ?? task.loopCount;
            initialLoopInfinite = targetStep.loopInfinite ??
                (initialLoopCount != null && initialLoopCount == 0);
          }
        } else {
          initialClickCount = task.clickCount;
          initialIsRandom = task.isRandom;
          initialFixedInterval = task.fixedIntervalMs ?? 1000;
          initialRandomMin = task.randomMinMs ?? 500;
          initialRandomMax = task.randomMaxMs ?? 1500;

          print(
              '[edit] taskId=$taskId stepIndex=$stepIndex displayNumber=$displayNumber resolvedDisplayOrder=$resolvedDisplayOrder isFirstDisplayStep=$isFirstDisplayStep');
        }

        bool dotsHidden = false;
        try {
          await AutoClickChannels.autoClickChannel.invokeMethod('hideFloatingDots');
          dotsHidden = true;
        } catch (e) {
          debugPrint('[AutoClick] hideFloatingDots failed: $e');
        }

        // 打开磨砂玻璃配置弹窗
        await showClickConfigDialog(
          context,
          initialClickCount: initialClickCount,
          initialIntervalMs: initialFixedInterval,
          initialIsRandom: initialIsRandom,
          initialRandomMinMs: initialRandomMin,
          initialRandomMaxMs: initialRandomMax,
          initialLoopCount: isFirstDisplayStep ? initialLoopCount : null,
          initialLoopInfinite:
              isFirstDisplayStep ? initialLoopInfinite : null,
          showLoopControls: isFirstDisplayStep,
          stepNumber: resolvedDisplayOrder,
          stepLabelColor: _resolveBallTheme(themeId).colors.last,
          onConfirm: ({
            required int clickCount,
            required bool isRandom,
            required int fixedIntervalMs,
            required int randomMinMs,
            required int randomMaxMs,
            int? loopCount,
            bool? loopInfinite,
          }) async {
            if (!mounted) return;

            final int? normalizedLoopCount = isFirstDisplayStep
                ? (loopInfinite == true
                    ? 0
                    : (loopCount == null || loopCount < 1 ? 1 : loopCount))
                : null;
            final bool? normalizedLoopInfinite = isFirstDisplayStep
                ? (loopInfinite ?? (normalizedLoopCount == 0 ? true : null))
                : null;

            // 1️⃣ 更新内存中的任务列表 _tasks
            setState(() {
              final idx = _tasks.indexWhere((t) => t.id == taskId);
              if (idx == -1) return;

              final original = _tasks[idx];

              if (isWorkflow) {
                final int sIndex = stepIndex!;
                final steps = [...original.workflowSteps];
                int pos = steps.indexWhere((s) => s.index == sIndex);

                WorkflowStep baseStep;
                if (pos != -1) {
                  baseStep = steps[pos];
                } else {
                  baseStep = WorkflowStep(
                    index: sIndex,
                    posX: popupAnchorXFromNative,
                    posY: popupAnchorYFromNative,
                  );
                  steps.add(baseStep);
                  pos = steps.length - 1;
                }

                final anchorX = popupAnchorXFromNative ?? baseStep.posX;
                final anchorY = popupAnchorYFromNative ?? baseStep.posY;

                WorkflowStep updatedStep = baseStep.copyWith(
                  posX: anchorX,
                  posY: anchorY,
                  clickCount: clickCount,
                  isRandom: isRandom,
                  fixedIntervalMs: fixedIntervalMs,
                  randomMinMs: randomMinMs,
                  randomMaxMs: randomMaxMs,
                );

                if (isFirstDisplayStep) {
                  updatedStep = updatedStep.copyWith(
                    loopCount: normalizedLoopCount,
                    loopInfinite: normalizedLoopInfinite,
                  );
                }

                steps[pos] = updatedStep;
                steps.sort((a, b) => a.index.compareTo(b.index));

                _tasks[idx] = original.copyWith(
                  workflowSteps: steps,
                  loopCount: isFirstDisplayStep
                      ? normalizedLoopCount ?? original.loopCount
                      : original.loopCount,
                  loopInfinite: isFirstDisplayStep
                      ? normalizedLoopInfinite ?? original.loopInfinite
                      : original.loopInfinite,
                );
              } else {
                final updatedPosX = popupAnchorXFromNative ?? original.posX;
                final updatedPosY = popupAnchorYFromNative ?? original.posY;
                _tasks[idx] = original.copyWith(
                  posX: updatedPosX,
                  posY: updatedPosY,
                  clickCount: clickCount,
                  isRandom: isRandom,
                  fixedIntervalMs: fixedIntervalMs,
                  randomMinMs: randomMinMs,
                  randomMaxMs: randomMaxMs,
                );
              }
            });

            // 2️⃣ 同步写回 Hive（保持你原来的逻辑）
            ClickTask currentTask =
            _tasks.firstWhere((t) => t.id == taskId);

            if (_hiveReady) {
              if (isWorkflow) {
                final int sIndex = stepIndex!;
                final step = currentTask.workflowSteps
                    .firstWhere((s) => s.index == sIndex);
                await _persistWorkflowStep(
                  finalId: currentTask.id,
                  finalName: currentTask.name,
                  description: currentTask.description,
                  step: step,
                );
              } else {
                await _persistSingleClickTask(
                  finalId: currentTask.id,
                  finalName: currentTask.name,
                  description: currentTask.description,
                  x: currentTask.posX,
                  y: currentTask.posY,
                  clickCount: currentTask.clickCount,
                  isRandom: currentTask.isRandom,
                  fixedIntervalMs: currentTask.fixedIntervalMs,
                  randomMinMs: currentTask.randomMinMs,
                  randomMaxMs: currentTask.randomMaxMs,
                );
              }
            }

            // 3️⃣ ⭐ 关键新增：把最新配置推给原生 FloatingDotService
            //    这样它内部的 clickCount / isRandom / interval 就会更新，
            //    小面板“执行”时 commitConfigToFlutter 才会回传新值
            final payload = <String, Object?>{
              'taskId': currentTask.id,
              'isWorkflow': isWorkflow,
              'stepIndex': isWorkflow ? stepIndex : null,
              'displayNumber': isWorkflow ? resolvedDisplayOrder : null,
              'floatingId': isWorkflow
                  ? targetStep?.floatingId ??
                  _buildFloatingId(taskId, stepIndex!)
                  : null,
              'showNextStep': false,
            };

            if (isWorkflow) {
              // 当前这一步的配置
              final int sIndex = stepIndex!;
              final step = currentTask.workflowSteps
                  .firstWhere((s) => s.index == sIndex);
              final stepAnchorX = popupAnchorXFromNative ?? step.posX;
              final stepAnchorY = popupAnchorYFromNative ?? step.posY;
              if (stepAnchorX != null) {
                payload['popupAnchorX'] = stepAnchorX;
              }
              if (stepAnchorY != null) {
                payload['popupAnchorY'] = stepAnchorY;
              }

              payload.addAll({
                'clickCount': step.clickCount,
                'isRandom': step.isRandom,
                if (step.fixedIntervalMs != null)
                  'fixedIntervalMs': step.fixedIntervalMs,
                if (step.randomMinMs != null) 'randomMinMs': step.randomMinMs,
                if (step.randomMaxMs != null) 'randomMaxMs': step.randomMaxMs,
                if (isFirstDisplayStep && step.loopCount != null)
                  'loopCount': step.loopCount,
                if (isFirstDisplayStep && step.loopInfinite != null)
                  'loopInfinite': step.loopInfinite,
              });
            } else {
              // 单任务配置
              payload.addAll({
                'clickCount': currentTask.clickCount,
                'isRandom': currentTask.isRandom,
                if (currentTask.fixedIntervalMs != null)
                  'fixedIntervalMs': currentTask.fixedIntervalMs,
                if (currentTask.randomMinMs != null)
                  'randomMinMs': currentTask.randomMinMs,
                if (currentTask.randomMaxMs != null)
                  'randomMaxMs': currentTask.randomMaxMs,
              });
              final anchorX = popupAnchorXFromNative ?? currentTask.posX;
              final anchorY = popupAnchorYFromNative ?? currentTask.posY;
              if (anchorX != null) {
                payload['popupAnchorX'] = anchorX;
              }
              if (anchorY != null) {
                payload['popupAnchorY'] = anchorY;
              }
            }

            print('[onFloatingEditRequested] updateFloatingConfig payload = $payload');

            await AutoClickChannels.autoClickChannel.invokeMethod(
              'updateFloatingConfig',
              payload,
            );
          },
        );

        if (dotsHidden) {
          try {
            await AutoClickChannels.autoClickChannel.invokeMethod('showFloatingDots');
          } catch (e) {
            debugPrint('[AutoClick] showFloatingDots failed: $e');
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
      if (_isFloatingEnabled) {
        await _stopFloatingDot();
      }

      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(kFloatingBallThemeKey) ?? _currentBallTheme.id;

      final Map<String, Object?> args = {
        'themeId': themeId,
        ...extraConfig,
      };

      args.putIfAbsent('displayNumber', () => 1);
      args.putIfAbsent('stepIndex', () => generateStepId());

      final isWorkflow = args['isWorkflow'] == true;
      final taskId = args['taskId'] as String?;
      final int stepIndex =
          (args['stepIndex'] as num?)?.toInt() ?? generateStepId();
      args['stepIndex'] = stepIndex;
      args.putIfAbsent('displayNumber', () => stepIndex);

      if (isWorkflow && taskId != null) {
        args.putIfAbsent(
            'floatingId', () => _buildFloatingId(taskId, stepIndex));
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

      setState(() {
        _isFloatingEnabled = result ?? false;
        _statusMessage =
        _isFloatingEnabled ? '定位喵球已开启' : '开启失败，请检查权限';
        _runningTaskId =
        _isFloatingEnabled ? extraConfig['taskId'] as String? : null;
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
                      child: FloatingBallConfigSheet(
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
      await _taskStorage.saveSingleClickTask(
        finalId: taskId,
        finalName: name,
        description: task.description,
        x: task.posX,
        y: task.posY,
        clickCount: task.clickCount,
        isRandom: task.isRandom,
        fixedIntervalMs: task.fixedIntervalMs,
        randomMinMs: task.randomMinMs,
        randomMaxMs: task.randomMaxMs,
      );
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
      await _taskStorage.saveWorkflowShell(task);
    }

    final center = _getScreenCenter();
    final anchor = _calculatePopupAnchor(center);
    final firstStepId = generateStepId();

    await _startFloatingDot(
      extraConfig: {
        'taskId': taskId,
        'taskName': name,
        'isWorkflow': true,
        'stepIndex': firstStepId,
        'displayNumber': 1,
        'nextDisplayNumber': 1,
        'floatingId': _buildFloatingId(taskId, firstStepId),
        'showNextStep': true,
        'x': center.dx.round(),
        'y': center.dy.round(),
        'popupAnchorX': anchor.dx.round(),
        'popupAnchorY': anchor.dy.round(),
      },
    );
  }

  Future<void> _onTaskTap(ClickTask task) async {
    // 切换到新的任务前，先把当前悬浮球停掉，避免遗留的“幽灵球”残留
    if (_isFloatingEnabled && _runningTaskId != null && _runningTaskId != task.id) {
      await _stopFloatingDot();
    }

    if (_hiveReady) {
      final entity = _taskStorage.getTaskEntity(task.id);
      final workflowData = _taskStorage.buildWorkflowExecutionData(
        task.id,
            (stepIndex) => _buildFloatingId(task.id, stepIndex),
      );
      if (entity != null &&
          (entity.taskType == 2 || task.isWorkflow)) {
        final stepsPayload = workflowData?.steps ?? [];
        final nextIndex = workflowData?.nextStepIndex ?? generateStepId();
        final nextDisplayNumber = stepsPayload.isNotEmpty
            ? stepsPayload.length + 1
            : 1;
        final center = _getScreenCenter();
        final anchor = _calculatePopupAnchor(center);

        await _startFloatingDot(
          extraConfig: {
            'taskId': task.id,
            'taskName': entity.name,
            'isWorkflow': true,
            if (stepsPayload.isNotEmpty) 'workflowSteps': stepsPayload,
            'showNextStep': true,
            'stepIndex': nextIndex,
            'displayNumber': nextDisplayNumber,
            'nextDisplayNumber': nextDisplayNumber,
            'floatingId': _buildFloatingId(task.id, nextIndex),
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
          .map((entry) {
        final step = entry.value.copyWith(
          floatingId: entry.value.floatingId ??
              _buildFloatingId(task.id, entry.value.index),
        );

        final anchor = step.posX != null && step.posY != null
            ? _calculatePopupAnchor(
          Offset(step.posX!.toDouble(), step.posY!.toDouble()),
        )
            : null;

        final payload = step.toMap(displayNumber: entry.key + 1);
        if (anchor != null) {
          payload['popupAnchorX'] = anchor.dx.round();
          payload['popupAnchorY'] = anchor.dy.round();
        }
        return payload;
      }).toList();

      final nextStepId = generateStepId();
      final nextDisplayNumber =
      stepsPayload.isNotEmpty ? stepsPayload.length + 1 : 1;
      final center = _getScreenCenter();
      final anchor = _calculatePopupAnchor(center);

      await _startFloatingDot(
        extraConfig: {
          'taskId': task.id,
          'taskName': task.name,
          'isWorkflow': true,
          if (stepsPayload.isNotEmpty) 'workflowSteps': stepsPayload,
          'showNextStep': true,
          'stepIndex': nextStepId,
          'displayNumber': nextDisplayNumber,
          'nextDisplayNumber': nextDisplayNumber,
          'floatingId': _buildFloatingId(task.id, nextStepId),
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
      await _taskStorage.deleteTask(task.id);
    }

    if (_runningTaskId != null && _runningTaskId == task.id) {
      await _stopFloatingDot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const _GeminiGlassBackdrop(),


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
                                      ShaderMask(
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
                                          style: theme.textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
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
                                // 如果你想用可复用的 ConfigButton：
                                // ConfigButton(onTap: _openFloatingBallConfigDialog),
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

                              if (_tasks.isEmpty)
                                const Center(
                                  child: _InlineEmptyState(),
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
                painter: GlassAccentPainter(
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
                        child: GlassActionButton(
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
                        child: GlassActionButton(
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




/// ✅ 空态：保持列表容器的磨砂样式（不额外铺黑底/星空），只保留月亮图标与文字
class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.white.withOpacity(0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // “月亮”徽章
          Stack(
            alignment: Alignment.center,
            children: [
              // 外圈柔光
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 28,
                      spreadRadius: 2,
                      color: const Color(0xFFFFD38A).withOpacity(0.35),
                    ),
                  ],
                ),
              ),
              // 内部月亮
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFE3B0).withOpacity(0.95),
                      const Color(0xFFFFC87A).withOpacity(0.92),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '暂无任务',
            style: TextStyle(
              color: subtle,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击下方「单任务 / 工作流」开始创建',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 统一整页背景：Gemini 风格（渐变 + 光晕 + 轻磨砂 + grain）
///
/// 注意：这是纯背景层，不接管任何点击事件。
class _GeminiGlassBackdrop extends StatefulWidget {
  const _GeminiGlassBackdrop();

  @override
  State<_GeminiGlassBackdrop> createState() => _GeminiGlassBackdropState();
}

class _GeminiGlassBackdropState extends State<_GeminiGlassBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.2, -0.35),
              radius: 1.18,
              colors: [
                Color(0xFF6A5CFF),
                Color(0xFF14151C),
              ],
            ),
          ),
        ),
        Positioned(
          left: -90,
          top: size.height * 0.22,
          child: const _GlowBlob(d: 240),
        ),
        Positioned(
          right: -110,
          bottom: size.height * 0.08,
          child: const _GlowBlob(d: 280),
        ),
        // very subtle blur "air"
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColoredBox(color: Colors.transparent),
            ),
          ),
        ),
        // grain
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ticker,
              builder: (_, __) => CustomPaint(painter: _GrainPainter()),
            ),
          ),
        ),
      ],
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
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final math.Random _rand = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.032)
      ..strokeWidth = 1;

    const int dots = 2200;

    final points = List<Offset>.generate(
      dots,
          (_) => Offset(
        _rand.nextDouble() * size.width,
        _rand.nextDouble() * size.height,
      ),
    );

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => true;
}

