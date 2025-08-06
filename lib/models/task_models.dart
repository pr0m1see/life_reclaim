import 'package:flutter/material.dart';
import 'package:life_reclaim/services/database/database.dart';

// 使用database.dart中定义的枚举
export '../services/database/database.dart' show TaskStatus, TaskPriority;

// 导出任务拆分相关模型
export 'task_decomposition_models.dart';

// Activity页面时间段枚举
enum ActivityPeriod {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
}

// 标签模型
class TagModel {
  final int id;
  final String name;
  final Color color;
  final bool isSystem;

  TagModel({
    required this.id,
    required this.name,
    required this.color,
    this.isSystem = false,
  });

  TagModel copyWith({
    int? id,
    String? name,
    Color? color,
    bool? isSystem,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}

// 任务模型
class TaskModel {
  final int id;
  final String title;
  final int? parentId;
  final TaskStatus status;
  final TaskPriority priority;
  final int? estimatedMinutes;
  final DateTime? startedAt; // 第一次开始工作时间
  final DateTime? currentSessionStartedAt; // 当前会话开始时间
  final DateTime? completedAt;
  final int? actualMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TaskModel> subtasks;
  final List<TagModel> tags;

  TaskModel({
    required this.id,
    required this.title,
    this.parentId,
    required this.status,
    required this.priority,
    this.estimatedMinutes,
    this.startedAt,
    this.currentSessionStartedAt,
    this.completedAt,
    this.actualMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.subtasks = const [],
    this.tags = const [],
  });

  TaskModel copyWith({
    int? id,
    String? title,
    int? parentId,
    TaskStatus? status,
    TaskPriority? priority,
    int? estimatedMinutes,
    DateTime? startedAt,
    DateTime? currentSessionStartedAt,
    DateTime? completedAt,
    int? actualMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TaskModel>? subtasks,
    List<TagModel>? tags,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      parentId: parentId ?? this.parentId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      startedAt: startedAt ?? this.startedAt,
      currentSessionStartedAt: currentSessionStartedAt ?? this.currentSessionStartedAt,
      completedAt: completedAt ?? this.completedAt,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subtasks: subtasks ?? this.subtasks,
      tags: tags ?? this.tags,
    );
  }

  // 获取任务状态显示文本
  String get statusText {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.active:
        return 'Active';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  // 获取优先级显示文本
  String get priorityText {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return 'Important & Urgent';
      case TaskPriority.importantNotUrgent:
        return 'Important & Not Urgent';
      case TaskPriority.urgentNotImportant:
        return 'Urgent & Not Important';
    }
  }

  // 获取优先级颜色
  Color get priorityColor {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return Colors.red;
      case TaskPriority.importantNotUrgent:
        return Colors.orange;
      case TaskPriority.urgentNotImportant:
        return Colors.yellow;
    }
  }

  // 是否正在进行中
  bool get isActive => status == TaskStatus.active;

  // 是否已完成
  bool get isCompleted => status == TaskStatus.completed;

  // 是否有子任务
  bool get hasSubtasks => subtasks.isNotEmpty;

  // 所有子任务是否都已完成
  bool get allSubtasksCompleted {
    if (!hasSubtasks) return false;
    return subtasks.every((subtask) => subtask.isCompleted);
  }

  // 是否有任何子任务已完成
  bool get hasCompletedSubtasks {
    if (!hasSubtasks) return false;
    return subtasks.any((subtask) => subtask.isCompleted);
  }

  // 已完成的子任务数量
  int get completedSubtasksCount {
    if (!hasSubtasks) return 0;
    return subtasks.where((subtask) => subtask.isCompleted).length;
  }

  // 是否应该显示checkbox（只有没有子任务的任务才显示checkbox）
  bool get shouldShowCheckbox => !hasSubtasks;

  // 工作时长（分钟）
  int get totalMinutes {
    int total = actualMinutes ?? 0;
    // 如果正在进行当前会话，加上当前会话时间
    if (currentSessionStartedAt != null) {
      total += DateTime.now().difference(currentSessionStartedAt!).inMinutes;
    }
    return total;
  }

  // 工作时长显示文本
  String get durationText {
    final minutes = totalMinutes;
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  // 为Today页面格式化时间显示
  String get todayTimeText {
    if (isCompleted) {
      if (startedAt != null && completedAt != null) {
        // 已完成任务：显示 第一次开始时间-完成时间 (总工作时间)
        final startTime = _formatTime(startedAt!);
        final endTime = _formatTime(completedAt!);
        final duration = actualMinutes != null ? '${actualMinutes}m' : '0m';
        return '$startTime-$endTime ($duration)';
      } else {
        // 直接完成的任务（没有激活过）：显示预估时间
        final estimated = estimatedMinutes ?? 0;
        return '(${estimated}m)';
      }
    } else if (isActive && startedAt != null) {
      // 正在进行任务：显示 第一次开始时间 (已工作时间)
      final startTime = _formatTime(startedAt!);
      final workedMinutes = totalMinutes;
      return '$startTime (${workedMinutes}m)';
    } else if (startedAt != null) {
      // 已停止但未完成的任务：显示开始时间和工作时间
      final startTime = _formatTime(startedAt!);
      if (actualMinutes != null && actualMinutes! > 0) {
        return '$startTime (${actualMinutes}m)';
      } else {
        return startTime;
      }
    } else if (actualMinutes != null && actualMinutes! > 0) {
      // 已停止但未完成的任务：显示总工作时间
      return '${actualMinutes}m worked';
    }
    return '';
  }

  // 格式化时间显示
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
} 