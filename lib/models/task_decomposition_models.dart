import 'package:flutter/foundation.dart';
import 'task_models.dart';

/// 任务拆分模式枚举
enum TaskDecompositionMode {
  ai,      // AI生成
  manual,  // 手动创建
  hybrid,  // 混合模式
}

/// 任务拆分模式扩展方法
extension TaskDecompositionModeExtension on TaskDecompositionMode {
  String get displayName {
    switch (this) {
      case TaskDecompositionMode.ai:
        return 'AI Suggestions';
      case TaskDecompositionMode.manual:
        return 'Manual Creation';
      case TaskDecompositionMode.hybrid:
        return 'Hybrid Mode';
    }
  }
  
  String get description {
    switch (this) {
      case TaskDecompositionMode.ai:
        return 'AI intelligently analyzes and generates suggestions';
      case TaskDecompositionMode.manual:
        return 'Manually create and edit subtasks';
      case TaskDecompositionMode.hybrid:
        return 'AI suggestions + manual adjustments';
    }
  }
}

/// 子任务建议模型
@immutable
class SubtaskSuggestion {
  final String id;
  final String title;
  final String? description;
  final Duration? estimatedDuration;
  final List<String> suggestedTags;
  final TaskPriority? suggestedPriority;
  final bool isAccepted; // 用户是否接受此建议
  final bool isModified; // 用户是否修改过
  final int order; // 显示顺序

  const SubtaskSuggestion({
    required this.id,
    required this.title,
    this.description,
    this.estimatedDuration,
    this.suggestedTags = const [],
    this.suggestedPriority,
    this.isAccepted = false,
    this.isModified = false,
    this.order = 0,
  });

  SubtaskSuggestion copyWith({
    String? id,
    String? title,
    String? description,
    Duration? estimatedDuration,
    List<String>? suggestedTags,
    TaskPriority? suggestedPriority,
    bool? isAccepted,
    bool? isModified,
    int? order,
  }) {
    return SubtaskSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      suggestedPriority: suggestedPriority ?? this.suggestedPriority,
      isAccepted: isAccepted ?? this.isAccepted,
      isModified: isModified ?? this.isModified,
      order: order ?? this.order,
    );
  }

  /// 估算时间的分钟数
  int? get estimatedMinutes => estimatedDuration?.inMinutes;

  /// 是否为有效的子任务建议
  bool get isValid => title.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtaskSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SubtaskSuggestion{id: $id, title: $title, accepted: $isAccepted, modified: $isModified}';
  }
}

/// 任务拆分结果模型
@immutable
class TaskDecompositionResult {
  final List<SubtaskSuggestion> suggestions;
  final TaskDecompositionMode mode;
  final String? errorMessage;
  final double confidence; // AI建议的置信度 (0.0 - 1.0)
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // 额外的元数据

  const TaskDecompositionResult({
    required this.suggestions,
    required this.mode,
    this.errorMessage,
    this.confidence = 0.0,
    required this.createdAt,
    this.metadata = const {},
  });

  /// 创建空的拆分结果（手动模式）
  factory TaskDecompositionResult.empty() => TaskDecompositionResult(
        suggestions: [],
        mode: TaskDecompositionMode.manual,
        createdAt: DateTime.now(),
      );

  /// 创建错误结果
  factory TaskDecompositionResult.error(String errorMessage) =>
      TaskDecompositionResult(
        suggestions: [],
        mode: TaskDecompositionMode.manual,
        errorMessage: errorMessage,
        createdAt: DateTime.now(),
      );

  /// 创建AI成功结果
  factory TaskDecompositionResult.aiSuccess(
    List<SubtaskSuggestion> suggestions, {
    double confidence = 0.8,
    Map<String, dynamic> metadata = const {},
  }) =>
      TaskDecompositionResult(
        suggestions: suggestions,
        mode: TaskDecompositionMode.ai,
        confidence: confidence,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

  TaskDecompositionResult copyWith({
    List<SubtaskSuggestion>? suggestions,
    TaskDecompositionMode? mode,
    String? errorMessage,
    double? confidence,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return TaskDecompositionResult(
      suggestions: suggestions ?? this.suggestions,
      mode: mode ?? this.mode,
      errorMessage: errorMessage ?? this.errorMessage,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 是否成功生成建议
  bool get isSuccess => errorMessage == null;

  /// 是否有错误
  bool get hasError => errorMessage != null;

  /// 已接受的建议数量
  int get acceptedCount => suggestions.where((s) => s.isAccepted).length;

  /// 已修改的建议数量
  int get modifiedCount => suggestions.where((s) => s.isModified).length;

  /// 获取有效的建议（已接受或已修改的）
  List<SubtaskSuggestion> get validSuggestions =>
      suggestions.where((s) => s.isAccepted && s.isValid).toList();

  /// 置信度等级
  String get confidenceLevel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }

  @override
  String toString() {
    return 'TaskDecompositionResult{mode: $mode, suggestions: ${suggestions.length}, confidence: $confidence, error: $errorMessage}';
  }
}

/// 任务拆分状态
enum TaskDecompositionStatus {
  initial,    // 初始状态
  loading,    // 正在处理
  success,    // 成功生成
  error,      // 出现错误
  saving,     // 正在保存
  saved,      // 已保存
}

/// 任务拆分状态扩展
extension TaskDecompositionStatusExtension on TaskDecompositionStatus {
  bool get isLoading => this == TaskDecompositionStatus.loading;
  bool get isSuccess => this == TaskDecompositionStatus.success;
  bool get hasError => this == TaskDecompositionStatus.error;
  bool get isSaving => this == TaskDecompositionStatus.saving;
  bool get isSaved => this == TaskDecompositionStatus.saved;
} 