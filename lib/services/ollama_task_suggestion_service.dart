import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/task_suggestion_models.dart';
import '../models/task_models.dart';
import 'task_suggestion_service.dart';
import 'ollama_service.dart';
import 'network_config_service.dart';

/// Ollama-based AI task suggestion service
/// 
/// Provides intelligent task analysis using local LLM models via Ollama.
/// Includes automatic model selection, fallback mechanisms, and performance optimization.
class OllamaTaskSuggestionService extends ObservableTaskSuggestionService {
  static const String _serviceName = 'Ollama AI Suggestions';
  static const int _servicePriority = 100; // High priority
  
  // Service dependencies
  final OllamaService _ollamaService;
  
  // Preferred models (lightweight to performance-oriented)
  static const List<String> _preferredModels = [
    'llama3.2:1b',     // Primary: Fast and lightweight
    'qwen2.5:0.5b',    // Fallback: Ultra-lightweight
    'phi4:3.8b',       // Performance: Better accuracy
  ];
  
  // Predefined tag categories and colors
  static final Map<String, Color> _systemTags = {
    'Work': Colors.blue,
    'Personal': Colors.green,
    'Learning': Colors.purple,
    'Social': Colors.pink,
    'Finance': Colors.teal,
    'Planning': Colors.indigo,
    'Meeting': Colors.amber,
    'Exercise': Colors.lightGreen,
    'Reading': Colors.deepPurple,
    'Writing': Colors.brown,
    'Shopping': Colors.lime,
  };
  
  // State management
  String? _currentModel;
  bool _isInitialized = false;
  bool _isAvailable = false;
  DateTime? _lastHealthCheck;
  
  // Performance tracking
  final List<int> _responseTimesMs = [];
  int _successfulRequests = 0;
  int _failedRequests = 0;
  
  // Caching
  final Map<String, TaskSuggestionResponse> _cache = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(hours: 2);
  
  // Streams for reactive updates
  final StreamController<bool> _availabilityController = StreamController<bool>.broadcast();
  final StreamController<TaskSuggestionResponse> _suggestionController = StreamController<TaskSuggestionResponse>.broadcast();
  final StreamController<TaskSuggestionException> _errorController = StreamController<TaskSuggestionException>.broadcast();
  
  OllamaTaskSuggestionService({
    OllamaService? ollamaService,
    NetworkConfigService? networkConfig,
  }) : _ollamaService = ollamaService ?? OllamaService(networkConfig: networkConfig);
  
  @override
  String get serviceName => _serviceName;
  
  @override
  bool get isAvailable => _isAvailable;
  
  @override
  int get priority => _servicePriority;
  
  @override
  Stream<bool> get availabilityStream => _availabilityController.stream;
  
  @override
  Stream<TaskSuggestionResponse> get suggestionStream => _suggestionController.stream;
  
  @override
  Stream<TaskSuggestionException> get errorStream => _errorController.stream;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('[$serviceName] Initializing...');
      
      await _ollamaService.initialize();
      await _checkServiceHealth();
      await _selectOptimalModel();
      
      _isInitialized = true;
      debugPrint('[$serviceName] Initialized successfully with model: $_currentModel');
    } catch (e) {
      debugPrint('[$serviceName] Initialization failed: $e');
      _isAvailable = false;
      _availabilityController.add(false);
    }
  }
  
  @override
  Future<TaskSuggestionResponse> suggestTaskAttributes(
    TaskSuggestionRequest request,
  ) async {
    final startTime = DateTime.now();
    
    try {
      notifySuggestionStarted(request);
      
      // Validate request
      if (!request.isValid) {
        throw const TaskSuggestionException(
          'Invalid request: task title is required',
          serviceUsed: _serviceName,
        );
      }
      
      // Check cache first
      final cached = _getFromCache(request.cacheKey);
      if (cached != null) {
        debugPrint('[$serviceName] Returning cached suggestion for: ${request.title}');
        return cached;
      }
      
      // Ensure service is available
      if (!await _ensureServiceAvailable()) {
        throw const TaskSuggestionException(
          'Ollama service is not available',
          serviceUsed: _serviceName,
        );
      }
      
      // Generate suggestions using AI
      final response = await _generateAISuggestions(request, startTime);
      
      // Cache the response
      _cacheResponse(request.cacheKey, response);
      
      // Track success
      _recordSuccess(startTime);
      notifySuggestionCompleted(request, response);
      
      return response;
    } catch (e) {
      _recordFailure(startTime);
      final error = TaskSuggestionException(
        'Failed to generate suggestions: $e',
        serviceUsed: serviceName,
        originalError: e,
      );
      notifySuggestionFailed(request, error);
      rethrow;
    }
  }
  
  @override
  Future<void> recordUserFeedback(
    TaskSuggestionRequest request,
    TaskSuggestionResponse response,
    UserFeedback feedback,
  ) async {
    try {
      // Store feedback for future learning
      debugPrint('[$serviceName] Recording feedback: ${feedback.type} for ${feedback.suggestionType}');
      
      // TODO: Implement feedback storage and learning
      // This could be used to improve future suggestions
      
    } catch (e) {
      debugPrint('[$serviceName] Failed to record feedback: $e');
    }
  }
  
  @override
  Future<ServiceHealthInfo> getHealthInfo() async {
    try {
      await _checkServiceHealth();
      
      final avgResponseTime = _responseTimesMs.isNotEmpty
          ? _responseTimesMs.reduce((a, b) => a + b) / _responseTimesMs.length
          : 0.0;
      
      final successRate = _successfulRequests + _failedRequests > 0
          ? _successfulRequests / (_successfulRequests + _failedRequests)
          : 0.0;
      
      return ServiceHealthInfo.healthy(
        status: 'Service operational with model: $_currentModel',
        details: {
          'model': _currentModel ?? 'None',
          'avgResponseTimeMs': avgResponseTime.round(),
          'successRate': (successRate * 100).round(),
          'cacheSize': _cache.length,
          'totalRequests': _successfulRequests + _failedRequests,
        },
      );
    } catch (e) {
      return ServiceHealthInfo.unhealthy(
        status: 'Service unavailable: $e',
        details: {'error': e.toString()},
      );
    }
  }
  
  @override
  Future<void> dispose() async {
    _availabilityController.close();
    _suggestionController.close();
    _errorController.close();
    _ollamaService.dispose();
  }
  
  /// Generate AI suggestions using Ollama
  Future<TaskSuggestionResponse> _generateAISuggestions(
    TaskSuggestionRequest request,
    DateTime startTime,
  ) async {
    final prompt = _buildPrompt(request);
    
    debugPrint('[$serviceName] Generating suggestions for: ${request.title}');
    
    try {
      final responseText = await _ollamaService.generateCompletion(
        prompt: prompt,
        modelName: _currentModel!,
      );
      
      final suggestions = _parseAIResponse(responseText, request);
      final processingTime = DateTime.now().difference(startTime);
      
      return TaskSuggestionResponse(
        tagSuggestions: suggestions['tags'] ?? [],
        prioritySuggestion: suggestions['priority']!,
        timeSuggestion: suggestions['timeEstimate']!,
        confidence: suggestions['confidence']!,
        metadata: {
          'model': _currentModel,
          'processingTimeMs': processingTime.inMilliseconds,
          'promptLength': prompt.length,
          'responseLength': responseText.length,
        },
        timestamp: DateTime.now(),
        serviceUsed: serviceName,
      );
    } catch (e) {
      debugPrint('[$serviceName] AI generation failed: $e');
      // Fallback to rule-based suggestions
      return _generateFallbackSuggestions(request, startTime);
    }
  }
  
  /// Build optimized prompt for task analysis
  String _buildPrompt(TaskSuggestionRequest request) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a productivity assistant that analyzes tasks and suggests optimal attributes.');
    buffer.writeln('');
    buffer.writeln('Task to analyze: "${request.title}"');
    buffer.writeln('');
    buffer.writeln('Please provide suggestions in JSON format:');
    buffer.writeln('{');
    buffer.writeln('  "tags": [');
    buffer.writeln('    {"name": "tag_name", "confidence": 0.85, "reasoning": "why this tag fits"}');
    buffer.writeln('  ],');
    buffer.writeln('  "priority": {');
    buffer.writeln('    "level": "importantNotUrgent", // options: importantUrgent, importantNotUrgent, urgentNotImportant');
    buffer.writeln('    "confidence": 0.90,');
    buffer.writeln('    "reasoning": "why this priority level"');
    buffer.writeln('  },');
    buffer.writeln('  "timeEstimate": {');
    buffer.writeln('    "minutes": 45,');
    buffer.writeln('    "minEstimate": 30,');
    buffer.writeln('    "maxEstimate": 60,');
    buffer.writeln('    "confidence": 0.75,');
    buffer.writeln('    "reasoning": "basis for time estimate"');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('Suggest 1-2 relevant tags from these categories: ${_systemTags.keys.join(', ')} or create new ones.');
    buffer.writeln('Time estimates should be between 15-480 minutes.');
    buffer.writeln('Use confidence scores between 0.1-1.0 based on how certain you are.');
    
    return buffer.toString();
  }
  
  /// Parse AI response and extract suggestions
  Map<String, dynamic> _parseAIResponse(String response, TaskSuggestionRequest request) {
    try {
      // Try to extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonStr);
        
        return {
          'tags': _parseTags(data['tags']),
          'priority': _parsePriority(data['priority']),
          'timeEstimate': _parseTimeEstimate(data['timeEstimate']),
          'confidence': _calculateOverallConfidence(data),
        };
      }
    } catch (e) {
      debugPrint('[$serviceName] JSON parsing failed: $e');
    }
    
    // Fallback to pattern matching
    return _parseResponseWithPatterns(response, request);
  }
  
  /// Parse tag suggestions from AI response
  List<SuggestedTag> _parseTags(dynamic tagsData) {
    final tags = <SuggestedTag>[];
    
    if (tagsData is List) {
      for (final tagData in tagsData) {
        if (tagData is Map<String, dynamic>) {
          final name = tagData['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            tags.add(SuggestedTag(
              name: name,
              color: _systemTags[name] ?? _generateColorForTag(name),
              confidence: (tagData['confidence'] ?? 0.7).toDouble(),
              reasoning: tagData['reasoning']?.toString() ?? 'AI suggested this tag',
              isExistingTag: _systemTags.containsKey(name),
            ));
          }
        }
      }
    }
    
    return tags.take(3).toList(); // Limit to 3 tags
  }
  
  /// Parse priority suggestion from AI response
  SuggestedPriority _parsePriority(dynamic priorityData) {
    if (priorityData is Map<String, dynamic>) {
      final levelStr = priorityData['level']?.toString() ?? 'importantNotUrgent';
      final priority = _parseTaskPriority(levelStr);
      
      return SuggestedPriority(
        priority: priority,
        confidence: (priorityData['confidence'] ?? 0.7).toDouble(),
        reasoning: priorityData['reasoning']?.toString() ?? 'AI suggested this priority',
      );
    }
    
    return const SuggestedPriority(
      priority: TaskPriority.importantNotUrgent,
      confidence: 0.5,
      reasoning: 'Default priority due to parsing error',
    );
  }
  
  /// Parse time estimate from AI response
  SuggestedTimeEstimate _parseTimeEstimate(dynamic timeData) {
    if (timeData is Map<String, dynamic>) {
      final minutes = (timeData['minutes'] ?? 30).toInt();
      final minEst = (timeData['minEstimate'] ?? (minutes * 0.7).round()).toInt();
      final maxEst = (timeData['maxEstimate'] ?? (minutes * 1.5).round()).toInt();
      
      return SuggestedTimeEstimate(
        estimatedMinutes: minutes.clamp(15, 480),
        minEstimate: minEst.clamp(5, minutes),
        maxEstimate: maxEst.clamp(minutes, 480),
        confidence: (timeData['confidence'] ?? 0.7).toDouble(),
        reasoning: timeData['reasoning']?.toString() ?? 'AI time estimation',
      );
    }
    
    return const SuggestedTimeEstimate(
      estimatedMinutes: 30,
      minEstimate: 20,
      maxEstimate: 45,
      confidence: 0.5,
      reasoning: 'Default estimate due to parsing error',
    );
  }
  
  /// Parse response using regex patterns when JSON parsing fails
  Map<String, dynamic> _parseResponseWithPatterns(String response, TaskSuggestionRequest request) {
    // Extract time estimates using patterns
    final timePattern = RegExp(r'(\d+)\s*(?:minutes?|mins?|m\b)', caseSensitive: false);
    final timeMatch = timePattern.firstMatch(response);
    final estimatedMinutes = timeMatch != null ? int.parse(timeMatch.group(1)!) : 30;
    
    // Extract priority keywords
    TaskPriority priority = TaskPriority.importantNotUrgent;
    if (response.toLowerCase().contains('urgent') && response.toLowerCase().contains('important')) {
      priority = TaskPriority.importantUrgent;
    } else if (response.toLowerCase().contains('urgent')) {
      priority = TaskPriority.urgentNotImportant;
    }
    
    // Extract potential tags by looking for keywords
    final tags = <SuggestedTag>[];
    for (final tagName in _systemTags.keys) {
      if (response.toLowerCase().contains(tagName.toLowerCase())) {
        tags.add(SuggestedTag(
          name: tagName,
          color: _systemTags[tagName]!,
          confidence: 0.6,
          reasoning: 'Extracted from AI response',
          isExistingTag: true,
        ));
      }
    }
    
    return {
      'tags': tags,
      'priority': SuggestedPriority(
        priority: priority,
        confidence: 0.6,
        reasoning: 'Extracted from AI response patterns',
      ),
      'timeEstimate': SuggestedTimeEstimate(
        estimatedMinutes: estimatedMinutes.clamp(15, 480),
        minEstimate: (estimatedMinutes * 0.7).round().clamp(5, estimatedMinutes),
        maxEstimate: (estimatedMinutes * 1.5).round().clamp(estimatedMinutes, 480),
        confidence: 0.6,
        reasoning: 'Extracted from AI response patterns',
      ),
      'confidence': 0.6,
    };
  }
  
  /// Generate fallback suggestions when AI fails
  TaskSuggestionResponse _generateFallbackSuggestions(
    TaskSuggestionRequest request,
    DateTime startTime,
  ) {
    final title = request.title.toLowerCase();
    final tags = <SuggestedTag>[];
    
    // Simple keyword-based tag suggestions
    for (final entry in _systemTags.entries) {
      if (title.contains(entry.key.toLowerCase())) {
        tags.add(SuggestedTag(
          name: entry.key,
          color: entry.value,
          confidence: 0.7,
          reasoning: 'Keyword match in task title',
          isExistingTag: true,
        ));
      }
    }
    
    // Length-based time estimation
    final words = title.split(' ').length;
    final estimatedMinutes = (words * 5 + 15).clamp(15, 120); // 5 min per word + base 15 min
    
    final processingTime = DateTime.now().difference(startTime);
    
    return TaskSuggestionResponse(
      tagSuggestions: tags,
      prioritySuggestion: const SuggestedPriority(
        priority: TaskPriority.importantNotUrgent,
        confidence: 0.5,
        reasoning: 'Default priority for fallback',
      ),
      timeSuggestion: SuggestedTimeEstimate(
        estimatedMinutes: estimatedMinutes,
        minEstimate: (estimatedMinutes * 0.7).round(),
        maxEstimate: (estimatedMinutes * 1.5).round(),
        confidence: 0.5,
        reasoning: 'Length-based estimation (fallback)',
      ),
      confidence: 0.5,
      metadata: {
        'fallback': true,
        'reason': 'AI parsing failed',
        'processingTimeMs': processingTime.inMilliseconds,
      },
      timestamp: DateTime.now(),
      serviceUsed: '$serviceName (Fallback)',
    );
  }
  
  /// Helper methods
  TaskPriority _parseTaskPriority(String priorityStr) {
    switch (priorityStr.toLowerCase()) {
      case 'importanturgent':
      case 'important_urgent':
        return TaskPriority.importantUrgent;
      case 'importantnoturgent':
      case 'important_not_urgent':
        return TaskPriority.importantNotUrgent;
      case 'urgentnotimportant':
      case 'urgent_not_important':
        return TaskPriority.urgentNotImportant;
      default:
        return TaskPriority.importantNotUrgent;
    }
  }
  
  Color _generateColorForTag(String tagName) {
    final hash = tagName.hashCode.abs();
    final colors = [
      Colors.blue, Colors.green, Colors.purple, Colors.orange,
      Colors.red, Colors.teal, Colors.pink, Colors.amber,
    ];
    return colors[hash % colors.length];
  }
  
  double _calculateOverallConfidence(Map<String, dynamic> data) {
    final confidences = <double>[];
    
    // Collect confidence scores
    if (data['tags'] is List) {
      for (final tag in data['tags']) {
        if (tag is Map && tag['confidence'] != null) {
          confidences.add(tag['confidence'].toDouble());
        }
      }
    }
    
    if (data['priority'] is Map && data['priority']['confidence'] != null) {
      confidences.add(data['priority']['confidence'].toDouble());
    }
    
    if (data['timeEstimate'] is Map && data['timeEstimate']['confidence'] != null) {
      confidences.add(data['timeEstimate']['confidence'].toDouble());
    }
    
    return confidences.isNotEmpty
        ? confidences.reduce((a, b) => a + b) / confidences.length
        : 0.7;
  }
  
  /// Service management methods
  Future<bool> _ensureServiceAvailable() async {
    final now = DateTime.now();
    if (_lastHealthCheck == null || now.difference(_lastHealthCheck!).inMinutes > 5) {
      await _checkServiceHealth();
    }
    return _isAvailable;
  }
  
  Future<void> _checkServiceHealth() async {
    try {
      final healthResult = await _ollamaService.healthCheck();
      _isAvailable = healthResult.isAvailable;
      _lastHealthCheck = DateTime.now();
      _availabilityController.add(_isAvailable);
      
      debugPrint('[$serviceName] Health check: ${_isAvailable ? "✅ Available" : "❌ Unavailable"}');
    } catch (e) {
      _isAvailable = false;
      _availabilityController.add(false);
      debugPrint('[$serviceName] Health check failed: $e');
    }
  }
  
  Future<void> _selectOptimalModel() async {
    try {
      final availableModels = await _ollamaService.getAvailableModels();
      
      for (final preferredModel in _preferredModels) {
        if (availableModels.contains(preferredModel)) {
          _currentModel = preferredModel;
          debugPrint('[$serviceName] Selected model: $preferredModel');
          return;
        }
      }
      
      // Use first available model if no preferred model found
      if (availableModels.isNotEmpty) {
        _currentModel = availableModels.first;
        debugPrint('[$serviceName] Using fallback model: ${_currentModel}');
      } else {
        throw Exception('No models available');
      }
    } catch (e) {
      debugPrint('[$serviceName] Model selection failed: $e');
      throw Exception('Failed to select AI model: $e');
    }
  }
  
  /// Performance tracking
  void _recordSuccess(DateTime startTime) {
    final responseTime = DateTime.now().difference(startTime).inMilliseconds;
    _responseTimesMs.add(responseTime);
    if (_responseTimesMs.length > 100) {
      _responseTimesMs.removeAt(0); // Keep only last 100 measurements
    }
    _successfulRequests++;
  }
  
  void _recordFailure(DateTime startTime) {
    _failedRequests++;
  }
  
  /// Caching methods
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
  
  /// Observable notifications
  @override
  void notifySuggestionStarted(TaskSuggestionRequest request) {
    debugPrint('[$serviceName] Starting suggestion for: ${request.title}');
  }
  
  @override
  void notifySuggestionCompleted(
    TaskSuggestionRequest request,
    TaskSuggestionResponse response,
  ) {
    debugPrint('[$serviceName] Completed suggestion for: ${request.title} (confidence: ${response.confidence})');
    _suggestionController.add(response);
  }
  
  @override
  void notifySuggestionFailed(
    TaskSuggestionRequest request,
    TaskSuggestionException error,
  ) {
    debugPrint('[$serviceName] Failed suggestion for: ${request.title} - ${error.message}');
    _errorController.add(error);
  }
} 