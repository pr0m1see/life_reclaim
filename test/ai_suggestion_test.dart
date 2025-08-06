import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_reclaim/models/task_suggestion_models.dart';
import 'package:life_reclaim/models/task_models.dart';
import 'package:life_reclaim/services/ollama_task_suggestion_service.dart';

void main() {
  group('AI Suggestion System - Phase 1 Tests', () {
    test('TaskSuggestionRequest validation', () {
      const request = TaskSuggestionRequest(
        title: 'Test task',
      );
      
      expect(request.isValid, true);
      expect(request.title, 'Test task');
      expect(request.cacheKey, isNotEmpty);
    });
    
    test('SuggestedTag creation and conversion', () {
      const suggestedTag = SuggestedTag(
        name: 'Work',
        color: Colors.blue,
        confidence: 0.8,
        reasoning: 'Test reasoning',
      );
      
      expect(suggestedTag.name, 'Work');
      expect(suggestedTag.confidence, 0.8);
      
      final tagModel = suggestedTag.toTagModel();
      expect(tagModel.name, 'Work');
      expect(tagModel.color, Colors.blue);
    });
    
    test('SuggestedPriority display names', () {
      const priorityUrgent = SuggestedPriority(
        priority: TaskPriority.importantUrgent,
        confidence: 0.9,
        reasoning: 'Test',
      );
      
      const priorityNotUrgent = SuggestedPriority(
        priority: TaskPriority.importantNotUrgent,
        confidence: 0.8,
        reasoning: 'Test',
      );
      
      const priorityUrgentNotImportant = SuggestedPriority(
        priority: TaskPriority.urgentNotImportant,
        confidence: 0.7,
        reasoning: 'Test',
      );
      
      expect(priorityUrgent.displayName, 'Important & Urgent');
      expect(priorityNotUrgent.displayName, 'Important & Not Urgent');
      expect(priorityUrgentNotImportant.displayName, 'Urgent & Not Important');
    });
    
    test('SuggestedTimeEstimate formatting', () {
      const estimate = SuggestedTimeEstimate(
        estimatedMinutes: 75,
        minEstimate: 60,
        maxEstimate: 90,
        confidence: 0.8,
        reasoning: 'Test estimate',
      );
      
      expect(estimate.displayTime, '1h 15m');
      expect(estimate.isReasonable, true);
      expect(estimate.rangeDisplay, '1h - 1h 30m');
    });
    
    test('TaskSuggestionResponse creation and quality', () {
      final response = TaskSuggestionResponse(
        tagSuggestions: [
          const SuggestedTag(
            name: 'Work',
            color: Colors.blue,
            confidence: 0.8,
            reasoning: 'Test',
          ),
        ],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantNotUrgent,
          confidence: 0.7,
          reasoning: 'Test',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 30,
          minEstimate: 20,
          maxEstimate: 45,
          confidence: 0.6,
          reasoning: 'Test',
        ),
        confidence: 0.7,
        timestamp: DateTime.now(),
        serviceUsed: 'Test Service',
      );
      
      expect(response.hasValidSuggestions, true);
      expect(response.qualityScore, greaterThan(0.5));
      expect(response.tagSuggestions.length, 1);
    });
    
    test('Ollama service basic functionality', () {
      final service = OllamaTaskSuggestionService();
      
      expect(service.serviceName, 'Ollama AI Suggestions');
      expect(service.priority, 100);
      
      // Note: Real functionality tests require actual Ollama service
      // These are basic structure tests
    });
    
    test('User feedback tracking', () {
      final feedback = UserFeedback(
        type: UserFeedbackType.accepted,
        suggestionType: 'tag',
        originalValue: 'Work',
        finalValue: 'Work',
        timestamp: DateTime.now(),
      );
      
      expect(feedback.type, UserFeedbackType.accepted);
      expect(feedback.suggestionType, 'tag');
      
      final json = feedback.toJson();
      expect(json['type'], 'accepted');
      
      final fromJson = UserFeedback.fromJson(json);
      expect(fromJson.type, UserFeedbackType.accepted);
    });
  });
  
  group('Service Integration Tests', () {
    test('Ollama service structure verification', () {
      final ollamaService = OllamaTaskSuggestionService();
      
      expect(ollamaService.priority, 100);
      expect(ollamaService.serviceName, 'Ollama AI Suggestions');
    });
    
    test('TaskSuggestionResponse serialization', () {
      final original = TaskSuggestionResponse(
        tagSuggestions: [
          const SuggestedTag(
            name: 'Work',
            color: Colors.blue,
            confidence: 0.8,
            reasoning: 'Test',
          ),
        ],
        prioritySuggestion: const SuggestedPriority(
          priority: TaskPriority.importantUrgent,
          confidence: 0.9,
          reasoning: 'Test priority',
        ),
        timeSuggestion: const SuggestedTimeEstimate(
          estimatedMinutes: 45,
          minEstimate: 30,
          maxEstimate: 60,
          confidence: 0.7,
          reasoning: 'Test time',
        ),
        confidence: 0.8,
        timestamp: DateTime.now(),
        serviceUsed: 'Test',
      );
      
      final json = original.toJson();
      final restored = TaskSuggestionResponse.fromJson(json);
      
      expect(restored.confidence, original.confidence);
      expect(restored.serviceUsed, original.serviceUsed);
      expect(restored.tagSuggestions.length, original.tagSuggestions.length);
      expect(restored.prioritySuggestion.priority, original.prioritySuggestion.priority);
    });
    
    test('TaskSuggestionException handling', () {
      const exception = TaskSuggestionException(
        'Test error',
        serviceUsed: 'Test Service',
      );
      
      expect(exception.message, 'Test error');
      expect(exception.serviceUsed, 'Test Service');
      expect(exception.toString(), contains('Test error'));
    });
  });
  
  group('Error Handling Tests', () {
    test('TaskSuggestionRequest with empty title', () {
      const request = TaskSuggestionRequest(title: '');
      
      expect(request.isValid, false);
      expect(request.title, isEmpty);
    });
    
    test('TaskSuggestionResponse empty factory', () {
      final emptyResponse = TaskSuggestionResponse.empty(
        serviceUsed: 'Test Service',
        reason: 'Test reason',
      );
      
      expect(emptyResponse.serviceUsed, 'Test Service');
      expect(emptyResponse.tagSuggestions, isEmpty);
      expect(emptyResponse.confidence, 0.1);
    });
    
    test('TaskSuggestionResponse error factory', () {
      final errorResponse = TaskSuggestionResponse.error(
        serviceUsed: 'Test Service',
        error: 'Test error',
      );
      
      expect(errorResponse.serviceUsed, 'Test Service');
      expect(errorResponse.metadata['error'], 'Test error');
      expect(errorResponse.confidence, 0.1);
    });
  });
} 