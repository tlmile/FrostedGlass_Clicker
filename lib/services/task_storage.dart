import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:hive/hive.dart';

import '../models/click_task.dart';
import '../models/task_entity.dart';
import '../models/step_identifier.dart';

class WorkflowExecutionData {
  WorkflowExecutionData({
    required this.steps,
    this.loopCount,
  });

  /// 每一步的执行参数（传给原生 executeWorkflow 的 steps 列表）
  final List<Map<String, Object?>> steps;

  /// 循环次数（仅对第 1 步有效，0 表示无限循环）
  final int? loopCount;

  /// 下一个步骤索引（用于新增步骤时计算 index）
  int get nextStepIndex => generateStepId();
}

class TaskStorage {
  TaskStorage(this._tasksBox, this._stepsBox);

  final Box<TaskEntity> _tasksBox;
  final Box<StepEntity> _stepsBox;

  static const int _popupAnchorOffsetX = 60;
  static const int _popupAnchorOffsetY = 0;

  bool get isReady => _tasksBox.isOpen && _stepsBox.isOpen;

  int nextListIndex(int fallbackLength) {
    if (!isReady || _tasksBox.isEmpty) {
      return fallbackLength;
    }
    return _tasksBox.values
        .map((entity) => entity.listIndex)
        .fold<int>(0, (previousValue, element) =>
    previousValue > element ? previousValue : element) +
        1;
  }

  /// 从步骤表加载指定任务的所有步骤，并按 stepNumber 排序
  List<StepEntity> loadSteps(String taskId) {
    if (!isReady) return [];
    final steps =
    _stepsBox.values.where((element) => element.taskId == taskId).toList();
    steps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    return steps;
  }

  /// 从 Hive 中恢复所有任务（含工作流步骤）
  Future<List<ClickTask>> restoreTasks() async {
    if (!isReady) return [];

    final entities = _tasksBox.values.toList()
      ..sort((a, b) => b.listIndex.compareTo(a.listIndex));

    return entities
        .map(
          (entity) => entity.toClickTask(loadSteps(entity.taskId)),
    )
        .toList();
  }

  /// 保存单击任务（非工作流），包括随机/固定间隔配置
  Future<void> saveSingleClickTask({
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
    if (!isReady) return;

    final existing = _tasksBox.get(finalId);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = finalId
      ..taskType = 1
      ..listIndex = existing?.listIndex ?? nextListIndex(_tasksBox.length)
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

    // 单任务模式下，清掉所有旧的步骤记录
    final keysToDelete = _stepsBox.keys
        .where((key) => _stepsBox.get(key)?.taskId == finalId)
        .toList();
    await _stepsBox.deleteAll(keysToDelete);
  }

  /// 保存工作流中的某一步
  Future<void> saveWorkflowStep({
    required String finalId,
    required String finalName,
    String? description,
    required WorkflowStep step,
    required String Function(int stepIndex) floatingIdBuilder,
  }) async {
    if (!isReady) return;

    // 任务壳：类型标记为工作流，坐标和单次配置清空
    final existing = _tasksBox.get(finalId);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = finalId
      ..taskType = 2
      ..listIndex = existing?.listIndex ?? nextListIndex(_tasksBox.length)
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

    // 循环配置：0 表示无限循环（仅显示第 1 步会带值）
    final loopValue = step.loopInfinite == true
        ? 0
        : (step.loopCount == null
            ? null
            : (step.loopCount! < 1 ? 1 : step.loopCount));

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
      ..floatingId = step.floatingId ?? floatingIdBuilder(step.index)
      ..loopCount = loopValue;

    await _stepsBox.put('${finalId}_${step.index}', stepEntity);
  }

  /// 保存仅用于展示的工作流壳（无步骤时）
  Future<void> saveWorkflowShell(ClickTask task) async {
    if (!isReady) return;
    final existing = _tasksBox.get(task.id);
    final entity = existing ?? TaskEntity();
    entity
      ..taskId = task.id
      ..taskType = 2
      ..listIndex = existing?.listIndex ?? nextListIndex(_tasksBox.length)
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

  TaskEntity? getTaskEntity(String taskId) => _tasksBox.get(taskId);

  /// 单任务执行参数：
  /// - 会把 isRandom、fixedIntervalMs、randomMinMs、randomMaxMs 原样传给原生
  /// - 原生 AutoClickExecutor 会据此决定使用固定间隔还是随机间隔
  Map<String, Object?>? buildSingleExecutionArgs(String taskId) {
    if (!isReady) return null;
    final entity = _tasksBox.get(taskId);
    if (entity == null || entity.posX == null || entity.posY == null) {
      return null;
    }

    return <String, Object?>{
      'taskId': entity.taskId,
      'x': entity.posX,
      'y': entity.posY,
      'clickCount': entity.clickCount ?? 1,
      'isRandom': entity.isRandom ?? false,
      if (entity.fixedIntervalMs != null) 'fixedIntervalMs': entity.fixedIntervalMs,
      if (entity.randomMinMs != null) 'randomMinMs': entity.randomMinMs,
      if (entity.randomMaxMs != null) 'randomMaxMs': entity.randomMaxMs,
    };
  }

  /// 工作流执行参数：
  /// - 每个步骤自己的 isRandom / fixedIntervalMs / randomMinMs / randomMaxMs 都会带上
  /// - 第一步如果有 loopCount，会额外传 loopCount / loopInfinite
  WorkflowExecutionData? buildWorkflowExecutionData(
    String taskId,
    String Function(int stepIndex) floatingIdBuilder,
  ) {
    if (!isReady) return null;
    final entity = _tasksBox.get(taskId);
    if (entity == null) return null;

    final steps = loadSteps(taskId);
    if (steps.isEmpty) return null;

    final payload = <Map<String, Object?>>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final displayNumber = i + 1;
      final anchor = _buildPopupAnchor(s.posX, s.posY);
      payload.add({
        'x': s.posX,
        'y': s.posY,
        if (anchor != null) 'popupAnchorX': anchor.dx,
        if (anchor != null) 'popupAnchorY': anchor.dy,
        'index': s.stepNumber,
        'displayNumber': displayNumber,
        'stepIndex': s.stepNumber,
        'floatingId': s.floatingId ?? floatingIdBuilder(s.stepNumber),
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

    final StepEntity? firstStep = steps.isNotEmpty ? steps.first : null;

    debugPrint(
        '[TaskStorage] buildWorkflowExecutionData task=$taskId steps=${payload.length} loopCount=${firstStep?.loopCount}');

    return WorkflowExecutionData(
      steps: payload,
      loopCount: firstStep?.loopCount,
    );
  }

  /// 删除任务及其所有步骤
  Future<void> deleteTask(String taskId) async {
    if (!isReady) return;
    await _tasksBox.delete(taskId);
    final keysToDelete = _stepsBox.keys
        .where((key) => _stepsBox.get(key)?.taskId == taskId)
        .toList();
    await _stepsBox.deleteAll(keysToDelete);
  }

  Offset? _buildPopupAnchor(int? x, int? y) {
    if (x == null || y == null) return null;
    return Offset(
      (x + _popupAnchorOffsetX).toDouble(),
      (y + _popupAnchorOffsetY).toDouble(),
    );
  }
}
