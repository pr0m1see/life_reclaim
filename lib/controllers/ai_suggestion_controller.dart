import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/task_suggestion_models.dart';
import '../services/task_suggestion_service.dart';
import '../services/ollama_task_suggestion_service.dart';

/// User action types for tracking and analytics
enum UserAction {
  acceptedTagSuggestion,
  rejectedTagSuggestion,
  modifiedTagSuggestion,
  acceptedPrioritySuggestion,
  rejectedPrioritySuggestion,
  modifiedPrioritySuggestion,
  acceptedTimeSuggestion,
  rejectedTimeSuggestion,
  modifiedTimeSuggestion,
  triggeredManualAnalysis,
  clearedSuggestions,
}

/// User action data for analytics
class UserActionData {
  final UserAction action;
  final String? suggestionType;
  final dynamic originalValue;
  final dynamic finalValue;
  final DateTime timestamp;
  final double? suggestionConfidence;
  final String? serviceUsed;

  const UserActionData({
    required this.action,
    this.suggestionType,
    this.originalValue,
    this.finalValue,
    required this.timestamp,
    this.suggestionConfidence,
    this.serviceUsed,
  });

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'suggestionType': suggestionType,
    'originalValue': originalValue?.toString(),
    'finalValue': finalValue?.toString(),
    'timestamp': timestamp.toIso8601String(),
    'suggestionConfidence': suggestionConfidence,
    'serviceUsed': serviceUsed,
  };
}

/// AI Suggestion Controller for managing task suggestion state and interactions
/// 
/// Provides real-time task analysis, suggestion management, and user feedback tracking.
/// Integrates with multiple AI services with automatic fallback mechanisms.
class AiSuggestionController extends GetxController {
  // Service dependencies
  late final List<TaskSuggestionService> _services;
  TaskSuggestionService? _currentService;
  
  // Core state management
  final isAnalyzing = false.obs;
  final currentSuggestions = Rxn<TaskSuggestionResponse>();
  final analysisError = Rxn<String>();
  final lastAnalyzedTask = ''.obs;
  
  // Service status
  final isServiceAvailable = false.obs;
  final currentServiceName = ''.obs;
  
  // Performance tracking
  final analysisCount = 0.obs;
  final averageResponseTime = 0.obs;
  final successRate = 0.0.obs;
  final totalErrors = 0.obs;
  
  // User interaction tracking
  final userActions = <UserActionData>[].obs;
  final suggestionAcceptanceRate = 0.0.obs;
  
  // Internal state
  Timer? _debounceTimer;
  final Map<String, TaskSuggestionResponse> _cache = {};
  final List<int> _responseTimesMs = [];
  int _successfulRequests = 0;
  int _failedRequests = 0;
  
  // Configuration
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const int _maxCacheSize = 20;
  static const Duration _cacheExpiry = Duration(minutes: 30);
  
  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }
  
  @override
  void onClose() {
    _debounceTimer?.cancel();
    _disposeServices();
    super.onClose();
  }
  
  /// Initialize AI suggestion services with priority ordering
  Future<void> _initializeServices() async {
    try {
      debugPrint('[AiSuggestionController] Initializing AI suggestion services...');
      
      // Create AI service (Ollama only)
      _services = [
        OllamaTaskSuggestionService(),
      ];
      
      // Initialize all services
      for (final service in _services) {
        try {
          await service.initialize();
          debugPrint('[AiSuggestionController] Initialized ${service.serviceName}');
        } catch (e) {
          debugPrint('[AiSuggestionController] Failed to initialize ${service.serviceName}: $e');
        }
      }
      
      // Select best available service
      await _selectBestService();
      
      debugPrint('[AiSuggestionController] Initialization complete. Using: ${_currentService?.serviceName ?? "None"}');
    } catch (e) {
      debugPrint('[AiSuggestionController] Service initialization failed: $e');
      analysisError.value = 'Failed to initialize AI services: $e';
    }
  }
  
  /// Select the best available service based on priority and availability
  Future<void> _selectBestService() async {
    // Sort services by priority (descending)
    _services.sort((a, b) => b.priority.compareTo(a.priority));
    
    for (final service in _services) {
      if (service.isAvailable) {
        _currentService = service;
        isServiceAvailable.value = true;
        currentServiceName.value = service.serviceName;
        debugPrint('[AiSuggestionController] Selected service: ${service.serviceName}');
        return;
      }
    }
    
    // No services available
    _currentService = null;
    isServiceAvailable.value = false;
    currentServiceName.value = 'No service available';
    debugPrint('[AiSuggestionController] No AI services available');
  }
  
  /// Analyze task with debouncing for real-time suggestions
  /// 
  /// This method implements debounced analysis to avoid excessive API calls
  /// while providing responsive user experience.
  Future<void> analyzeTask(String title, {
    bool forceAnalysis = false,
  }) async {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Clear error state
    analysisError.value = null;
    
    // Skip analysis if title is empty or same as last analyzed
    if (title.trim().isEmpty) {
      currentSuggestions.value = null;
      lastAnalyzedTask.value = '';
      return;
    }
    
    if (!forceAnalysis && title == lastAnalyzedTask.value) {
      return; // Same task, no need to re-analyze
    }
    
    // Start debounce timer for real-time analysis
    _debounceTimer = Timer(_debounceDelay, () async {
      await _performAnalysis(title);
    });
  }
  
  /// Perform actual task analysis
  Future<void> _performAnalysis(String title) async {
    if (isAnalyzing.value) return; // Prevent concurrent analysis
     
    try {
      isAnalyzing.value = true;
      lastAnalyzedTask.value = title;
      
      // Create analysis request
      final request = TaskSuggestionRequest(
        title: title,
      );
      
      // Check cache first
      final cached = _getFromCache(request.cacheKey);
      if (cached != null) {
        currentSuggestions.value = cached;
        debugPrint('[AiSuggestionController] Using cached suggestion for: $title');
        return;
      }
      
      // Ensure service is available
      if (_currentService == null || !_currentService!.isAvailable) {
        await _selectBestService();
        if (_currentService == null) {
          throw Exception('No AI services available');
        }
      }
      
      // Perform analysis
      final startTime = DateTime.now();
      debugPrint('[AiSuggestionController] Starting analysis for: $title');
      
      final response = await _currentService!.suggestTaskAttributes(request);
      
      // Track performance
      final responseTime = DateTime.now().difference(startTime);
      _recordSuccess(responseTime);
      
      // Cache and update state
      _cacheResponse(request.cacheKey, response);
      currentSuggestions.value = response;
      
      debugPrint('[AiSuggestionController] Analysis completed for: $title (${responseTime.inMilliseconds}ms)');
      
    } catch (e) {
      _recordFailure();
      analysisError.value = 'Analysis failed: $e';
      currentSuggestions.value = null;
      
      debugPrint('[AiSuggestionController] Analysis failed for: $title - $e');
      
      // No fallback service - user will need to set manually
      
    } finally {
      isAnalyzing.value = false;
    }
  }
  

  
  /// Accept a suggestion and record user feedback
  void acceptSuggestion(String suggestionType) {
    final suggestions = currentSuggestions.value;
    if (suggestions == null) return;
    
    UserAction action;
    dynamic value;
    double confidence;
    
    switch (suggestionType.toLowerCase()) {
      case 'tag':
        action = UserAction.acceptedTagSuggestion;
        value = suggestions.tagSuggestions.map((t) => t.name).join(', ');
        confidence = suggestions.tagSuggestions.isNotEmpty 
            ? suggestions.tagSuggestions.map((t) => t.confidence).reduce((a, b) => a + b) / suggestions.tagSuggestions.length
            : 0.0;
        break;
      case 'priority':
        action = UserAction.acceptedPrioritySuggestion;
        value = suggestions.prioritySuggestion.priority.name;
        confidence = suggestions.prioritySuggestion.confidence;
        break;
      case 'time':
        action = UserAction.acceptedTimeSuggestion;
        value = suggestions.timeSuggestion.estimatedMinutes;
        confidence = suggestions.timeSuggestion.confidence;
        break;
      default:
        debugPrint('[AiSuggestionController] Unknown suggestion type: $suggestionType');
        return;
    }
    
    _recordUserAction(UserActionData(
      action: action,
      suggestionType: suggestionType,
      originalValue: value,
      finalValue: value,
      timestamp: DateTime.now(),
      suggestionConfidence: confidence,
      serviceUsed: suggestions.serviceUsed,
    ));
    
    debugPrint('[AiSuggestionController] User accepted $suggestionType suggestion');
  }
  
  /// Reject a suggestion and record user feedback
  void rejectSuggestion(String suggestionType) {
    final suggestions = currentSuggestions.value;
    if (suggestions == null) return;
    
    UserAction action;
    dynamic value;
    double confidence;
    
    switch (suggestionType.toLowerCase()) {
      case 'tag':
        action = UserAction.rejectedTagSuggestion;
        value = suggestions.tagSuggestions.map((t) => t.name).join(', ');
        confidence = suggestions.tagSuggestions.isNotEmpty 
            ? suggestions.tagSuggestions.map((t) => t.confidence).reduce((a, b) => a + b) / suggestions.tagSuggestions.length
            : 0.0;
        break;
      case 'priority':
        action = UserAction.rejectedPrioritySuggestion;
        value = suggestions.prioritySuggestion.priority.name;
        confidence = suggestions.prioritySuggestion.confidence;
        break;
      case 'time':
        action = UserAction.rejectedTimeSuggestion;
        value = suggestions.timeSuggestion.estimatedMinutes;
        confidence = suggestions.timeSuggestion.confidence;
        break;
      default:
        debugPrint('[AiSuggestionController] Unknown suggestion type: $suggestionType');
        return;
    }
    
    _recordUserAction(UserActionData(
      action: action,
      suggestionType: suggestionType,
      originalValue: value,
      finalValue: null,
      timestamp: DateTime.now(),
      suggestionConfidence: confidence,
      serviceUsed: suggestions.serviceUsed,
    ));
    
    debugPrint('[AiSuggestionController] User rejected $suggestionType suggestion');
  }
  
  /// Modify a suggestion and record user feedback
  void modifySuggestion(String suggestionType, dynamic newValue) {
    final suggestions = currentSuggestions.value;
    if (suggestions == null) return;
    
    UserAction action;
    dynamic originalValue;
    double confidence;
    
    switch (suggestionType.toLowerCase()) {
      case 'tag':
        action = UserAction.modifiedTagSuggestion;
        originalValue = suggestions.tagSuggestions.map((t) => t.name).join(', ');
        confidence = suggestions.tagSuggestions.isNotEmpty 
            ? suggestions.tagSuggestions.map((t) => t.confidence).reduce((a, b) => a + b) / suggestions.tagSuggestions.length
            : 0.0;
        break;
      case 'priority':
        action = UserAction.modifiedPrioritySuggestion;
        originalValue = suggestions.prioritySuggestion.priority.name;
        confidence = suggestions.prioritySuggestion.confidence;
        break;
      case 'time':
        action = UserAction.modifiedTimeSuggestion;
        originalValue = suggestions.timeSuggestion.estimatedMinutes;
        confidence = suggestions.timeSuggestion.confidence;
        break;
      default:
        debugPrint('[AiSuggestionController] Unknown suggestion type: $suggestionType');
        return;
    }
    
    _recordUserAction(UserActionData(
      action: action,
      suggestionType: suggestionType,
      originalValue: originalValue,
      finalValue: newValue,
      timestamp: DateTime.now(),
      suggestionConfidence: confidence,
      serviceUsed: suggestions.serviceUsed,
    ));
    
    debugPrint('[AiSuggestionController] User modified $suggestionType suggestion from $originalValue to $newValue');
  }
  
  /// Record user action for analytics and learning
  void recordUserAction(UserAction action) {
    _recordUserAction(UserActionData(
      action: action,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Clear current suggestions
  void clearSuggestions() {
    currentSuggestions.value = null;
    analysisError.value = null;
    lastAnalyzedTask.value = '';
    
    recordUserAction(UserAction.clearedSuggestions);
    debugPrint('[AiSuggestionController] Suggestions cleared');
  }
  
  /// Force manual analysis (bypass debouncing)
  Future<void> forceAnalysis(String title) async {
    recordUserAction(UserAction.triggeredManualAnalysis);
    await analyzeTask(
      title,
      forceAnalysis: true,
    );
  }
  
  /// Get suggestion acceptance rate for analytics
  double get acceptanceRate {
    if (userActions.isEmpty) return 0.0;
    
    final acceptedActions = userActions.where((action) => 
        action.action == UserAction.acceptedTagSuggestion ||
        action.action == UserAction.acceptedPrioritySuggestion ||
        action.action == UserAction.acceptedTimeSuggestion
    ).length;
    
    final totalSuggestionActions = userActions.where((action) => 
        action.action.name.contains('Suggestion')
    ).length;
    
    return totalSuggestionActions > 0 ? acceptedActions / totalSuggestionActions : 0.0;
  }
  
  /// Get performance summary for analytics
  Map<String, dynamic> get performanceSummary => {
    'analysisCount': analysisCount.value,
    'averageResponseTime': averageResponseTime.value,
    'successRate': successRate.value,
    'totalErrors': totalErrors.value,
    'acceptanceRate': acceptanceRate,
    'currentService': currentServiceName.value,
    'cacheSize': _cache.length,
    'userActionsCount': userActions.length,
  };
  
  /// Internal helper methods
  void _recordUserAction(UserActionData action) {
    userActions.add(action);
    
    // Keep only last 1000 actions
    if (userActions.length > 1000) {
      userActions.removeAt(0);
    }
    
    // Update acceptance rate
    suggestionAcceptanceRate.value = acceptanceRate;
  }
  
  void _recordSuccess(Duration responseTime) {
    _successfulRequests++;
    _responseTimesMs.add(responseTime.inMilliseconds);
    
    // Keep only last 100 response times
    if (_responseTimesMs.length > 100) {
      _responseTimesMs.removeAt(0);
    }
    
    // Update statistics
    analysisCount.value = _successfulRequests + _failedRequests;
    averageResponseTime.value = _responseTimesMs.isNotEmpty
        ? _responseTimesMs.reduce((a, b) => a + b) ~/ _responseTimesMs.length
        : 0;
    successRate.value = analysisCount.value > 0
        ? _successfulRequests / analysisCount.value
        : 0.0;
  }
  
  void _recordFailure() {
    _failedRequests++;
    totalErrors.value = _failedRequests;
    
    analysisCount.value = _successfulRequests + _failedRequests;
    successRate.value = analysisCount.value > 0
        ? _successfulRequests / analysisCount.value
        : 0.0;
  }
  
  /// Cache management
  TaskSuggestionResponse? _getFromCache(String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age < _cacheExpiry) {
        return cached;
      } else {
        _cache.remove(cacheKey);
      }
    }
    return null;
  }
  
  void _cacheResponse(String cacheKey, TaskSuggestionResponse response) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[cacheKey] = response;
  }
  
  /// Dispose all services
  Future<void> _disposeServices() async {
    for (final service in _services) {
      try {
        await service.dispose();
      } catch (e) {
        debugPrint('[AiSuggestionController] Error disposing ${service.serviceName}: $e');
      }
    }
  }
  
  /// Refresh service availability
  Future<void> refreshServices() async {
    debugPrint('[AiSuggestionController] Refreshing service availability...');
    await _selectBestService();
  }
}
