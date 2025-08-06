import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task_models.dart';
import 'task_decomposition_service.dart';
import 'ollama_service.dart';
import 'network_config_service.dart';

/// 基于Ollama的AI任务分解服务
/// 
/// 集成Ollama本地大模型，提供智能任务分解功能，包括：
/// - 连接状态自动管理
/// - 模型自动选择和降级
/// - 错误处理和重试机制
/// - 智能缓存和优化
class OllamaTaskDecompositionService extends ObservableTaskDecompositionService {
  static const String _serviceName = 'Ollama AI Decomposition';
  
  final OllamaService _ollamaService;
  
  // 模型选择策略
  static const List<String> _preferredModels = [
    'llama3.2:1b',     // 首选：轻量快速
    'qwen2.5:0.5b',    // 备选：超轻量
    'phi4:3.8b',       // 备选：平衡性能
  ];
  
  String? _currentModel;
  bool _isAvailable = false;
  DateTime? _lastHealthCheck;
  
  // 性能指标
  int _successfulRequests = 0;
  int _failedRequests = 0;
  List<int> _responseTimesMs = [];
  
  OllamaTaskDecompositionService({
    OllamaService? ollamaService,
    NetworkConfigService? networkConfig,
  }) : _ollamaService = ollamaService ?? OllamaService(networkConfig: networkConfig);
  
  @override
  String get serviceName => _serviceName;
  
  @override
  bool get isAvailable => _isAvailable;
  
  @override
  TaskDecompositionMode get supportedMode => TaskDecompositionMode.ai;
  
  /// 初始化服务
  Future<void> initialize() async {
    try {
      await _ollamaService.initialize();
      await _checkServiceHealth();
      
      // 选择最佳模型
      await _selectOptimalModel();
      
      debugPrint('$serviceName initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize $serviceName: $e');
      _isAvailable = false;
    }
  }
  
  @override
  Future<TaskDecompositionResult> decomposeTask(
    TaskModel task, {
    Map<String, dynamic> context = const {},
  }) async {
    final startTime = DateTime.now();
    
    try {
      notifyDecompositionStarted(task);
      
      // 检查服务可用性
      if (!await _ensureServiceAvailable()) {
        throw const OllamaException('Ollama service is not available');
      }
      
      // 选择合适的模型
      final modelName = await _selectModelForTask(task);
      
      // 构建增强的上下文
      final enhancedContext = _buildEnhancedContext(task, context);
      
      // 执行任务分解
      final suggestions = await _ollamaService.decomposeTask(
        task,
        modelName,
        context: enhancedContext,
      );
      
      // 计算置信度
      final confidence = _calculateConfidence(task, suggestions);
      
      // 构建结果
      final result = TaskDecompositionResult.aiSuccess(
        suggestions,
        confidence: confidence,
        metadata: _buildResultMetadata(modelName, startTime),
      );
      
      _recordSuccess(startTime);
      notifyDecompositionCompleted(task, result);
      
      return result;
    } catch (e) {
      _recordFailure(startTime);
      final errorMessage = 'Ollama decomposition failed: $e';
      notifyDecompositionFailed(task, errorMessage);
      
      // 尝试降级处理
      return await _fallbackDecomposition(task, context, errorMessage);
    }
  }
  
  /// 确保服务可用
  Future<bool> _ensureServiceAvailable() async {
    // 检查是否需要重新检查健康状态
    final now = DateTime.now();
    if (_lastHealthCheck == null || 
        now.difference(_lastHealthCheck!).inMinutes > 5) {
      await _checkServiceHealth();
    }
    
    return _isAvailable;
  }
  
  /// 检查服务健康状态
  Future<void> _checkServiceHealth() async {
    try {
      final healthResult = await _ollamaService.healthCheck();
      _isAvailable = healthResult.isAvailable;
      _lastHealthCheck = DateTime.now();
      
      if (_isAvailable) {
        debugPrint('Ollama service is healthy: ${healthResult.availableModels.length} models available');
      } else {
        debugPrint('Ollama service is unhealthy: ${healthResult.error}');
      }
    } catch (e) {
      _isAvailable = false;
      _lastHealthCheck = DateTime.now();
      debugPrint('Health check failed: $e');
    }
  }
  
  /// 选择最优模型
  Future<void> _selectOptimalModel() async {
    try {
      final availableModels = await _ollamaService.getAvailableModels();
      
      // 按优先级选择模型
      for (final preferredModel in _preferredModels) {
        if (availableModels.contains(preferredModel)) {
          _currentModel = preferredModel;
          debugPrint('Selected model: $_currentModel');
          return;
        }
      }
      
      // 如果没有首选模型，使用第一个可用的
      if (availableModels.isNotEmpty) {
        _currentModel = availableModels.first;
        debugPrint('Using fallback model: $_currentModel');
      } else {
        _currentModel = null;
        debugPrint('No models available');
      }
    } catch (e) {
      debugPrint('Failed to select model: $e');
      _currentModel = null;
    }
  }
  
  /// 为任务选择合适的模型
  Future<String> _selectModelForTask(TaskModel task) async {
    if (_currentModel != null) {
      return _currentModel!;
    }
    
    // 重新尝试选择模型
    await _selectOptimalModel();
    
    if (_currentModel != null) {
      return _currentModel!;
    }
    
    // 使用默认模型
    return _preferredModels.first;
  }
  
  /// 构建增强的上下文信息
  Map<String, dynamic> _buildEnhancedContext(TaskModel task, Map<String, dynamic> originalContext) {
    final enhanced = Map<String, dynamic>.from(originalContext);
    
    // 添加任务分析信息
    enhanced['taskComplexity'] = _analyzeTaskComplexity(task);
    enhanced['estimatedDifficulty'] = _estimateTaskDifficulty(task);
    enhanced['suggestedApproach'] = _suggestApproach(task);
    
    // 添加用户历史信息（如果可用）
    if (_responseTimesMs.isNotEmpty) {
      enhanced['userPreference'] = {
        'averageResponseTime': _responseTimesMs.fold(0, (a, b) => a + b) / _responseTimesMs.length,
        'successRate': _successfulRequests / (_successfulRequests + _failedRequests),
      };
    }
    
    return enhanced;
  }
  
  /// 分析任务复杂度
  String _analyzeTaskComplexity(TaskModel task) {
    final titleLength = task.title.length;
    final tagCount = task.tags.length;
    final estimatedTime = task.estimatedMinutes ?? 60;
    
    if (titleLength > 50 || tagCount > 3 || estimatedTime > 180) {
      return 'high';
    } else if (titleLength > 25 || tagCount > 1 || estimatedTime > 60) {
      return 'medium';
    } else {
      return 'low';
    }
  }
  
  /// 估计任务难度
  String _estimateTaskDifficulty(TaskModel task) {
    final title = task.title.toLowerCase();
    
    // 检查复杂性关键词
    final complexKeywords = ['develop', 'create', 'build', 'design', 'research', 'analyze'];
    final simpleKeywords = ['review', 'read', 'update', 'check', 'organize'];
    
    if (complexKeywords.any((keyword) => title.contains(keyword))) {
      return 'complex';
    } else if (simpleKeywords.any((keyword) => title.contains(keyword))) {
      return 'simple';
    } else {
      return 'moderate';
    }
  }
  
  /// 建议处理方法
  String _suggestApproach(TaskModel task) {
    final title = task.title.toLowerCase();
    
    if (title.contains('urgent') || task.priority == TaskPriority.importantUrgent) {
      return 'rapid_breakdown';
    } else if (title.contains('project') || title.contains('plan')) {
      return 'strategic_planning';
    } else {
      return 'standard_breakdown';
    }
  }
  
  /// 计算置信度
  double _calculateConfidence(TaskModel task, List<SubtaskSuggestion> suggestions) {
    if (suggestions.isEmpty) return 0.0;
    
    double confidence = 0.7; // 基础置信度
    
    // 根据建议数量调整
    if (suggestions.length >= 3 && suggestions.length <= 5) {
      confidence += 0.1; // 合理的数量
    }
    
    // 根据任务复杂度调整
    final complexity = _analyzeTaskComplexity(task);
    switch (complexity) {
      case 'low':
        confidence += 0.1;
        break;
      case 'high':
        confidence -= 0.1;
        break;
    }
    
    // 根据历史成功率调整
    if (_successfulRequests > 0) {
      final successRate = _successfulRequests / (_successfulRequests + _failedRequests);
      confidence += (successRate - 0.5) * 0.2;
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// 构建结果元数据
  Map<String, dynamic> _buildResultMetadata(String modelName, DateTime startTime) {
    final processingTime = DateTime.now().difference(startTime).inMilliseconds;
    
    return {
      'provider': 'Ollama',
      'model': modelName,
      'processingTimeMs': processingTime,
      'serviceVersion': '1.0.0',
      'isLocal': true,
      'approach': 'LLM-powered decomposition',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// 降级处理
  Future<TaskDecompositionResult> _fallbackDecomposition(
    TaskModel task,
    Map<String, dynamic> context,
    String originalError,
  ) async {
    // 简单的基于规则的分解作为降级策略
    final fallbackSuggestions = _generateFallbackSuggestions(task);
    
    return TaskDecompositionResult.aiSuccess(
      fallbackSuggestions,
      confidence: 0.3, // 较低的置信度表示这是降级结果
      metadata: {
        'provider': 'Ollama (Fallback)',
        'originalError': originalError,
        'approach': 'Rule-based fallback',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// 生成降级建议
  List<SubtaskSuggestion> _generateFallbackSuggestions(TaskModel task) {
    final estimatedDuration = Duration(
      minutes: (task.estimatedMinutes ?? 120) ~/ 3,
    );
    
    return [
      SubtaskSuggestion(
        id: 'fallback_1_${DateTime.now().millisecondsSinceEpoch}',
        title: '准备和规划阶段',
        description: '收集所需资源，制定详细计划',
        estimatedDuration: estimatedDuration,
        suggestedTags: ['Planning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: 'fallback_2_${DateTime.now().millisecondsSinceEpoch}',
        title: '核心执行阶段',
        description: '完成主要工作内容',
        estimatedDuration: estimatedDuration,
        suggestedTags: ['Execution'],
        suggestedPriority: task.priority,
        order: 2,
      ),
      SubtaskSuggestion(
        id: 'fallback_3_${DateTime.now().millisecondsSinceEpoch}',
        title: '检查和完善阶段',
        description: '审查结果，进行必要的改进',
        estimatedDuration: estimatedDuration,
        suggestedTags: ['Review'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 记录成功
  void _recordSuccess(DateTime startTime) {
    _successfulRequests++;
    final responseTime = DateTime.now().difference(startTime).inMilliseconds;
    _responseTimesMs.add(responseTime);
    
    // 限制历史记录长度
    if (_responseTimesMs.length > 100) {
      _responseTimesMs.removeAt(0);
    }
  }
  
  /// 记录失败
  void _recordFailure(DateTime startTime) {
    _failedRequests++;
  }
  
  /// 获取性能统计
  Map<String, dynamic> getPerformanceStats() {
    final totalRequests = _successfulRequests + _failedRequests;
    
    return {
      'totalRequests': totalRequests,
      'successfulRequests': _successfulRequests,
      'failedRequests': _failedRequests,
      'successRate': totalRequests > 0 ? _successfulRequests / totalRequests : 0.0,
      'averageResponseTimeMs': _responseTimesMs.isNotEmpty 
          ? _responseTimesMs.fold(0, (a, b) => a + b) / _responseTimesMs.length 
          : 0.0,
      'currentModel': _currentModel,
      'isAvailable': _isAvailable,
      'lastHealthCheck': _lastHealthCheck?.toIso8601String(),
    };
  }
  
  /// 重置统计信息
  void resetStats() {
    _successfulRequests = 0;
    _failedRequests = 0;
    _responseTimesMs.clear();
  }
  
  /// 手动触发健康检查
  Future<HealthCheckResult> performHealthCheck() async {
    await _checkServiceHealth();
    return await _ollamaService.healthCheck();
  }
  
  /// 释放资源
  void dispose() {
    _ollamaService.dispose();
  }
} 