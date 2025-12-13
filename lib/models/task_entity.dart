import 'package:hive/hive.dart';

import 'click_task.dart';

@HiveType(typeId: 1)
class TaskEntity extends HiveObject {
  @HiveField(0)
  late String taskId;

  @HiveField(1)
  late int listIndex;

  @HiveField(2)
  late int taskType; // 1 = single, 2 = workflow

  @HiveField(3)
  late String name;

  @HiveField(4)
  String? description;

  @HiveField(5)
  late DateTime createdAt;

  // Single click specific
  @HiveField(6)
  int? posX;

  @HiveField(7)
  int? posY;

  @HiveField(8)
  int? clickCount;

  @HiveField(9)
  bool? isRandom;

  @HiveField(10)
  int? fixedIntervalMs;

  @HiveField(11)
  int? randomMinMs;

  @HiveField(12)
  int? randomMaxMs;
}

@HiveType(typeId: 2)
class StepEntity extends HiveObject {
  @HiveField(0)
  late String taskId;

  @HiveField(1)
  late int stepNumber;

  @HiveField(2)
  late int posX;

  @HiveField(3)
  late int posY;

  @HiveField(4)
  late int clickCount;

  @HiveField(5)
  late bool isRandom;

  @HiveField(6)
  int? fixedIntervalMs;

  @HiveField(7)
  int? randomMinMs;

  @HiveField(8)
  int? randomMaxMs;

  @HiveField(9)
  int? loopCount; // Only meaningful on first step, 0 = infinite

  @HiveField(10)
  String? floatingId;
}

class TaskEntityAdapter extends TypeAdapter<TaskEntity> {
  @override
  final int typeId = 1;

  @override
  TaskEntity read(BinaryReader reader) {
    final obj = TaskEntity();
    obj.taskId = reader.readString();
    obj.listIndex = reader.readInt();
    obj.taskType = reader.readInt();
    obj.name = reader.readString();
    obj.description = reader.read();
    obj.createdAt = reader.read() as DateTime;
    obj.posX = reader.read();
    obj.posY = reader.read();
    obj.clickCount = reader.read();
    obj.isRandom = reader.read();
    obj.fixedIntervalMs = reader.read();
    obj.randomMinMs = reader.read();
    obj.randomMaxMs = reader.read();
    return obj;
  }

  @override
  void write(BinaryWriter writer, TaskEntity obj) {
    writer
      ..writeString(obj.taskId)
      ..writeInt(obj.listIndex)
      ..writeInt(obj.taskType)
      ..writeString(obj.name)
      ..write(obj.description)
      ..write(obj.createdAt)
      ..write(obj.posX)
      ..write(obj.posY)
      ..write(obj.clickCount)
      ..write(obj.isRandom)
      ..write(obj.fixedIntervalMs)
      ..write(obj.randomMinMs)
      ..write(obj.randomMaxMs);
  }
}

class StepEntityAdapter extends TypeAdapter<StepEntity> {
  @override
  final int typeId = 2;

  @override
  StepEntity read(BinaryReader reader) {
    final obj = StepEntity();
    obj.taskId = reader.readString();
    obj.stepNumber = reader.readInt();
    obj.posX = reader.readInt();
    obj.posY = reader.readInt();
    obj.clickCount = reader.readInt();
    obj.isRandom = reader.readBool();
    obj.fixedIntervalMs = reader.read();
    obj.randomMinMs = reader.read();
    obj.randomMaxMs = reader.read();
    obj.loopCount = reader.read();
    try {
      obj.floatingId = reader.read();
    } catch (_) {
      obj.floatingId = null;
    }
    return obj;
  }

  @override
  void write(BinaryWriter writer, StepEntity obj) {
    writer
      ..writeString(obj.taskId)
      ..writeInt(obj.stepNumber)
      ..writeInt(obj.posX)
      ..writeInt(obj.posY)
      ..writeInt(obj.clickCount)
      ..writeBool(obj.isRandom)
      ..write(obj.fixedIntervalMs)
      ..write(obj.randomMinMs)
      ..write(obj.randomMaxMs)
      ..write(obj.loopCount)
      ..write(obj.floatingId);
  }
}

extension TaskEntityMapper on TaskEntity {
  ClickTask toClickTask(List<StepEntity> steps) {
    if (taskType == 2) {
      final workflowSteps = List<StepEntity>.from(steps)
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      final wfSteps = workflowSteps
          .map(
          (s) => WorkflowStep(
            index: s.stepNumber,
            posX: s.posX,
            posY: s.posY,
            clickCount: s.clickCount,
            isRandom: s.isRandom,
            fixedIntervalMs: s.fixedIntervalMs,
            randomMinMs: s.randomMinMs,
            randomMaxMs: s.randomMaxMs,
            floatingId: s.floatingId ?? '${s.taskId}_${s.stepNumber}',
            loopCount: s.loopCount,
            loopInfinite: s.loopCount == 0,
          ),
        )
        .toList();

      final WorkflowStep? firstStep = wfSteps
          .cast<WorkflowStep?>()
          .firstWhere((e) => e?.index == 1, orElse: () => null) ??
          (wfSteps.isNotEmpty ? wfSteps.first : null);

      return ClickTask(
        id: taskId,
        name: name,
        description: description ?? '',
        isWorkflow: true,
        createdAt: createdAt,
        workflowSteps: wfSteps,
        loopCount: firstStep?.loopCount,
        loopInfinite: firstStep?.loopInfinite,
      );
    }

    return ClickTask(
      id: taskId,
      name: name,
      description: description ?? '',
      isWorkflow: false,
      createdAt: createdAt,
      posX: posX,
      posY: posY,
      clickCount: clickCount ?? 1,
      isRandom: isRandom ?? false,
      fixedIntervalMs: fixedIntervalMs,
      randomMinMs: randomMinMs,
      randomMaxMs: randomMaxMs,
    );
  }
}

extension StepEntityFactory on WorkflowStep {
  StepEntity toEntity(String owningTaskId) {
    final entity = StepEntity()
      ..taskId = owningTaskId
      ..stepNumber = index
      ..posX = posX ?? 0
      ..posY = posY ?? 0
      ..clickCount = clickCount
      ..isRandom = isRandom
      ..fixedIntervalMs = fixedIntervalMs
      ..randomMinMs = randomMinMs
      ..randomMaxMs = randomMaxMs
      ..floatingId = floatingId
      ..loopCount = loopInfinite == true ? 0 : loopCount;
    return entity;
  }
}
