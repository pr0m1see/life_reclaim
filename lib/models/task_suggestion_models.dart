import 'package:flutter/material.dart';
import 'task_models.dart';

/// User feedback model for tracking AI suggestion quality
enum UserFeedbackType {
  accepted,
  rejected,
  modified,
}

class UserFeedback {
  final UserFeedbackType type;
  final String suggestionType; // 'tag', 'priority', 'timeEstimate'
  final dynamic originalValue;
  final dynamic finalValue;
  final DateTime timestamp;
  final String? userComment;

  const UserFeedback({
    required this.type,
    required this.suggestionType,
    required this.originalValue,
    required this.finalValue,
    required this.timestamp,
    this.userComment,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'suggestionType': suggestionType,
    'originalValue': originalValue.toString(),
    'finalValue': finalValue.toString(),
    'timestamp': timestamp.toIso8601String(),
    'userComment': userComment,
  };

  factory UserFeedback.fromJson(Map<String, dynamic> json) => UserFeedback(
    type: UserFeedbackType.values.firstWhere((e) => e.name == json['type']),
    suggestionType: json['suggestionType'],
    originalValue: json['originalValue'],
    finalValue: json['finalValue'],
    timestamp: DateTime.parse(json['timestamp']),
    userComment: json['userComment'],
  );
}

/// Request model for task analysis
class TaskSuggestionRequest {
  final String title;

  const TaskSuggestionRequest({
    required this.title,
  });

  TaskSuggestionRequest copyWith({
    String? title,
  }) => TaskSuggestionRequest(
    title: title ?? this.title,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
  };

  /// Generate cache key for this request
  String get cacheKey => title.trim().toLowerCase();

  /// Check if request has sufficient data for analysis
  bool get isValid => title.trim().isNotEmpty;
}

/// Suggested tag with confidence and reasoning
class SuggestedTag {
  final String name;
  final Color color;
  final double confidence;
  final String reasoning;
  final bool isExistingTag;

  const SuggestedTag({
    required this.name,
    required this.color,
    required this.confidence,
    required this.reasoning,
    this.isExistingTag = false,
  });

  SuggestedTag copyWith({
    String? name,
    Color? color,
    double? confidence,
    String? reasoning,
    bool? isExistingTag,
  }) => SuggestedTag(
    name: name ?? this.name,
    color: color ?? this.color,
    confidence: confidence ?? this.confidence,
    reasoning: reasoning ?? this.reasoning,
    isExistingTag: isExistingTag ?? this.isExistingTag,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.value,
    'confidence': confidence,
    'reasoning': reasoning,
    'isExistingTag': isExistingTag,
  };

  factory SuggestedTag.fromJson(Map<String, dynamic> json) => SuggestedTag(
    name: json['name'],
    color: Color(json['color']),
    confidence: json['confidence'].toDouble(),
    reasoning: json['reasoning'],
    isExistingTag: json['isExistingTag'] ?? false,
  );

  /// Convert to TagModel
  TagModel toTagModel({int? id}) => TagModel(
    id: id ?? name.hashCode,
    name: name,
    color: color,
    isSystem: false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestedTag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'SuggestedTag(name: $name, confidence: $confidence)';
}

/// Suggested priority with confidence and reasoning
class SuggestedPriority {
  final TaskPriority priority;
  final double confidence;
  final String reasoning;

  const SuggestedPriority({
    required this.priority,
    required this.confidence,
    required this.reasoning,
  });

  SuggestedPriority copyWith({
    TaskPriority? priority,
    double? confidence,
    String? reasoning,
  }) => SuggestedPriority(
    priority: priority ?? this.priority,
    confidence: confidence ?? this.confidence,
    reasoning: reasoning ?? this.reasoning,
  );

  Map<String, dynamic> toJson() => {
    'priority': priority.name,
    'confidence': confidence,
    'reasoning': reasoning,
  };

  factory SuggestedPriority.fromJson(Map<String, dynamic> json) => SuggestedPriority(
    priority: TaskPriority.values.firstWhere((p) => p.name == json['priority']),
    confidence: json['confidence'].toDouble(),
    reasoning: json['reasoning'],
  );

  /// Get priority display name
  String get displayName {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return 'Important & Urgent';
      case TaskPriority.importantNotUrgent:
        return 'Important & Not Urgent';
      case TaskPriority.urgentNotImportant:
        return 'Urgent & Not Important';
    }
  }

  /// Get priority description
  String get description {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return 'Requires immediate attention and action';
      case TaskPriority.importantNotUrgent:
        return 'Important for long-term goals, schedule time';
      case TaskPriority.urgentNotImportant:
        return 'Delegate or minimize time spent';
    }
  }

  @override
  String toString() => 'SuggestedPriority(priority: $priority, confidence: $confidence)';
}

/// Suggested time estimate with range and reasoning
class SuggestedTimeEstimate {
  final int estimatedMinutes;
  final int minEstimate;
  final int maxEstimate;
  final double confidence;
  final String reasoning;

  const SuggestedTimeEstimate({
    required this.estimatedMinutes,
    required this.minEstimate,
    required this.maxEstimate,
    required this.confidence,
    required this.reasoning,
  });

  SuggestedTimeEstimate copyWith({
    int? estimatedMinutes,
    int? minEstimate,
    int? maxEstimate,
    double? confidence,
    String? reasoning,
  }) => SuggestedTimeEstimate(
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    minEstimate: minEstimate ?? this.minEstimate,
    maxEstimate: maxEstimate ?? this.maxEstimate,
    confidence: confidence ?? this.confidence,
    reasoning: reasoning ?? this.reasoning,
  );

  Map<String, dynamic> toJson() => {
    'estimatedMinutes': estimatedMinutes,
    'minEstimate': minEstimate,
    'maxEstimate': maxEstimate,
    'confidence': confidence,
    'reasoning': reasoning,
  };

  factory SuggestedTimeEstimate.fromJson(Map<String, dynamic> json) => SuggestedTimeEstimate(
    estimatedMinutes: json['estimatedMinutes'],
    minEstimate: json['minEstimate'],
    maxEstimate: json['maxEstimate'],
    confidence: json['confidence'].toDouble(),
    reasoning: json['reasoning'],
  );

  /// Get formatted time display
  String get displayTime {
    if (estimatedMinutes < 60) {
      return '${estimatedMinutes}m';
    } else {
      final hours = estimatedMinutes ~/ 60;
      final minutes = estimatedMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  /// Get formatted range display
  String get rangeDisplay {
    return '${_formatMinutes(minEstimate)} - ${_formatMinutes(maxEstimate)}';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }

  /// Check if estimate is within reasonable bounds
  bool get isReasonable => 
      estimatedMinutes >= 5 && 
      estimatedMinutes <= 480 && // max 8 hours
      minEstimate <= estimatedMinutes && 
      estimatedMinutes <= maxEstimate;

  @override
  String toString() => 'SuggestedTimeEstimate(estimated: $estimatedMinutes min, confidence: $confidence)';
}

/// Complete response model containing all AI suggestions
class TaskSuggestionResponse {
  final List<SuggestedTag> tagSuggestions;
  final SuggestedPriority prioritySuggestion;
  final SuggestedTimeEstimate timeSuggestion;
  final double confidence;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String serviceUsed;

  const TaskSuggestionResponse({
    required this.tagSuggestions,
    required this.prioritySuggestion,
    required this.timeSuggestion,
    required this.confidence,
    this.metadata = const {},
    required this.timestamp,
    required this.serviceUsed,
  });

  TaskSuggestionResponse copyWith({
    List<SuggestedTag>? tagSuggestions,
    SuggestedPriority? prioritySuggestion,
    SuggestedTimeEstimate? timeSuggestion,
    double? confidence,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    String? serviceUsed,
  }) => TaskSuggestionResponse(
    tagSuggestions: tagSuggestions ?? this.tagSuggestions,
    prioritySuggestion: prioritySuggestion ?? this.prioritySuggestion,
    timeSuggestion: timeSuggestion ?? this.timeSuggestion,
    confidence: confidence ?? this.confidence,
    metadata: metadata ?? this.metadata,
    timestamp: timestamp ?? this.timestamp,
    serviceUsed: serviceUsed ?? this.serviceUsed,
  );

  Map<String, dynamic> toJson() => {
    'tagSuggestions': tagSuggestions.map((tag) => tag.toJson()).toList(),
    'prioritySuggestion': prioritySuggestion.toJson(),
    'timeSuggestion': timeSuggestion.toJson(),
    'confidence': confidence,
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
    'serviceUsed': serviceUsed,
  };

  factory TaskSuggestionResponse.fromJson(Map<String, dynamic> json) => TaskSuggestionResponse(
    tagSuggestions: (json['tagSuggestions'] as List)
        .map((tag) => SuggestedTag.fromJson(tag))
        .toList(),
    prioritySuggestion: SuggestedPriority.fromJson(json['prioritySuggestion']),
    timeSuggestion: SuggestedTimeEstimate.fromJson(json['timeSuggestion']),
    confidence: json['confidence'].toDouble(),
    metadata: json['metadata'] ?? {},
    timestamp: DateTime.parse(json['timestamp']),
    serviceUsed: json['serviceUsed'],
  );

  /// Create empty response for fallback scenarios
  factory TaskSuggestionResponse.empty({
    required String serviceUsed,
    String reason = 'No suggestions available',
  }) => TaskSuggestionResponse(
    tagSuggestions: [],
    prioritySuggestion: SuggestedPriority(
      priority: TaskPriority.importantNotUrgent,
      confidence: 0.1,
      reasoning: 'Default priority due to: $reason',
    ),
    timeSuggestion: SuggestedTimeEstimate(
      estimatedMinutes: 30,
      minEstimate: 15,
      maxEstimate: 60,
      confidence: 0.1,
      reasoning: 'Default estimate due to: $reason',
    ),
    confidence: 0.1,
    metadata: {'reason': reason},
    timestamp: DateTime.now(),
    serviceUsed: serviceUsed,
  );

  /// Create error response
  factory TaskSuggestionResponse.error({
    required String serviceUsed,
    required String error,
  }) => TaskSuggestionResponse.empty(
    serviceUsed: serviceUsed,
    reason: error,
  ).copyWith(
    metadata: {'error': error, 'reason': 'Error occurred'},
  );

  /// Check if response has valid suggestions
  bool get hasValidSuggestions => 
      tagSuggestions.isNotEmpty || 
      confidence > 0.5;

  /// Get overall quality score
  double get qualityScore {
    final tagQuality = tagSuggestions.isEmpty ? 0.0 : 
        tagSuggestions.map((t) => t.confidence).reduce((a, b) => a + b) / tagSuggestions.length;
    final priorityQuality = prioritySuggestion.confidence;
    final timeQuality = timeSuggestion.confidence;
    
    return (tagQuality + priorityQuality + timeQuality) / 3;
  }

  /// Get processing time from metadata
  Duration? get processingTime {
    final ms = metadata['processingTimeMs'];
    return ms != null ? Duration(milliseconds: ms) : null;
  }

  @override
  String toString() => 'TaskSuggestionResponse(confidence: $confidence, service: $serviceUsed, tags: ${tagSuggestions.length})';
}

/// Exception for task suggestion errors
class TaskSuggestionException implements Exception {
  final String message;
  final String? serviceUsed;
  final dynamic originalError;

  const TaskSuggestionException(
    this.message, {
    this.serviceUsed,
    this.originalError,
  });

  @override
  String toString() => 'TaskSuggestionException: $message${serviceUsed != null ? ' (service: $serviceUsed)' : ''}';
} 