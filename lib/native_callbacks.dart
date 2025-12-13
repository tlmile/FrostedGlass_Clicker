import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channels.dart';
import 'models/click_task.dart';
import 'models/task_entity.dart';
import 'start_page/ball_theme.dart';
import 'start_page/widgets/click_config_dialog.dart';

String _buildFloatingId(String taskId, int stepIndex) => '${taskId}_$stepIndex';

Future<BallTheme> _resolveBallTheme(String? themeId) async {
  final prefs = await SharedPreferences.getInstance();
  final resolvedId = themeId ?? prefs.getString(kFloatingBallThemeKey);

  return kBallThemes.firstWhere(
    (theme) => theme.id == resolvedId,
    orElse: () => kBallThemes.first,
  );
}

int _resolveWorkflowDisplayNumber(List<WorkflowStep> steps, int stepIndex) {
  final sorted = [...steps]..sort((a, b) => a.index.compareTo(b.index));
  final pos = sorted.indexWhere((step) => step.index == stepIndex);

  if (pos != -1) return pos + 1;

  return sorted.isNotEmpty ? sorted.length + 1 : 1;
}

/// 在 App 启动后调用一次，注册原生回调
/// 建议在 StartPage.initState 里：
///
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   setupAutoClickCallbacks(context);
/// });
///
void setupAutoClickCallbacks(BuildContext context) {
  debugPrint(
      '[AutoClick] setupAutoClickCallbacks 已废弃，请使用 StartPage 中的 _handleNativeCallback 注册 MethodCallHandler。');
}

/// 从 Hive 里把某个 taskId 对应的 ClickTask 取出来
Future<ClickTask?> _loadTaskById(String taskId) async {
  final tasksBox = Hive.box<TaskEntity>('tasks');
  final stepsBox = Hive.box<StepEntity>('steps');

  TaskEntity? taskEntity;
  for (final t in tasksBox.values) {
    if (t.taskId == taskId) {
      taskEntity = t;
      break;
    }
  }
  if (taskEntity == null) return null;

  final taskSteps = stepsBox.values.where((s) => s.taskId == taskId).toList();

  // 这里用你之前的扩展方法把 TaskEntity + StepEntity => ClickTask
  return taskEntity.toClickTask(taskSteps);
}

/// 把修改后的 ClickTask 写回 Hive（单任务 / 工作流都处理）
/// 关键点：
///  - isRandom 一定要保存
///  - randomMinMs / randomMaxMs 一定要保存
Future<void> _saveTask(ClickTask task) async {
  final tasksBox = Hive.box<TaskEntity>('tasks');
  final stepsBox = Hive.box<StepEntity>('steps');

  TaskEntity? taskEntity;
  for (final t in tasksBox.values) {
    if (t.taskId == task.id) {
      taskEntity = t;
      break;
    }
  }
  if (taskEntity == null) {
    debugPrint('[AutoClick] _saveTask: 未找到 TaskEntity ${task.id}');
    return;
  }

  if (task.isWorkflow) {
    // 清理已删除的步骤，避免旧数据覆盖最新配置
    final validIndexes = task.workflowSteps.map((s) => s.index).toSet();
    final obsoleteKeys = stepsBox.keys.where((key) {
      final entity = stepsBox.get(key);
      return entity?.taskId == task.id && !validIndexes.contains(entity?.stepNumber);
    }).toList();
    await stepsBox.deleteAll(obsoleteKeys);

    // 这些就是被删除的步骤 index（注意：和 step.index 一样）
    final obsoleteStepIndexes = <int>{};
    for (final key in obsoleteKeys) {
      final entity = stepsBox.get(key);
      final num = entity?.stepNumber;
      if (num != null) {
        obsoleteStepIndexes.add(num);
      }
    }

    // 删掉 Hive 里的旧步骤
    await stepsBox.deleteAll(obsoleteKeys);

    // 🔔 告诉原生：这些步骤已经被删除 -> 请把对应的悬浮球也移除
    if (obsoleteStepIndexes.isNotEmpty) {
      await AutoClickChannels.autoClickChannel.invokeMethod(
        'removeWorkflowSteps',
        {
          'taskId': task.id,
          'stepIndexes': obsoleteStepIndexes.toList(),
        },
      );
    }

    // 先同步每个步骤
    final allSteps =
        stepsBox.values.where((s) => s.taskId == task.id).toList();

    for (final step in task.workflowSteps) {
      StepEntity? existing = allSteps.firstWhere(
            (e) => e.stepNumber == step.index,
        orElse: () => StepEntity()
          ..taskId = task.id
          ..stepNumber = step.index
          ..posX = step.posX ?? 0
          ..posY = step.posY ?? 0
          ..clickCount = step.clickCount
          ..isRandom = step.isRandom,
      );

      existing
        ..posX = step.posX ?? existing.posX
        ..posY = step.posY ?? existing.posY
        ..clickCount = step.clickCount
        ..isRandom = step.isRandom
        ..fixedIntervalMs = step.fixedIntervalMs
        ..randomMinMs = step.randomMinMs
        ..randomMaxMs = step.randomMaxMs
        ..loopCount = step.loopCount
        ..floatingId = step.floatingId ?? existing.floatingId;

      if (existing.isInBox) {
        await existing.save();
      } else {
        await stepsBox.add(existing);
      }
    }

    // 再同步 TaskEntity 的一些基础信息
    taskEntity
      ..taskType = 2
      ..name = task.name
      ..description = task.description
    // 让顶层也带一份最近一次编辑的点击配置（可选，但方便别处复用）
      ..clickCount = task.clickCount
      ..isRandom = task.isRandom
      ..fixedIntervalMs = task.fixedIntervalMs
      ..randomMinMs = task.randomMinMs
      ..randomMaxMs = task.randomMaxMs;

    await taskEntity.save();
  } else {
    // 单任务：全都保存在 TaskEntity 里
    taskEntity
      ..taskType = 1
      ..posX = task.posX
      ..posY = task.posY
      ..clickCount = task.clickCount
      ..isRandom = task.isRandom
      ..fixedIntervalMs = task.fixedIntervalMs
      ..randomMinMs = task.randomMinMs
      ..randomMaxMs = task.randomMaxMs
      ..name = task.name
      ..description = task.description;

    await taskEntity.save();
  }
}
