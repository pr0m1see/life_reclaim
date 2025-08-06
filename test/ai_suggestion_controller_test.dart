import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:life_reclaim/controllers/ai_suggestion_controller.dart';
import 'package:life_reclaim/controllers/task_controller.dart';
import 'package:life_reclaim/models/task_suggestion_models.dart';
import 'package:life_reclaim/models/task_models.dart';


void main() {
  group('AI Suggestion Controller - Phase 2 Tests', () {
    late AiSuggestionController controller;
    
    setUp(() async {
      // Reset GetX
      Get.reset();
      
      // Create controller
      controller = AiSuggestionController();
      Get.put(controller);
      
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));
    });
    
    tearDown(() {
      Get.reset();
    });
    
    test('Controller initialization and service selection', () async {
      expect(controller.isServiceAvailable.value, isTrue);
      expect(controller.currentServiceName.value, isNotEmpty);
      expect(controller.isAnalyzing.value, isFalse);
      expect(controller.currentSuggestions.value, isNull);
    });
    
    test('Real-time task analysis with debouncing', () async {
      const taskTitle = 'Send email to team about meeting';
      
      // Start analysis
      await controller.analyzeTask(taskTitle);
      
      expect(controller.lastAnalyzedTask.value, taskTitle);
      expect(controller.analysisError.value, isNull);
    });
    
    test('Suggestion acceptance tracking', () async {
      // Create mock suggestions
      final suggestions = TaskSuggestionResponse(
        tagSuggestions: [
          const SuggestedTag(
            name: 'Work',
            color: Colors.blue,
            confidence: 0.8,
            reasoning: 'Test tag',
          ),
        ],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantUrgent,
          confidence: 0.9,
          reasoning: 'Test priority',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 30,
          minEstimate: 20,
          maxEstimate: 45,
          confidence: 0.7,
          reasoning: 'Test time',
        ),
        confidence: 0.8,
        timestamp: DateTime.now(),
        serviceUsed: 'Test Service',
      );
      
      controller.currentSuggestions.value = suggestions;
      
      // Test acceptance
      controller.acceptSuggestion('tag');
      controller.acceptSuggestion('priority');
      controller.rejectSuggestion('time');
      
      expect(controller.userActions.length, 3);
      expect(controller.acceptanceRate, closeTo(0.67, 0.1));
    });
    
    test('Suggestion modification tracking', () async {
      final suggestions = TaskSuggestionResponse(
        tagSuggestions: [],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantNotUrgent,
          confidence: 0.8,
          reasoning: 'Test',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 60,
          minEstimate: 45,
          maxEstimate: 90,
          confidence: 0.7,
          reasoning: 'Test',
        ),
        confidence: 0.7,
        timestamp: DateTime.now(),
        serviceUsed: 'Test Service',
      );
      
      controller.currentSuggestions.value = suggestions;
      
      // Test modification
      controller.modifySuggestion('time', 45);
      controller.modifySuggestion('priority', TaskPriority.importantUrgent);
      
      expect(controller.userActions.length, 2);
      expect(controller.userActions.last.action, UserAction.modifiedPrioritySuggestion);
      expect(controller.userActions.last.finalValue, TaskPriority.importantUrgent);
    });
    
    test('Performance metrics tracking', () async {
      expect(controller.performanceSummary['analysisCount'], 0);
      expect(controller.performanceSummary['successRate'], 0.0);
      
      // Perform successful analysis
      await controller.analyzeTask('Test task');
      
      final summary = controller.performanceSummary;
      expect(summary['currentService'], isNotEmpty);
      expect(summary['acceptanceRate'], isA<double>());
    });
    
    test('Force analysis bypasses debouncing', () async {
      const taskTitle = 'Urgent task';
      
      final startTime = DateTime.now();
      await controller.forceAnalysis(taskTitle);
      final endTime = DateTime.now();
      
      // Should complete immediately without debounce delay
      expect(endTime.difference(startTime).inMilliseconds, lessThan(200));
      expect(controller.lastAnalyzedTask.value, taskTitle);
    });
    
    test('Caching mechanism works correctly', () async {
      const taskTitle = 'Cached task test';
      
      // First analysis
      await controller.analyzeTask(taskTitle);
      
      // Second analysis of same task should return early (same title)
      controller.currentSuggestions.value = null;
      await controller.analyzeTask(taskTitle);
      
      // Should return early for same task title
    });
    
    test('Clear suggestions functionality', () async {
      // Set up some suggestions
      controller.currentSuggestions.value = TaskSuggestionResponse(
        tagSuggestions: [],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantNotUrgent,
          confidence: 0.8,
          reasoning: 'Test',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 30,
          minEstimate: 20,
          maxEstimate: 45,
          confidence: 0.7,
          reasoning: 'Test',
        ),
        confidence: 0.7,
        timestamp: DateTime.now(),
        serviceUsed: 'Test',
      );
      
      controller.lastAnalyzedTask.value = 'Test task';
      
      // Clear suggestions
      controller.clearSuggestions();
      
      expect(controller.currentSuggestions.value, isNull);
      expect(controller.lastAnalyzedTask.value, isEmpty);
      expect(controller.analysisError.value, isNull);
    });
  });
  
  group('Task Controller Integration Tests', () {
    test('AI suggestion statistics tracking', () {
      final taskController = TaskController();
      
      // Initially no tasks created
      expect(taskController.totalTasksCreated.value, 0);
      expect(taskController.tasksCreatedWithAi.value, 0);
      expect(taskController.aiSuggestionsUsed.value, 0);
      
      final stats = taskController.aiSuggestionStats;
      expect(stats['totalTasksCreated'], 0);
      expect(stats['aiUsageRate'], 0.0);
    });
    
    test('AI suggestion modification recording', () {
      final taskController = TaskController();
      
      // Should not crash when AI controller is not available
      taskController.recordAiSuggestionModification('priority', 'old', 'new');
      
      // No exception should be thrown
      expect(true, isTrue);
    });
    
    test('AI suggestion refresh without crash', () async {
      final taskController = TaskController();
      
      // Should not crash when AI controller is not available
      await taskController.refreshAiSuggestions('Test task');
      taskController.clearAiSuggestions();
      
      // No exception should be thrown
      expect(true, isTrue);
    });
  });
  
  group('User Action Data Tests', () {
    test('User action data serialization', () {
      final actionData = UserActionData(
        action: UserAction.acceptedTagSuggestion,
        suggestionType: 'tag',
        originalValue: 'Work',
        finalValue: 'Work',
        timestamp: DateTime.now(),
        suggestionConfidence: 0.8,
        serviceUsed: 'Test Service',
      );
      
      final json = actionData.toJson();
      expect(json['action'], 'acceptedTagSuggestion');
      expect(json['suggestionType'], 'tag');
      expect(json['originalValue'], 'Work');
      expect(json['suggestionConfidence'], 0.8);
    });
    
    test('User action enumeration coverage', () {
      const actions = UserAction.values;
      
      // Ensure we have actions for all suggestion types
      expect(actions.contains(UserAction.acceptedTagSuggestion), isTrue);
      expect(actions.contains(UserAction.rejectedTagSuggestion), isTrue);
      expect(actions.contains(UserAction.modifiedTagSuggestion), isTrue);
      expect(actions.contains(UserAction.acceptedPrioritySuggestion), isTrue);
      expect(actions.contains(UserAction.rejectedPrioritySuggestion), isTrue);
      expect(actions.contains(UserAction.modifiedPrioritySuggestion), isTrue);
      expect(actions.contains(UserAction.acceptedTimeSuggestion), isTrue);
      expect(actions.contains(UserAction.rejectedTimeSuggestion), isTrue);
      expect(actions.contains(UserAction.modifiedTimeSuggestion), isTrue);
      expect(actions.contains(UserAction.triggeredManualAnalysis), isTrue);
      expect(actions.contains(UserAction.clearedSuggestions), isTrue);
    });
  });
  
  group('Error Handling Tests', () {
    test('Analysis with empty title', () async {
      final controller = AiSuggestionController();
      
      // Should not crash with empty title
      await controller.analyzeTask('');
      
      expect(controller.currentSuggestions.value, isNull);
      expect(controller.lastAnalyzedTask.value, isEmpty);
    });
    
    test('Suggestion operations with no current suggestions', () {
      final controller = AiSuggestionController();
      
      // Should not crash when no suggestions are available
      controller.acceptSuggestion('tag');
      controller.rejectSuggestion('priority');
      controller.modifySuggestion('time', 45);
      
      // No user actions should be recorded
      expect(controller.userActions.length, 0);
    });
    
    test('Invalid suggestion type handling', () {
      final controller = AiSuggestionController();
      
      // Set up mock suggestions
      controller.currentSuggestions.value = TaskSuggestionResponse(
        tagSuggestions: [],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantNotUrgent,
          confidence: 0.8,
          reasoning: 'Test',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 30,
          minEstimate: 20,
          maxEstimate: 45,
          confidence: 0.7,
          reasoning: 'Test',
        ),
        confidence: 0.7,
        timestamp: DateTime.now(),
        serviceUsed: 'Test',
      );
      
      // Try invalid suggestion type
      controller.acceptSuggestion('invalid_type');
      controller.rejectSuggestion('another_invalid_type');
      controller.modifySuggestion('yet_another_invalid_type', 'value');
      
      // Should not record any actions for invalid types
      expect(controller.userActions.length, 0);
    });
  });
} 