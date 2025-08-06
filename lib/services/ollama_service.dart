import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/task_models.dart';
import 'network_config_service.dart';

/// Ollama client service
/// 
/// Provides high-level interface for communicating with Ollama server, including:
/// - Task decomposition functionality
/// - Model management
/// - Error handling and retry mechanisms
/// - Response caching
class OllamaService {
  late final NetworkConfigService _networkConfig;
  late final http.Client _httpClient;
  
  // Cache configuration
  final Map<String, _CachedResponse> _responseCache = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _requestTimeout = Duration(minutes: 5); // Extended to 5 minutes for AI inference time
  
  bool _isInitialized = false;
  
  OllamaService({NetworkConfigService? networkConfig}) {
    _networkConfig = networkConfig ?? NetworkConfigService();
    _httpClient = http.Client();
  }
  
  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _networkConfig.initialize();
    _isInitialized = true;
  }
  
  /// Simple text generation (for testing)
  Future<String> generateCompletion({
    required String prompt,
    required String modelName,
  }) async {
    await initialize();
    
    try {
      final response = await _makeRequest(
        endpoint: '/api/generate',
        data: {
          'model': modelName,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
          },
        },
      );
      
      return response['response'] as String? ?? 'No response';
    } catch (e) {
      debugPrint('Generate completion failed: $e');
      rethrow;
    }
  }
  
  /// Release resources
  void dispose() {
    _httpClient.close();
  }
  
  /// Decompose task into subtasks
  Future<List<SubtaskSuggestion>> decomposeTask(
    TaskModel task,
    String modelName, {
    Map<String, dynamic> context = const {},
  }) async {
    await initialize();
    
    // Check cache
    final cacheKey = _generateCacheKey(task, modelName, context);
    final cached = _getFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    try {
      final prompt = _buildTaskDecompositionPrompt(task, context);
      
      final response = await _makeRequest(
        endpoint: '/api/generate',
        data: {
          'model': modelName,
          'prompt': prompt,
          'format': 'json',
          'stream': false,
          'options': {
            'temperature': 0.3, // Lower temperature for stable output
          },
        },
      );
      
      final suggestions = _parseDecompositionResponse(response, task);
      
      // Cache results
      _addToCache(cacheKey, suggestions);
      
      return suggestions;
    } catch (e) {
      debugPrint('Task decomposition failed: $e');
      rethrow;
    }
  }
  
  /// Generate task attributes (tags, priority, time estimation)
  Future<TaskAttributeSuggestion> generateTaskAttributes(
    String title,
    String? description, {
    Map<String, dynamic> context = const {},
  }) async {
    await initialize();
    
    try {
      final prompt = _buildAttributeGenerationPrompt(title, description, context);
      
      final response = await _makeRequest(
        endpoint: '/api/generate',
        data: {
          'model': context['modelName'] ?? 'llama3.2:1b',
          'prompt': prompt,
          'format': 'json',
          'stream': false,
          'options': {
            'temperature': 0.2,
            'num_predict': 512,
          },
        },
      );
      
      return _parseAttributeResponse(response);
    } catch (e) {
      debugPrint('Task attribute generation failed: $e');
      rethrow;
    }
  }
  
  /// Get available models list
  Future<List<String>> getAvailableModels() async {
    await initialize();
    
    try {
      final response = await _makeRequest(
        endpoint: '/api/tags',
        method: 'GET',
      );
      
      final models = (response['models'] as List?)
          ?.map((model) => model['name'] as String)
          .toList() ?? [];
      
      return models;
    } catch (e) {
      debugPrint('Failed to get available models: $e');
      return [];
    }
  }
  
  /// Check if model is available
  Future<bool> isModelAvailable(String modelName) async {
    final models = await getAvailableModels();
    return models.contains(modelName);
  }
  
  /// Perform health check
  Future<HealthCheckResult> healthCheck() async {
    await initialize();
    return await _networkConfig.performHealthCheck();
  }
  
  /// Build task decomposition prompt
  String _buildTaskDecompositionPrompt(TaskModel task, Map<String, dynamic> context) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a professional time management and task decomposition expert. Please break down complex tasks into 3-5 specific, actionable subtasks.');
    buffer.writeln();
    buffer.writeln('Decomposition principles:');
    buffer.writeln('1. Each subtask should be completable within 1-2 hours');
    buffer.writeln('2. Subtasks should have logical sequence and dependencies');
    buffer.writeln('3. Subtasks should be specific, measurable, and actionable');
    buffer.writeln('4. Consider actual workflow and dependency relationships');
    buffer.writeln();
    buffer.writeln('Task to decompose:');
    buffer.writeln('Title: ${task.title}');
    
    if (task.tags.isNotEmpty) {
      buffer.writeln('Existing tags: ${task.tags.map((t) => t.name).join(', ')}');
    }
    
    if (task.estimatedMinutes != null) {
      buffer.writeln('Original estimated time: ${task.estimatedMinutes} minutes');
    }
    
    if (task.priority != null) {
      buffer.writeln('Task priority: ${_getPriorityString(task.priority!)}');
    }
    
    // Add context information
    if (context.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Additional context:');
      if (context['taskComplexity'] != null) {
        buffer.writeln('Task complexity: ${context['taskComplexity']}');
      }
      if (context['estimatedDifficulty'] != null) {
        buffer.writeln('Estimated difficulty: ${context['estimatedDifficulty']}');
      }
      if (context['suggestedApproach'] != null) {
        buffer.writeln('Suggested approach: ${context['suggestedApproach']}');
      }
    }
    
    buffer.writeln();
    buffer.writeln('Please return subtask suggestions strictly in the following JSON format:');
    buffer.writeln('''{
  "subtasks": [
    {
      "title": "Specific subtask name",
      "description": "Detailed description of what this subtask involves and how to verify completion",
      "estimatedMinutes": 90,
      "suggestedTags": ["relevant tags"],
      "priority": "important_not_urgent",
      "order": 1
    }
  ]
}''');
    
    buffer.writeln();
    buffer.writeln('Available priorities: important_urgent, important_not_urgent, urgent_not_important');
    buffer.writeln('Common tags: Planning, Research, Development, Implementation, Testing, Review, Writing, Learning, Communication');
    
    return buffer.toString();
  }
  
  /// Get priority string description
  String _getPriorityString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return 'Important and Urgent';
      case TaskPriority.importantNotUrgent:
        return 'Important but Not Urgent';
      case TaskPriority.urgentNotImportant:
        return 'Urgent but Not Important';
    }
  }
  
  /// Build attribute generation prompt
  String _buildAttributeGenerationPrompt(
    String title,
    String? description,
    Map<String, dynamic> context,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a task attribute analysis expert. Please generate appropriate tags, priority, and time estimates for the following task.');
    buffer.writeln();
    buffer.writeln('Task title: $title');
    
    if (description?.isNotEmpty == true) {
      buffer.writeln('Task description: $description');
    }
    
    buffer.writeln();
    buffer.writeln('Please return the analysis results in JSON format:');
    buffer.writeln('''{
  "suggestedTags": ["relevant tag 1", "relevant tag 2"],
  "priority": "important_urgent",
  "estimatedMinutes": 90,
  "confidence": 0.85,
  "reasoning": "Analysis reasoning"
}''');
    
    buffer.writeln();
    buffer.writeln('Priority options: important_urgent, important_not_urgent, not_important_urgent, not_important_not_urgent');
    
    return buffer.toString();
  }
  
  /// Send HTTP request
  Future<Map<String, dynamic>> _makeRequest({
    required String endpoint,
    Map<String, dynamic>? data,
    String method = 'POST',
  }) async {
    final baseUrl = await _networkConfig.getOllamaBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        late http.Response response;
        
        if (method == 'POST') {
          response = await _httpClient.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: data != null ? jsonEncode(data) : null,
          ).timeout(_requestTimeout);
        } else {
          response = await _httpClient.get(
            url,
            headers: {'Content-Type': 'application/json'},
          ).timeout(_requestTimeout);
        }
        
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw OllamaException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          throw OllamaException('Request failed after $_maxRetries attempts: $e');
        }
        
        // Wait before retry
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }
    
    throw OllamaException('Unexpected error in _makeRequest');
  }
  
  /// Parse task decomposition response
  List<SubtaskSuggestion> _parseDecompositionResponse(
    Map<String, dynamic> response,
    TaskModel originalTask,
  ) {
    try {
      final responseText = response['response'] as String;
      final parsed = jsonDecode(responseText) as Map<String, dynamic>;
      final subtasks = parsed['subtasks'] as List;
      
      return subtasks.asMap().entries.map((entry) {
        final index = entry.key;
        final subtask = entry.value as Map<String, dynamic>;
        
        return SubtaskSuggestion(
          id: 'ollama_${DateTime.now().millisecondsSinceEpoch}_$index',
          title: subtask['title'] as String,
          description: subtask['description'] as String,
          estimatedDuration: Duration(minutes: subtask['estimatedMinutes'] as int),
          suggestedTags: (subtask['suggestedTags'] as List)
              .map((tag) => tag as String)
              .toList(),
          suggestedPriority: _parsePriority(subtask['priority'] as String),
          order: subtask['order'] as int? ?? index + 1,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to parse decomposition response: $e');
      // Return empty list or default suggestions
      return [];
    }
  }
  
  /// Parse attribute generation response
  TaskAttributeSuggestion _parseAttributeResponse(Map<String, dynamic> response) {
    try {
      final responseText = response['response'] as String;
      final parsed = jsonDecode(responseText) as Map<String, dynamic>;
      
      return TaskAttributeSuggestion(
        suggestedTags: (parsed['suggestedTags'] as List)
            .map((tag) => tag as String)
            .toList(),
        suggestedPriority: _parsePriority(parsed['priority'] as String),
        estimatedMinutes: parsed['estimatedMinutes'] as int,
        confidence: parsed['confidence'] as double? ?? 0.5,
        reasoning: parsed['reasoning'] as String?,
      );
    } catch (e) {
      debugPrint('Failed to parse attribute response: $e');
      // Return default suggestions
      return TaskAttributeSuggestion(
        suggestedTags: [],
        suggestedPriority: TaskPriority.importantNotUrgent,
        estimatedMinutes: 60,
        confidence: 0.0,
        reasoning: 'Failed to parse AI response',
      );
    }
  }
  
  /// Parse priority string
  TaskPriority _parsePriority(String priorityStr) {
    switch (priorityStr) {
      case 'important_urgent':
        return TaskPriority.importantUrgent;
      case 'important_not_urgent':
        return TaskPriority.importantNotUrgent;
      case 'urgent_not_important':
        return TaskPriority.urgentNotImportant;
      default:
        return TaskPriority.importantNotUrgent;
    }
  }
  
  /// Generate cache key
  String _generateCacheKey(TaskModel task, String modelName, Map<String, dynamic> context) {
    final keyData = {
      'title': task.title,
      'tags': task.tags.map((t) => t.name).toList()..sort(),
      'model': modelName,
      'context': context,
    };
    return keyData.hashCode.toString();
  }
  
  /// Get result from cache
  List<SubtaskSuggestion>? _getFromCache(String key) {
    final cached = _responseCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.suggestions;
    }
    return null;
  }
  
  /// 添加到缓存
  void _addToCache(String key, List<SubtaskSuggestion> suggestions) {
    // 限制缓存大小
    if (_responseCache.length >= _maxCacheSize) {
      final oldestKey = _responseCache.keys.first;
      _responseCache.remove(oldestKey);
    }
    
    _responseCache[key] = _CachedResponse(
      suggestions: suggestions,
      timestamp: DateTime.now(),
    );
  }
}

/// 任务属性建议
class TaskAttributeSuggestion {
  final List<String> suggestedTags;
  final TaskPriority suggestedPriority;
  final int estimatedMinutes;
  final double confidence;
  final String? reasoning;
  
  const TaskAttributeSuggestion({
    required this.suggestedTags,
    required this.suggestedPriority,
    required this.estimatedMinutes,
    required this.confidence,
    this.reasoning,
  });
}

/// 缓存的响应
class _CachedResponse {
  final List<SubtaskSuggestion> suggestions;
  final DateTime timestamp;
  
  const _CachedResponse({
    required this.suggestions,
    required this.timestamp,
  });
  
  bool get isExpired => DateTime.now().difference(timestamp) > OllamaService._cacheExpiry;
}

/// Ollama服务异常
class OllamaException implements Exception {
  final String message;
  final int? statusCode;
  
  const OllamaException(this.message, {this.statusCode});
  
  @override
  String toString() => 'OllamaException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
} 