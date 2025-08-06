import '../models/task_suggestion_models.dart';

/// Abstract interface for task suggestion services
/// 
/// Defines the contract for services that provide AI-powered task analysis
/// and suggestions for tags, priority, and time estimates.
abstract class TaskSuggestionService {
  /// Service identification
  String get serviceName;
  
  /// Check if the service is currently available
  bool get isAvailable;
  
  /// Service priority (higher = preferred)
  int get priority;
  
  /// Initialize the service
  Future<void> initialize();
  
  /// Suggest task attributes based on title and context
  /// 
  /// Analyzes the provided task information and returns suggestions
  /// for tags, priority level, and time estimation.
  Future<TaskSuggestionResponse> suggestTaskAttributes(
    TaskSuggestionRequest request,
  );
  
  /// Record user feedback for improving future suggestions
  /// 
  /// This data is used to learn user preferences and improve
  /// the accuracy of future suggestions.
  Future<void> recordUserFeedback(
    TaskSuggestionRequest request,
    TaskSuggestionResponse response,
    UserFeedback feedback,
  );
  
  /// Get service health information
  Future<ServiceHealthInfo> getHealthInfo();
  
  /// Dispose of service resources
  Future<void> dispose();
}

/// Service health information
class ServiceHealthInfo {
  final bool isHealthy;
  final String status;
  final Map<String, dynamic> details;
  final DateTime lastChecked;

  const ServiceHealthInfo({
    required this.isHealthy,
    required this.status,
    this.details = const {},
    required this.lastChecked,
  });

  factory ServiceHealthInfo.healthy({
    String status = 'Service is operational',
    Map<String, dynamic> details = const {},
  }) => ServiceHealthInfo(
    isHealthy: true,
    status: status,
    details: details,
    lastChecked: DateTime.now(),
  );

  factory ServiceHealthInfo.unhealthy({
    required String status,
    Map<String, dynamic> details = const {},
  }) => ServiceHealthInfo(
    isHealthy: false,
    status: status,
    details: details,
    lastChecked: DateTime.now(),
  );

  @override
  String toString() => 'ServiceHealth(healthy: $isHealthy, status: $status)';
}

/// Observable task suggestion service for state management
/// 
/// Provides reactive capabilities for UI components to listen
/// to service state changes.
abstract class ObservableTaskSuggestionService extends TaskSuggestionService {
  /// Stream of service availability changes
  Stream<bool> get availabilityStream;
  
  /// Stream of suggestion responses
  Stream<TaskSuggestionResponse> get suggestionStream;
  
  /// Stream of error events
  Stream<TaskSuggestionException> get errorStream;
  
  /// Notify listeners of suggestion start
  void notifySuggestionStarted(TaskSuggestionRequest request);
  
  /// Notify listeners of suggestion completion
  void notifySuggestionCompleted(
    TaskSuggestionRequest request,
    TaskSuggestionResponse response,
  );
  
  /// Notify listeners of suggestion failure
  void notifySuggestionFailed(
    TaskSuggestionRequest request,
    TaskSuggestionException error,
  );
} 