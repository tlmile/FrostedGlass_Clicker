import 'package:flutter/material.dart';

/// ------------------------------
/// Workflow Step 模型（单个悬浮球配置）
/// ------------------------------
class WorkflowStep {
  final int index;
  final int? posX;
  final int? posY;
  final int clickCount;
  final bool isRandom;
  final int? fixedIntervalMs;
  final int? randomMinMs;
  final int? randomMaxMs;
  final String? themeId;
  final String? floatingId;

  /// 🔥 新增：循环次数（只有第一步有效）
  final int? loopCount;

  /// 🔥 新增：是否无限循环
  final bool? loopInfinite;

  const WorkflowStep({
    required this.index,
    this.posX,
    this.posY,
    this.clickCount = 1,
    this.isRandom = false,
    this.fixedIntervalMs,
    this.randomMinMs,
    this.randomMaxMs,
    this.themeId,
    this.floatingId,
    this.loopCount,
    this.loopInfinite,
  });

  WorkflowStep copyWith({
    int? index,
    int? posX,
    int? posY,
    int? clickCount,
    bool? isRandom,
    int? fixedIntervalMs,
    int? randomMinMs,
    int? randomMaxMs,
    String? themeId,
    String? floatingId,
    int? loopCount,
    bool? loopInfinite,
  }) {
    return WorkflowStep(
      index: index ?? this.index,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      clickCount: clickCount ?? this.clickCount,
      isRandom: isRandom ?? this.isRandom,
      fixedIntervalMs: fixedIntervalMs ?? this.fixedIntervalMs,
      randomMinMs: randomMinMs ?? this.randomMinMs,
      randomMaxMs: randomMaxMs ?? this.randomMaxMs,
      themeId: themeId ?? this.themeId,
      floatingId: floatingId ?? this.floatingId,
      loopCount: loopCount ?? this.loopCount,
      loopInfinite: loopInfinite ?? this.loopInfinite,
    );
  }

  /// 发送给 Android 的完整结构
  Map<String, Object?> toMap({int? displayNumber}) {
    return {
      'index': index,
      'stepIndex': index,
      if (posX != null) 'x': posX,
      if (posY != null) 'y': posY,
      'clickCount': clickCount,
      'isRandom': isRandom,
      if (fixedIntervalMs != null) 'fixedIntervalMs': fixedIntervalMs,
      if (randomMinMs != null) 'randomMinMs': randomMinMs,
      if (randomMaxMs != null) 'randomMaxMs': randomMaxMs,
      if (themeId != null) 'themeId': themeId,
      if (floatingId != null) 'floatingId': floatingId,

      /// 🔥 工作流循环配置（非常关键）
      if (loopCount != null) 'loopCount': loopCount,
      if (loopInfinite != null) 'loopInfinite': loopInfinite,

      /// Android UI 会使用 displayNumber 显示步骤序号
      'displayNumber': displayNumber ?? index,
    };
  }
}

/// ------------------------------
/// ClickTask（任务模型）
/// ------------------------------
class ClickTask {
  final String id;
  final String name;
  final String description;
  final bool isWorkflow;
  final DateTime createdAt;

  final List<WorkflowStep> workflowSteps;

  // 单击任务参数
  final int? posX;
  final int? posY;
  final int clickCount;
  final bool isRandom;
  final int? fixedIntervalMs;
  final int? randomMinMs;
  final int? randomMaxMs;
  final String? themeId;

  /// 🔥 工作流循环配置同步到 Task 层（可选）
  final int? loopCount;
  final bool? loopInfinite;

  ClickTask({
    required this.id,
    required this.name,
    required this.description,
    required this.isWorkflow,
    required this.createdAt,
    this.workflowSteps = const [],
    this.posX,
    this.posY,
    this.clickCount = 1,
    this.isRandom = false,
    this.fixedIntervalMs,
    this.randomMinMs,
    this.randomMaxMs,
    this.themeId,
    this.loopCount,
    this.loopInfinite,
  });

  ClickTask copyWith({
    String? id,
    String? name,
    String? description,
    bool? isWorkflow,
    DateTime? createdAt,
    List<WorkflowStep>? workflowSteps,
    int? posX,
    int? posY,
    int? clickCount,
    bool? isRandom,
    int? fixedIntervalMs,
    int? randomMinMs,
    int? randomMaxMs,
    String? themeId,
    int? loopCount,
    bool? loopInfinite,
  }) {
    return ClickTask(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isWorkflow: isWorkflow ?? this.isWorkflow,
      createdAt: createdAt ?? this.createdAt,
      workflowSteps: workflowSteps ?? this.workflowSteps,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      clickCount: clickCount ?? this.clickCount,
      isRandom: isRandom ?? this.isRandom,
      fixedIntervalMs: fixedIntervalMs ?? this.fixedIntervalMs,
      randomMinMs: randomMinMs ?? this.randomMinMs,
      randomMaxMs: randomMaxMs ?? this.randomMaxMs,
      themeId: themeId ?? this.themeId,

      /// 🔥 循环参数
      loopCount: loopCount ?? this.loopCount,
      loopInfinite: loopInfinite ?? this.loopInfinite,
    );
  }
}
