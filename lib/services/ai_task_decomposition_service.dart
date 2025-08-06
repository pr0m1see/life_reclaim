import 'dart:math';
import '../models/task_models.dart';
import 'task_decomposition_service.dart';

/// Mock AI Task Decomposition Service
/// 
/// Simulates AI-powered task decomposition using Gemma3 model
class AITaskDecompositionService extends ObservableTaskDecompositionService {
  static const String _serviceName = 'Gemma3 AI Decomposition';
  
  @override
  String get serviceName => _serviceName;
  
  @override
  bool get isAvailable => true; // Mock as always available
  
  @override
  TaskDecompositionMode get supportedMode => TaskDecompositionMode.ai;
  
  @override
  Future<TaskDecompositionResult> decomposeTask(
    TaskModel task, {
    Map<String, dynamic> context = const {},
  }) async {
    try {
      notifyDecompositionStarted(task);
      
      // Simulate AI processing time
      await Future.delayed(const Duration(milliseconds: 2500));
      
      // Generate AI-powered suggestions
      final suggestions = _generateAISuggestions(task, context);
      
      final result = TaskDecompositionResult.aiSuccess(
        suggestions,
        confidence: 0.85 + Random().nextDouble() * 0.1, // Random confidence 85-95%
        metadata: {
          'model': 'Gemma3',
          'processingTime': 2500,
          'confidence': 'High',
          'approach': _getAIApproach(task),
          'complexity': _analyzeComplexity(task),
        },
      );
      
      notifyDecompositionCompleted(task, result);
      return result;
    } catch (e) {
      final errorMessage = 'AI decomposition failed: $e';
      notifyDecompositionFailed(task, errorMessage);
      return TaskDecompositionResult.error(errorMessage);
    }
  }
  
  /// Generate AI-powered suggestions
  List<SubtaskSuggestion> _generateAISuggestions(
    TaskModel task,
    Map<String, dynamic> context,
  ) {
    final suggestions = <SubtaskSuggestion>[];
    final taskType = _analyzeTaskType(task);
    
    switch (taskType) {
      case 'learning':
        suggestions.addAll(_generateLearningAI(task));
        break;
      case 'development':
        suggestions.addAll(_generateDevelopmentAI(task));
        break;
      case 'research':
        suggestions.addAll(_generateResearchAI(task));
        break;
      case 'creative':
        suggestions.addAll(_generateCreativeAI(task));
        break;
      case 'business':
        suggestions.addAll(_generateBusinessAI(task));
        break;
      default:
        suggestions.addAll(_generateGenericAI(task));
    }
    
    // Always return exactly 3 suggestions as specified
    return suggestions.take(3).toList();
  }
  
  /// Learning-related AI suggestions
  List<SubtaskSuggestion> _generateLearningAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Research fundamentals and gather resources',
        description: 'Collect comprehensive learning materials and establish knowledge foundation',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Research', 'Learning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Create structured learning plan',
        description: 'Design step-by-step curriculum with milestones and checkpoints',
        estimatedDuration: const Duration(minutes: 30),
        suggestedTags: ['Planning', 'Strategy'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Complete initial practical exercises',
        description: 'Apply learned concepts through hands-on practice and examples',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Practice', 'Hands-on'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Development-related AI suggestions
  List<SubtaskSuggestion> _generateDevelopmentAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Design system architecture',
        description: 'Create technical specifications and system design documents',
        estimatedDuration: const Duration(hours: 1, minutes: 30),
        suggestedTags: ['Design', 'Architecture'],
        suggestedPriority: TaskPriority.importantUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Implement core functionality',
        description: 'Build essential features and establish main workflow',
        estimatedDuration: const Duration(hours: 3),
        suggestedTags: ['Development', 'Implementation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Test and refine solution',
        description: 'Conduct thorough testing and optimize performance',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Testing', 'Quality'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Research-related AI suggestions
  List<SubtaskSuggestion> _generateResearchAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Conduct comprehensive literature review',
        description: 'Survey existing research and identify knowledge gaps',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Research', 'Analysis'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Develop research methodology',
        description: 'Design systematic approach and data collection strategy',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Methodology', 'Planning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Execute primary research phase',
        description: 'Collect and analyze data according to established methodology',
        estimatedDuration: const Duration(hours: 2, minutes: 30),
        suggestedTags: ['Data Collection', 'Analysis'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Creative-related AI suggestions
  List<SubtaskSuggestion> _generateCreativeAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Brainstorm and ideate concepts',
        description: 'Generate diverse creative ideas and explore possibilities',
        estimatedDuration: const Duration(minutes: 40),
        suggestedTags: ['Brainstorming', 'Creativity'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Create initial prototypes',
        description: 'Develop rough drafts and preliminary versions',
        estimatedDuration: const Duration(hours: 1, minutes: 30),
        suggestedTags: ['Prototyping', 'Design'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Refine and finalize output',
        description: 'Polish and perfect the creative work for completion',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Refinement', 'Completion'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Business-related AI suggestions
  List<SubtaskSuggestion> _generateBusinessAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Analyze market requirements',
        description: 'Research target audience and competitive landscape',
        estimatedDuration: const Duration(hours: 1),
        suggestedTags: ['Market Research', 'Analysis'],
        suggestedPriority: TaskPriority.importantUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Develop strategic plan',
        description: 'Create actionable roadmap with clear objectives',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Strategy', 'Planning'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Execute implementation phase',
        description: 'Deploy strategy and monitor initial results',
        estimatedDuration: const Duration(hours: 2),
        suggestedTags: ['Implementation', 'Execution'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Generic AI suggestions
  List<SubtaskSuggestion> _generateGenericAI(TaskModel task) {
    return [
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Plan and prepare approach',
        description: 'Define objectives and gather necessary resources',
        estimatedDuration: const Duration(minutes: 30),
        suggestedTags: ['Planning', 'Preparation'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 1,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Execute main workflow',
        description: 'Complete the primary tasks and core activities',
        estimatedDuration: const Duration(hours: 1, minutes: 30),
        suggestedTags: ['Execution', 'Focus'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 2,
      ),
      SubtaskSuggestion(
        id: _generateId(),
        title: 'Review and optimize results',
        description: 'Evaluate outcomes and make necessary improvements',
        estimatedDuration: const Duration(minutes: 45),
        suggestedTags: ['Review', 'Optimization'],
        suggestedPriority: TaskPriority.importantNotUrgent,
        order: 3,
      ),
    ];
  }
  
  /// Analyze task type from title and tags
  String _analyzeTaskType(TaskModel task) {
    final title = task.title.toLowerCase();
    final tags = task.tags.map((tag) => tag.name.toLowerCase()).join(' ');
    final combined = '$title $tags';
    
    if (combined.contains(RegExp(r'\b(learn|study|course|tutorial|education)\b'))) {
      return 'learning';
    }
    if (combined.contains(RegExp(r'\b(code|develop|build|program|app|software)\b'))) {
      return 'development';
    }
    if (combined.contains(RegExp(r'\b(research|analyze|investigate|study)\b'))) {
      return 'research';
    }
    if (combined.contains(RegExp(r'\b(design|create|write|art|creative)\b'))) {
      return 'creative';
    }
    if (combined.contains(RegExp(r'\b(business|market|strategy|plan|project)\b'))) {
      return 'business';
    }
    
    return 'generic';
  }
  
  /// Get AI analysis approach
  String _getAIApproach(TaskModel task) {
    final taskType = _analyzeTaskType(task);
    switch (taskType) {
      case 'learning':
        return 'Progressive Learning Framework';
      case 'development':
        return 'Agile Development Methodology';
      case 'research':
        return 'Systematic Research Process';
      case 'creative':
        return 'Design Thinking Approach';
      case 'business':
        return 'Strategic Planning Framework';
      default:
        return 'Goal-Oriented Task Breakdown';
    }
  }
  
  /// Analyze task complexity
  String _analyzeComplexity(TaskModel task) {
    final titleLength = task.title.length;
    final tagCount = task.tags.length;
    final estimatedTime = task.estimatedMinutes ?? 60;
    
    if (titleLength > 50 || tagCount > 3 || estimatedTime > 180) {
      return 'High';
    } else if (titleLength > 25 || tagCount > 1 || estimatedTime > 60) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }
  
  /// Generate unique ID
  String _generateId() {
    return 'ai_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }
} 