import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:life_reclaim/services/ollama_service.dart';
import 'package:life_reclaim/services/network_config_service.dart';

/// AI测试控制器
/// 
/// 提供简单的AI功能验证，用于测试Ollama集成是否正常工作
class AiTestController extends GetxController {
  // 服务实例
  late final OllamaService _ollamaService;
  late final NetworkConfigService _networkConfig;
  
  // 状态管理
  final isLoading = false.obs;
  final isServiceAvailable = false.obs;
  final serverUrl = ''.obs;
  final currentModel = '未知'.obs;
  final responseTime = 0.obs;
  
  // 测试数据
  final testPrompt = 'Please explain what artificial intelligence is in one sentence.'.obs;
  final aiResponse = ''.obs;
  final errorMessage = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }
  
  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      _networkConfig = NetworkConfigService();
      _ollamaService = OllamaService(networkConfig: _networkConfig);
      
      await _ollamaService.initialize();
      await refreshStatus();
      
      debugPrint('AI test controller initialized');
    } catch (e) {
      errorMessage.value = 'Initialization failed: $e';
      debugPrint('AI test initialization error: $e');
    }
  }
  
  /// 刷新服务状态
  Future<void> refreshStatus() async {
    try {
      // 获取服务器URL
      serverUrl.value = await _networkConfig.getOllamaBaseUrl();
      
      // 执行健康检查
      final healthResult = await _ollamaService.healthCheck();
      isServiceAvailable.value = healthResult.isAvailable;
      
      if (healthResult.isAvailable) {
        // 获取可用模型
        final models = await _ollamaService.getAvailableModels();
        currentModel.value = models.isNotEmpty ? models.first : '无可用模型';
        errorMessage.value = '';
      } else {
        currentModel.value = '服务不可用';
        errorMessage.value = healthResult.error ?? 'Unknown error';
      }
      
      debugPrint('Status refreshed: ${healthResult.toString()}');
    } catch (e) {
      isServiceAvailable.value = false;
      errorMessage.value = 'Status check failed: $e';
      debugPrint('Status refresh error: $e');
    }
  }
  
  /// 执行AI测试
  Future<void> runAiTest() async {
    if (isLoading.value) return;
    
    try {
      isLoading.value = true;
      aiResponse.value = '';
      errorMessage.value = '';
      responseTime.value = 0;
      
      // 检查服务是否可用
      if (!isServiceAvailable.value) {
        await refreshStatus();
        if (!isServiceAvailable.value) {
          throw Exception('Ollama service is not available');
        }
      }
      
      // 记录开始时间
      final startTime = DateTime.now();
      
      // 使用简单的HTTP调用测试基础AI功能
      final response = await _testBasicCompletion();
      
      // 计算响应时间
      final endTime = DateTime.now();
      responseTime.value = endTime.difference(startTime).inMilliseconds;
      
      // 解析响应
      if (response.isNotEmpty) {
        aiResponse.value = response;
        debugPrint('AI test successful: ${response.length} characters');
      } else {
        throw Exception('Empty response from AI service');
      }
      
    } catch (e) {
      errorMessage.value = 'Test failed: $e';
      debugPrint('AI test error: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 执行基础的completion测试
  Future<String> _testBasicCompletion() async {
    try {
      // 获取可用模型
      final models = await _ollamaService.getAvailableModels();
      if (models.isEmpty) {
        throw Exception('No models available');
      }
      
      final modelName = models.first;
      debugPrint('Using model: $modelName for test');
      
      // 调用简单的completion方法
      final response = await _ollamaService.generateCompletion(
        prompt: testPrompt.value,
        modelName: modelName,
      );
      
      return response;
    } catch (e) {
      throw Exception('Completion test failed: $e');
    }
  }
  
  /// 更改测试提示词
  void updateTestPrompt(String newPrompt) {
    testPrompt.value = newPrompt;
  }
  
  /// 清除结果
  void clearResults() {
    aiResponse.value = '';
    errorMessage.value = '';
    responseTime.value = 0;
  }
  
  /// 获取状态摘要
  String get statusSummary {
    final buffer = StringBuffer();
    buffer.writeln('Service: ${isServiceAvailable.value ? "✅ Available" : "❌ Unavailable"}');
    buffer.writeln('URL: ${serverUrl.value}');
    buffer.writeln('Model: ${currentModel.value}');
    
    if (responseTime.value > 0) {
      buffer.writeln('Last Response: ${responseTime.value}ms');
    }
    
    if (errorMessage.value.isNotEmpty) {
      buffer.writeln('Error: ${errorMessage.value}');
    }
    
    return buffer.toString();
  }
  
  @override
  void onClose() {
    _ollamaService.dispose();
    super.onClose();
  }
}

 