import 'dart:math';
import '../models/task_models.dart';
import 'task_decomposition_service.dart';

/// 手动任务拆分服务
/// 
/// 提供结构化的手动拆分指导和模板建议
/// 当AI服务不可用时作为降级方案
class ManualTaskDecompositionService extends ObservableTaskDecompositionService {
  static const String _serviceName = 'Manual Task Decomposition';
  
  @override
  String get serviceName => _serviceName;
  
  @override
  bool get isAvailable => true; // 手动模式总是可用
  
  @override
  TaskDecompositionMode get supportedMode => TaskDecompositionMode.manual;
  
  @override
  Future<TaskDecompositionResult> decomposeTask(
    TaskModel task, {
    Map<String, dynamic> context = const {},
  }) async {
    try {
      notifyDecompositionStarted(task);
      
      // 模拟短暂的处理时间，提供更好的用户体验
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 生成基础模板建议
      final suggestions = _generateTemplateSuggestions(task, context);
      
      final result = TaskDecompositionResult(
        suggestions: suggestions,
        mode: TaskDecompositionMode.manual,
        createdAt: DateTime.now(),
        metadata: {
          'templateType': _getTemplateType(task),
          'estimatedComplexity': _estimateComplexity(task),
          'suggestedApproach': _getSuggestedApproach(task),
          'bestPractices': _getBestPractices(task),
        },
      );
      
      notifyDecompositionCompleted(task, result);
      return result;
    } catch (e) {
      final errorMessage = 'Manual decomposition failed: $e';
      notifyDecompositionFailed(task, errorMessage);
      return TaskDecompositionResult.error(errorMessage);
    }
  }
  
  /// 生成模板建议
  List<SubtaskSuggestion> _generateTemplateSuggestions(
    TaskModel task,
    Map<String, dynamic> context,
  ) {
    final suggestions = <SubtaskSuggestion>[];
    final templateType = _getTemplateType(task);
    
    switch (templateType) {
      case 'learning':
        suggestions.addAll(_generateLearningTemplate(task));
        break;
      case 'project':
        suggestions.addAll(_generateProjectTemplate(task));
        break;
      case 'research':
        suggestions.addAll(_generateResearchTemplate(task));
        break;
      case 'creative':
        suggestions.addAll(_generateCreativeTemplate(task));
        break;
      default:
        suggestions.addAll(_generateGenericTemplate(task));
    }
    
    return suggestions;
  }
  
  /// 学习类任务模板
  List<SubtaskSuggestion> _generateLearningTemplate(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: '收集学习资料',
        description: '搜集相关的教程、文档、视频等学习资源',
        estimatedDuration: const Duration(minutes: 30),
        suggestedTags: ['Research', 'Preparation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '制定学习计划',
        description: '规划学习顺序和时间安排',
        estimatedDuration: const Duration(minutes: 20),
        suggestedTags: ['Planning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '开始基础学习',
        description: '学习核心概念和基础知识',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Learning', 'Focus'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 项目类任务模板
  List<SubtaskSuggestion> _generateProjectTemplate(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: '需求分析',
        description: '明确项目目标和具体需求',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Planning', 'Analysis'],
        suggestedPriority: TaskPriority.importantUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '设计方案',
        description: '制定实现方案和技术路线',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Design', 'Planning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '开始实施',
        description: '按计划开始项目实施',
        estimatedDuration: const Duration(hours: 4),
        suggestedTags: ['Implementation', 'Focus'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 研究类任务模板
  List<SubtaskSuggestion> _generateResearchTemplate(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: '定义研究范围',
        description: '明确研究的具体问题和边界',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Research', 'Planning'],
        suggestedPriority: TaskPriority.importantUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '文献调研',
        description: '查找和阅读相关资料',
        estimatedDuration: const Duration(hours: 3),
        suggestedTags: ['Research', 'Reading'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '整理分析',
        description: '整理收集的信息并进行分析',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Analysis', 'Documentation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 创意类任务模板
  List<SubtaskSuggestion> _generateCreativeTemplate(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: '灵感收集',
        description: '收集相关的创意和参考材料',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Creative', 'Inspiration'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '初步构思',
        description: '形成基本的创意方向和概念',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Creative', 'Brainstorming'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '创作实施',
        description: '开始具体的创作工作',
        estimatedDuration: const Duration(hours: 3),
        suggestedTags: ['Creative', 'Focus'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 通用任务模板
  List<SubtaskSuggestion> _generateGenericTemplate(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: '准备工作',
        description: '收集必要的资源和信息',
        estimatedDuration: const Duration(minutes: 30),
        suggestedTags: ['Preparation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '执行阶段1',
        description: '开始任务的第一个主要步骤',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Implementation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: '执行阶段2',
        description: '完成任务的后续步骤',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Implementation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// 确定任务模板类型
  String _getTemplateType(TaskModel task) {
    final titleLower = task.title.toLowerCase();
    
    // 学习相关关键词
    if (_containsAny(titleLower, ['学习', '教程', '了解', 'learn', 'study', 'tutorial'])) {
      return 'learning';
    }
    
    // 项目相关关键词
    if (_containsAny(titleLower, ['项目', '开发', '实现', 'project', 'develop', 'build', 'create'])) {
      return 'project';
    }
    
    // 研究相关关键词
    if (_containsAny(titleLower, ['研究', '调研', '分析', 'research', 'analyze', 'investigate'])) {
      return 'research';
    }
    
    // 创意相关关键词
    if (_containsAny(titleLower, ['设计', '创作', '写作', 'design', 'create', 'write', 'creative'])) {
      return 'creative';
    }
    
    return 'generic';
  }
  
  /// 估算任务复杂度
  String _estimateComplexity(TaskModel task) {
    final estimatedMinutes = task.estimatedMinutes ?? 60;
    
    if (estimatedMinutes <= 30) return '简单';
    if (estimatedMinutes <= 120) return '中等';
    if (estimatedMinutes <= 300) return '复杂';
    return '非常复杂';
  }
  
  /// 获取建议的分解方法
  String _getSuggestedApproach(TaskModel task) {
    final complexity = _estimateComplexity(task);
    
    switch (complexity) {
      case '简单':
        return '可以直接执行，建议分解为2-3个小步骤';
      case '中等':
        return '建议按时间或功能模块分解为3-5个子任务';
      case '复杂':
        return '建议按阶段分解，每个阶段1-2小时，总共4-6个子任务';
      case '非常复杂':
        return '建议按里程碑分解，先完成整体规划，再逐步细化';
      default:
        return '建议按逻辑顺序分解为可管理的小任务';
    }
  }
  
  /// 获取最佳实践建议
  List<String> _getBestPractices(TaskModel task) {
    return [
      '每个子任务应该在2小时内完成',
      '子任务之间保持逻辑顺序',
      '为每个子任务设定明确的完成标准',
      '预留一定的缓冲时间',
      '优先处理重要且紧急的子任务',
    ];
  }
  
  /// 检查字符串是否包含任意关键词
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
  
  /// 生成唯一ID
  String _generateId() {
    return 'manual_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }
  
  @override
  bool validateResult(TaskDecompositionResult result) {
    // 手动模式的验证：检查模式正确且建议有效
    if (result.mode != TaskDecompositionMode.manual) {
      return false;
    }
    
    // 允许空建议列表（作为起始模板）
    if (result.suggestions.isEmpty) {
      return true;
    }
    
    // 如果有建议，检查它们是否有效
    return result.suggestions.every((s) => s.isValid);
  }
  
  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    final baseStatus = await super.getHealthStatus();
    return {
      ...baseStatus,
      'templateTypes': ['learning', 'project', 'research', 'creative', 'generic'],
      'capabilities': [
        'Template generation',
        'Best practices guidance',
        'Complexity estimation',
        'Structured approach suggestion',
      ],
    };
  }
} 