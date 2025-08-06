import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_reclaim/models/task_models.dart';
import 'package:life_reclaim/services/task_decomposition_service.dart';
import 'package:life_reclaim/services/manual_task_decomposition_service.dart';
import 'package:life_reclaim/services/ollama_task_decomposition_service.dart';

void main() {
  // 确保 Flutter 绑定在测试中正确初始化
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  group('Task Decomposition Service Tests', () {
    late ManualTaskDecompositionService manualService;

    setUp(() {
      manualService = ManualTaskDecompositionService();
    });

    test('Manual service should always be available', () {
      expect(manualService.isAvailable, isTrue);
      expect(manualService.supportedMode, TaskDecompositionMode.manual);
      expect(manualService.serviceName, isNotEmpty);
    });

    test('Should decompose learning task correctly', () async {
      final task = TaskModel(
        id: 1,
        title: '学习Flutter开发',
        status: TaskStatus.pending,
        priority: TaskPriority.importantNotUrgent,
        estimatedMinutes: 240,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await manualService.decomposeTask(task);

      expect(result.isSuccess, isTrue);
      expect(result.mode, TaskDecompositionMode.manual);
      expect(result.suggestions.length, greaterThan(0));
      expect(result.metadata['templateType'], 'learning');
      expect(result.metadata['estimatedComplexity'], isNotNull);
    });

    test('Should decompose project task correctly', () async {
      final task = TaskModel(
        id: 2,
        title: '开发移动应用项目',
        status: TaskStatus.pending,
        priority: TaskPriority.importantUrgent,
        estimatedMinutes: 480,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await manualService.decomposeTask(task);

      expect(result.isSuccess, isTrue);
      expect(result.suggestions.length, greaterThan(0));
      expect(result.metadata['templateType'], 'project');

      // 验证建议的结构
      for (final suggestion in result.suggestions) {
        expect(suggestion.title, isNotEmpty);
        expect(suggestion.isValid, isTrue);
        expect(suggestion.estimatedDuration, isNotNull);
      }
    });

    test('Should generate different templates for different task types', () async {
      final tasks = [
        ('学习Vue.js', 'learning'),
        ('开发应用', 'project'),
        ('研究AI趋势', 'research'),
        ('设计Logo', 'creative'),
        ('完成报告', 'generic'),
      ];

      for (final (title, expectedType) in tasks) {
        final task = TaskModel(
          id: 1,
          title: title,
          status: TaskStatus.pending,
          priority: TaskPriority.importantNotUrgent,
          estimatedMinutes: 120,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = await manualService.decomposeTask(task);
        expect(result.metadata['templateType'], expectedType,
            reason: 'Task "$title" should generate $expectedType template');
      }
    });

    test('Should validate result correctly', () {
      final validResult = TaskDecompositionResult(
        suggestions: const [
          SubtaskSuggestion(
            id: '1',
            title: 'Valid suggestion',
            estimatedDuration: Duration(hours: 1),
          ),
        ],
        mode: TaskDecompositionMode.manual,
        createdAt: DateTime.now(),
      );

      final invalidResult = TaskDecompositionResult(
        suggestions: const [
          SubtaskSuggestion(
            id: 'invalid',
            title: '  ', // 空白标题，应该无效
          ),
        ],
        mode: TaskDecompositionMode.manual,
        createdAt: DateTime.now(),
      );

      expect(manualService.validateResult(validResult), isTrue);
      expect(manualService.validateResult(invalidResult), isFalse);
    });

    test('Should get health status', () async {
      final healthStatus = await manualService.getHealthStatus();

      expect(healthStatus['serviceName'], manualService.serviceName);
      expect(healthStatus['isAvailable'], isTrue);
      expect(healthStatus['supportedMode'], 'manual');
      expect(healthStatus['templateTypes'], isA<List>());
      expect(healthStatus['capabilities'], isA<List>());
    });
  });

  group('Service Factory Tests', () {
    setUp(() {
      TaskDecompositionServiceFactory.clear();
    });

    test('Should register and retrieve services', () {
      final service = ManualTaskDecompositionService();
      TaskDecompositionServiceFactory.registerService(
        TaskDecompositionMode.manual,
        service,
      );

      final retrieved = TaskDecompositionServiceFactory.getService(
        TaskDecompositionMode.manual,
      );

      expect(retrieved, same(service));
    });

    test('Should find available service', () {
      final service = ManualTaskDecompositionService();
      TaskDecompositionServiceFactory.registerService(
        TaskDecompositionMode.manual,
        service,
      );

      final available = TaskDecompositionServiceFactory.getAvailableService();
      expect(available, isNotNull);
      expect(available!.isAvailable, isTrue);
    });

    test('Should return null for unavailable service', () {
      final service = TaskDecompositionServiceFactory.getService(
        TaskDecompositionMode.ai,
      );
      expect(service, isNull);
    });
  });

  group('SubtaskSuggestion Tests', () {
    test('Should create valid suggestion', () {
      const suggestion = SubtaskSuggestion(
        id: 'test-1',
        title: 'Test Task',
        description: 'Test description',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['test', 'example'],
        suggestedPriority: TaskPriority.importantNotUrgent,
      );

      expect(suggestion.isValid, isTrue);
      expect(suggestion.estimatedMinutes, 120);
      expect(suggestion.title, 'Test Task');
    });

    test('Should detect invalid suggestion', () {
      const suggestion = SubtaskSuggestion(
        id: 'test-2',
        title: '  ', // 空白标题
      );

      expect(suggestion.isValid, isFalse);
    });

    test('Should copy with modifications', () {
      const original = SubtaskSuggestion(
        id: 'test-3',
        title: 'Original',
        isAccepted: false,
      );

      final modified = original.copyWith(
        title: 'Modified',
        isAccepted: true,
        isModified: true,
      );

      expect(modified.title, 'Modified');
      expect(modified.isAccepted, isTrue);
      expect(modified.isModified, isTrue);
      expect(modified.id, original.id); // ID保持不变
    });
  });

  group('Ollama Task Decomposition Service Tests', () {
    late OllamaTaskDecompositionService ollamaService;

    setUp(() {
      ollamaService = OllamaTaskDecompositionService();
    });

    test('Ollama service should have correct configuration', () {
      expect(ollamaService.supportedMode, TaskDecompositionMode.ai);
      expect(ollamaService.serviceName, contains('Ollama'));
    });

    test('Should handle initialization gracefully when Ollama unavailable', () async {
      // 测试在Ollama服务不可用时的初始化行为
      try {
        await ollamaService.initialize();
        // 如果初始化成功，检查状态
        expect(ollamaService.serviceName, isNotEmpty);
      } catch (e) {
        // 如果初始化失败（Ollama不可用），应该优雅处理
        expect(ollamaService.isAvailable, isFalse);
      }
    });

    test('Should provide performance statistics', () {
      final stats = ollamaService.getPerformanceStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalRequests'), isTrue);
      expect(stats.containsKey('successfulRequests'), isTrue);
      expect(stats.containsKey('failedRequests'), isTrue);
      expect(stats.containsKey('successRate'), isTrue);
      expect(stats.containsKey('isAvailable'), isTrue);
    });

    test('Should handle decomposition when service unavailable', () async {
      final task = TaskModel(
        id: 1,
        title: '测试任务',
        status: TaskStatus.pending,
        priority: TaskPriority.importantNotUrgent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 如果Ollama不可用，应该提供降级方案
      final result = await ollamaService.decomposeTask(task);
      
      // 无论服务是否可用，都应该返回有效结果
      expect(result, isNotNull);
      expect(result.mode, TaskDecompositionMode.ai);
      
      if (!ollamaService.isAvailable) {
        // 降级情况下，应该有降级建议
        expect(result.suggestions.length, greaterThan(0));
        expect(result.confidence, lessThan(0.5)); // 降级结果置信度较低
      }
    });
  });
} 