import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/task_models.dart';
import '../services/ollama_task_decomposition_service.dart';
import '../services/network_config_service.dart';

/// Ollama演示控制器
/// 
/// 提供简单的界面来测试和展示Ollama AI集成功能
class OllamaDemoController extends GetxController {
  // 服务实例
  late final OllamaTaskDecompositionService _ollamaService;
  late final NetworkConfigService _networkConfig;
  
  // 状态管理
  final isInitialized = false.obs;
  final isServiceAvailable = false.obs;
  final isLoading = false.obs;
  final currentModel = ''.obs;
  final healthStatus = ''.obs;
  
  // 演示数据
  final demoTaskTitle = '开发一个Flutter AI应用'.obs;
  final decompositionResults = <SubtaskSuggestion>[].obs;
  final errorMessage = ''.obs;
  final performanceStats = <String, dynamic>{}.obs;
  
  // 网络配置
  final customHost = ''.obs;
  final customPort = 11434.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }
  
  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      _networkConfig = NetworkConfigService();
      _ollamaService = OllamaTaskDecompositionService();
      
      await _ollamaService.initialize();
      await _updateStatus();
      
      isInitialized.value = true;
      debugPrint('Ollama demo controller initialized');
    } catch (e) {
      errorMessage.value = 'Failed to initialize: $e';
      debugPrint('Initialization error: $e');
    }
  }
  
  /// 更新状态信息
  Future<void> _updateStatus() async {
    try {
      // 获取健康状态
      final health = await _ollamaService.performHealthCheck();
      isServiceAvailable.value = health.isAvailable;
      healthStatus.value = health.toString();
      
      if (health.isAvailable && health.availableModels.isNotEmpty) {
        currentModel.value = health.availableModels.first;
      }
      
      // 获取性能统计
      performanceStats.value = _ollamaService.getPerformanceStats();
      
    } catch (e) {
      errorMessage.value = 'Status update failed: $e';
    }
  }
  
  /// 执行演示任务分解
  Future<void> performDemoDecomposition() async {
    if (isLoading.value) return;
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      decompositionResults.clear();
      
      // 创建演示任务
      final demoTask = _createDemoTask();
      
      // 执行分解
      final result = await _ollamaService.decomposeTask(
        demoTask,
        context: {
          'demo': true,
          'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      if (result.isSuccess) {
        decompositionResults.value = result.suggestions;
        debugPrint('Decomposition successful: ${result.suggestions.length} suggestions');
      } else {
        errorMessage.value = result.errorMessage ?? 'Unknown error';
      }
      
      // 更新统计信息
      await _updateStatus();
      
    } catch (e) {
      errorMessage.value = 'Decomposition failed: $e';
      debugPrint('Decomposition error: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 创建演示任务
  TaskModel _createDemoTask() {
    return TaskModel(
      id: 0,
      title: demoTaskTitle.value,
      status: TaskStatus.pending,
      priority: TaskPriority.importantNotUrgent,
      estimatedMinutes: 240, // 4小时
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: [
        TagModel(id: 1, name: 'Development', color: const Color(0xFF2196F3)),
        TagModel(id: 2, name: 'AI', color: const Color(0xFF4CAF50)),
        TagModel(id: 3, name: 'Flutter', color: const Color(0xFF03DAC6)),
      ],
    );
  }
  
  /// 手动刷新状态
  Future<void> refreshStatus() async {
    isLoading.value = true;
    await _updateStatus();
    isLoading.value = false;
  }
  
  /// 设置自定义服务器地址
  Future<void> setCustomServer(String host, int port) async {
    try {
      customHost.value = host;
      customPort.value = port;
      
      await _networkConfig.setCustomHost(host, port);
      
      // 重新初始化服务
      await _ollamaService.initialize();
      await _updateStatus();
      
      Get.snackbar('Success', 'Server configuration updated');
    } catch (e) {
      errorMessage.value = 'Failed to set custom server: $e';
      Get.snackbar('Error', 'Failed to update server configuration');
    }
  }
  
  /// 清除自定义配置
  Future<void> clearCustomServer() async {
    try {
      await _networkConfig.clearCustomHost();
      customHost.value = '';
      
      // 重新初始化服务
      await _ollamaService.initialize();
      await _updateStatus();
      
      Get.snackbar('Success', 'Using auto-detected configuration');
    } catch (e) {
      errorMessage.value = 'Failed to clear custom server: $e';
    }
  }
  
  /// 更新演示任务标题
  void updateDemoTaskTitle(String newTitle) {
    demoTaskTitle.value = newTitle;
  }
  
  /// 重置统计信息
  void resetStats() {
    _ollamaService.resetStats();
    performanceStats.value = _ollamaService.getPerformanceStats();
  }
  
  /// 获取格式化的性能信息
  String get formattedPerformanceStats {
    final stats = performanceStats;
    if (stats.isEmpty) return 'No statistics available';
    
    final buffer = StringBuffer();
    buffer.writeln('Performance Statistics:');
    buffer.writeln('Total Requests: ${stats['totalRequests'] ?? 0}');
    buffer.writeln('Success Rate: ${((stats['successRate'] ?? 0.0) * 100).toStringAsFixed(1)}%');
    buffer.writeln('Average Response Time: ${(stats['averageResponseTimeMs'] ?? 0.0).toStringAsFixed(0)}ms');
    buffer.writeln('Current Model: ${stats['currentModel'] ?? 'None'}');
    buffer.writeln('Service Available: ${stats['isAvailable'] ?? false}');
    
    return buffer.toString();
  }
  
  /// 获取建议摘要
  String get suggestionsSummary {
    if (decompositionResults.isEmpty) {
      return 'No suggestions available';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Generated ${decompositionResults.length} subtasks:');
    
    for (int i = 0; i < decompositionResults.length; i++) {
      final suggestion = decompositionResults[i];
      buffer.writeln('${i + 1}. ${suggestion.title}');
      buffer.writeln('   Duration: ${suggestion.estimatedDuration?.inMinutes ?? 0}min');
      buffer.writeln('   Tags: ${suggestion.suggestedTags.join(', ')}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  @override
  void onClose() {
    _ollamaService.dispose();
    super.onClose();
  }
} 