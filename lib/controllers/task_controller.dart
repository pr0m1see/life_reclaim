import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/task_models.dart';
import '../models/task_suggestion_models.dart';
import '../repositories/database_task_repository.dart';
import '../services/database_service.dart';
import 'ai_suggestion_controller.dart';

class TaskController extends GetxController {
  // 注入数据库仓储
  late final DatabaseTaskRepository _repository;
  
  // AI Suggestion Controller for intelligent task creation
  AiSuggestionController? _aiSuggestionController;
  
  // Observable states
  final RxList<TaskModel> tasks = <TaskModel>[].obs;
  final RxMap<int, bool> collapsedTasks = <int, bool>{}.obs;
  final Rxn<TaskModel> activeTask = Rxn<TaskModel>();
  final RxBool isLoading = false.obs;
  
  // AI Suggestion tracking
  final RxInt aiSuggestionsUsed = 0.obs;
  final RxDouble aiAcceptanceRate = 0.0.obs;
  final RxInt tasksCreatedWithAi = 0.obs;
  final RxInt totalTasksCreated = 0.obs;
  
  // 获取未完成的任务（Inbox页面使用）
  List<TaskModel> get pendingTasks => tasks.where((task) => !task.isCompleted).toList();
  
  @override
  void onInit() {
    super.onInit();
    // 初始化数据库仓储
    final databaseService = Get.find<DatabaseService>();
    _repository = DatabaseTaskRepository(databaseService.database);
    
    // 初始化AI建议控制器
    _initializeAiSuggestionController();
    
    loadTasks();
  }
  
  /// Initialize AI Suggestion Controller
  void _initializeAiSuggestionController() {
    try {
      _aiSuggestionController = Get.find<AiSuggestionController>();
      debugPrint('✨ AI Suggestion Controller connected to Task Controller');
    } catch (e) {
      debugPrint('❌ AI Suggestion Controller not found: $e');
      // This should not happen since it's registered in main.dart
    }
  }
  
  Future<void> loadTasks() async {
    isLoading.value = true;
    try {
      debugPrint('🔄 Loading tasks...');
      final loadedTasks = await _repository.getAllRootTasks();
      debugPrint('📋 Loaded ${loadedTasks.length} tasks');
      
      // 打印每个任务的详细信息用于调试
      for (final task in loadedTasks) {
        debugPrint('  Task: ${task.title} (ID: ${task.id})');
        debugPrint('    Status: ${task.status}, Priority: ${task.priority}');
        debugPrint('    startedAt: ${task.startedAt}, completedAt: ${task.completedAt}');
        debugPrint('    actualMinutes: ${task.actualMinutes}, estimatedMinutes: ${task.estimatedMinutes}');
        debugPrint('    Tags: ${task.tags.length}');
        for (final tag in task.tags) {
          debugPrint('      Tag: ${tag.name} (${tag.color})');
        }
      }
      
      tasks.value = loadedTasks;
      
      // 检查是否有活跃任务
      final active = await _repository.getActiveTask();
      activeTask.value = active;
      debugPrint('⚡ Active task: ${active?.title ?? 'None'}');
    } catch (e) {
      debugPrint('❌ Error loading tasks: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  void toggleSubtaskCollapse(int taskId) {
    collapsedTasks[taskId] = !(collapsedTasks[taskId] ?? false);
  }
  
  Future<void> activateTask(TaskModel task) async {
    try {
      // 如果有其他活跃任务，先停止它
      if (activeTask.value != null) {
        await _repository.stopTask(activeTask.value!.id);
      }
      
      // 激活新任务
      final success = await _repository.startTask(task.id);
      if (success) {
        final now = DateTime.now();
        activeTask.value = task.copyWith(
          status: TaskStatus.active,
          // 如果是第一次开始，设置 startedAt
          startedAt: task.startedAt ?? now,
          // 设置当前会话开始时间
          currentSessionStartedAt: now,
        );
        
        // 记录今日活动
        await _updateDailyActivity('activate');
        
        // 刷新任务列表
        await loadTasks();
      }
    } catch (e) {
      debugPrint('Error activating task: $e');
    }
  }
  
  Future<void> deactivateTask(TaskModel task) async {
    try {
      final success = await _repository.stopTask(task.id);
      if (success) {
        activeTask.value = null;
        await loadTasks();
      }
    } catch (e) {
      debugPrint('Error deactivating task: $e');
    }
  }
  
  Future<void> completeTask(TaskModel task) async {
    try {
      debugPrint('🎯 Completing task: ${task.title} (ID: ${task.id})');
      debugPrint('   Before completion - startedAt: ${task.startedAt}, completedAt: ${task.completedAt}');
      
      // 如果任务有子任务，不允许直接完成父任务
      if (task.hasSubtasks) {
        debugPrint('⚠️  Cannot complete parent task directly - has subtasks');
        return;
      }
      
      final success = await _repository.completeTask(task.id);
      debugPrint('   Database completion result: $success');
      
      if (success) {
        if (activeTask.value?.id == task.id) {
          activeTask.value = null;
        }
        
        // 记录今日活动
        await _updateDailyActivity('complete');
        
        // 如果是子任务，检查是否需要更新父任务状态
        if (task.parentId != null) {
          await _updateParentTaskStatus(task.parentId!);
        }
        
        await loadTasks();
        
        // 验证任务是否正确更新
        final updatedTask = tasks.firstWhere((t) => t.id == task.id);
        debugPrint('   After completion - startedAt: ${updatedTask.startedAt}, completedAt: ${updatedTask.completedAt}');
        debugPrint('   Task status: ${updatedTask.status}, actualMinutes: ${updatedTask.actualMinutes}');
      }
    } catch (e) {
      debugPrint('Error completing task: $e');
    }
  }
  
  Future<void> uncompleteTask(TaskModel task) async {
    try {
      // 如果任务有子任务，不允许直接取消完成父任务
      if (task.hasSubtasks) {
        debugPrint('⚠️  Cannot uncomplete parent task directly - has subtasks');
        return;
      }
      
      final success = await _repository.uncompleteTask(task.id);
      if (success) {
        // 如果是子任务，检查是否需要更新父任务状态
        if (task.parentId != null) {
          await _updateParentTaskStatus(task.parentId!);
        }
        
        await loadTasks();
      }
    } catch (e) {
      debugPrint('Error uncompleting task: $e');
    }
  }

  // 更新父任务状态的辅助方法
  Future<void> _updateParentTaskStatus(int parentId) async {
    try {
      debugPrint('🔄 Checking parent task status for parentId: $parentId');
      
      // 获取父任务及其所有子任务
      final parentTask = await _repository.getTaskWithSubtasks(parentId);
      if (parentTask == null) {
        debugPrint('⚠️  Parent task not found: $parentId');
        return;
      }
      
      debugPrint('👨‍👧‍👦 Parent task: ${parentTask.title}');
      debugPrint('   Subtasks: ${parentTask.subtasks.length}');
      debugPrint('   All completed: ${parentTask.allSubtasksCompleted}');
      debugPrint('   Current status: ${parentTask.status}');
      
      // 如果所有子任务都完成，且父任务未完成，则完成父任务
      if (parentTask.allSubtasksCompleted && !parentTask.isCompleted) {
        debugPrint('✅ All subtasks completed, completing parent task');
        await _repository.completeTask(parentId);
        
        // 如果父任务也有父任务，递归更新
        if (parentTask.parentId != null) {
          await _updateParentTaskStatus(parentTask.parentId!);
        }
      }
      // 如果有任何子任务未完成，且父任务已完成，则取消完成父任务
      else if (!parentTask.allSubtasksCompleted && parentTask.isCompleted) {
        debugPrint('❌ Not all subtasks completed, uncompleting parent task');
        await _repository.uncompleteTask(parentId);
        
        // 如果父任务也有父任务，递归更新
        if (parentTask.parentId != null) {
          await _updateParentTaskStatus(parentTask.parentId!);
        }
      }
    } catch (e) {
      debugPrint('Error updating parent task status: $e');
    }
  }
  
  Future<void> createTask(
    String title, {
    TaskPriority? priority,
    int? estimatedMinutes,
    List<TagModel>? tags,
    TaskSuggestionResponse? aiSuggestions,
    Map<String, bool>? suggestionUsage, // Which suggestions were used: {'tags': true, 'priority': false, 'time': true}
  }) async {
    try {
      debugPrint('➕ Creating task: $title');
      debugPrint('   Priority: ${priority ?? TaskPriority.importantNotUrgent}');
      
      // 如果没有设置预估时间，使用默认值30分钟
      final finalEstimatedMinutes = estimatedMinutes ?? 30;
      debugPrint('   Estimated: $finalEstimatedMinutes minutes');
      debugPrint('   Tags: ${tags?.map((tag) => tag.name).join(', ') ?? 'None'}');
      
      final tagIds = tags?.map((tag) => tag.id).toList();
      debugPrint('   Tag IDs: ${tagIds ?? 'None'}');
      
      await _repository.createTask(
        title: title,
        status: TaskStatus.pending,
        priority: priority ?? TaskPriority.importantNotUrgent,
        estimatedMinutes: finalEstimatedMinutes,
        tagIds: tagIds,
      );
      
      // Track AI suggestion usage if provided
      if (aiSuggestions != null && suggestionUsage != null) {
        await _trackAiSuggestionUsage(aiSuggestions, suggestionUsage);
      }
      
      // Update task creation statistics
      totalTasksCreated.value++;
      if (aiSuggestions != null) {
        tasksCreatedWithAi.value++;
      }
      
      debugPrint('✅ Task created successfully');
      await loadTasks();
    } catch (e) {
      debugPrint('❌ Error creating task: $e');
      rethrow; // Re-throw the error so the UI can handle it
    }
  }
  
  /// Create task with AI suggestions integration
  Future<void> createTaskWithAiSuggestions(
    String title, {
    String? description,
    TaskPriority? overridePriority,
    int? overrideEstimatedMinutes,
    List<TagModel>? overrideTags,
  }) async {
    try {
      if (_aiSuggestionController == null) {
        // Fallback to regular task creation
        await createTask(title, 
          priority: overridePriority,
          estimatedMinutes: overrideEstimatedMinutes,
          tags: overrideTags,
        );
        return;
      }
      
      debugPrint('🤖 Creating task with AI suggestions: $title');
      
      // Get AI suggestions
      await _aiSuggestionController!.analyzeTask(
        title,
        forceAnalysis: true,
      );
      
      // Wait for analysis to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      final suggestions = _aiSuggestionController!.currentSuggestions.value;
      if (suggestions == null) {
        debugPrint('⚠️ No AI suggestions available, using defaults');
        await createTask(title,
          priority: overridePriority,
          estimatedMinutes: overrideEstimatedMinutes,
          tags: overrideTags,
        );
        return;
      }
      
      // Use AI suggestions with manual overrides
      final finalPriority = overridePriority ?? suggestions.prioritySuggestion.priority;
      final finalEstimatedMinutes = overrideEstimatedMinutes ?? suggestions.timeSuggestion.estimatedMinutes;
      
      // Convert suggested tags to TagModel and merge with overrides
      final suggestedTags = _convertSuggestedTags(suggestions.tagSuggestions);
      final finalTags = overrideTags ?? suggestedTags;
      
      // Track which suggestions were used
      final suggestionUsage = {
        'tags': overrideTags == null && suggestedTags.isNotEmpty,
        'priority': overridePriority == null,
        'time': overrideEstimatedMinutes == null,
      };
      
      await createTask(
        title,
        priority: finalPriority,
        estimatedMinutes: finalEstimatedMinutes,
        tags: finalTags,
        aiSuggestions: suggestions,
        suggestionUsage: suggestionUsage,
      );
      
      debugPrint('🎯 Task created with AI suggestions - Usage: $suggestionUsage');
      
    } catch (e) {
      debugPrint('❌ Error creating task with AI suggestions: $e');
      // Fallback to regular creation
      await createTask(title,
        priority: overridePriority,
        estimatedMinutes: overrideEstimatedMinutes,
        tags: overrideTags,
      );
    }
  }
  
  Future<void> updateTask(TaskModel task) async {
    try {
      debugPrint('📝 Updating task: ${task.title}');
      debugPrint('   Priority: ${task.priority}');
      debugPrint('   Estimated: ${task.estimatedMinutes ?? 'None'} minutes');
      debugPrint('   Tags: ${task.tags.map((tag) => tag.name).join(', ')}');
      debugPrint('   Tag IDs: ${task.tags.map((tag) => tag.id).join(', ')}');
      
      final success = await _repository.updateTask(task.id, task);
      
      if (success) {
        debugPrint('✅ Task updated successfully');
        await loadTasks();
      } else {
        debugPrint('❌ Task update failed');
      }
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      rethrow;
    }
  }
  
  Future<void> deleteTask(TaskModel task) async {
    try {
      await _repository.deleteTask(task.id);
      await loadTasks();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  // 标签相关方法
  Future<List<TagModel>> getAllTags() async {
    try {
      return await _repository.getAllTags();
    } catch (e) {
      debugPrint('Error getting tags: $e');
      return [];
    }
  }

  Future<int> createTag(String name, Color color) async {
    try {
      debugPrint('🏷️ Creating tag: $name (${color.value})');
      final tagId = await _repository.createTag(name, color);
      debugPrint('✅ Tag created successfully with ID: $tagId');
      return tagId;
    } catch (e) {
      debugPrint('❌ Error creating tag: $e');
      rethrow;
    }
  }

  // 统计相关方法
  Future<Map<DateTime, int>> getTaskStats(DateTime startDate, DateTime endDate) async {
    try {
      return await _repository.getTaskStats(startDate, endDate);
    } catch (e) {
      debugPrint('Error getting task stats: $e');
      return {};
    }
  }

  Future<Map<String, int>> getTagStats() async {
    try {
      return await _repository.getTagStats();
    } catch (e) {
      debugPrint('Error getting tag stats: $e');
      return {};
    }
  }

  // 获取今日任务统计
  Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final stats = await _repository.getTaskStats(startOfDay, endOfDay);
      final todayCount = stats[startOfDay] ?? 0;
      
      // 计算今日总时间
      int totalMinutes = 0;
      for (final task in tasks) {
        if (task.completedAt != null &&
            task.completedAt!.isAfter(startOfDay) &&
            task.completedAt!.isBefore(endOfDay)) {
          totalMinutes += task.actualMinutes ?? 0;
        }
      }
      
      return {
        'completedTasks': todayCount,
        'totalMinutes': totalMinutes,
        'totalTasks': tasks.length,
      };
    } catch (e) {
      debugPrint('Error getting today stats: $e');
      return {
        'completedTasks': 0,
        'totalMinutes': 0,
        'totalTasks': 0,
      };
    }
  }

  // 获取特定日期的任务（Today页面使用）
  List<TaskModel> getTasksForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    debugPrint('📅 Getting tasks for date: ${date.year}-${date.month}-${date.day}');
    debugPrint('   Date range: $startOfDay to $endOfDay');
    
    final filteredTasks = tasks.where((task) {
      bool matchesStarted = false;
      bool matchesCompleted = false;
      
      // 检查是否是该日期激活过的任务
      if (task.startedAt != null && 
          task.startedAt!.isAfter(startOfDay) && 
          task.startedAt!.isBefore(endOfDay)) {
        matchesStarted = true;
      }
      
      // 检查是否是该日期完成的任务
      if (task.completedAt != null && 
          task.completedAt!.isAfter(startOfDay) && 
          task.completedAt!.isBefore(endOfDay)) {
        matchesCompleted = true;
      }
      
      if (matchesStarted || matchesCompleted) {
        debugPrint('   ✅ Task matches: ${task.title}');
        debugPrint('      startedAt: ${task.startedAt}, completedAt: ${task.completedAt}');
        debugPrint('      status: ${task.status}, actualMinutes: ${task.actualMinutes}');
        debugPrint('      todayTimeText: "${task.todayTimeText}"');
        return true;
      }
      
      return false;
    }).toList();
    
    debugPrint('   Found ${filteredTasks.length} tasks for today');
    return filteredTasks;
  }

  // Activity页面统计数据方法
  Future<Map<String, dynamic>> getActivityStats() async {
    try {
      final completedTasks = await _repository.getCompletedTasksCount();
      final totalTimeMinutes = await _repository.getTotalFocusTime();
      final streak = await _getCurrentStreakFromSharedPrefs(); // 使用新的SharedPreferences逻辑
      final dailyAverage = await _repository.getDailyAverageTaskCount();
      
      // 添加当前活跃任务的实时时间
      int finalTotalTime = totalTimeMinutes;
      if (activeTask.value != null && activeTask.value!.currentSessionStartedAt != null) {
        final currentSessionMinutes = DateTime.now().difference(activeTask.value!.currentSessionStartedAt!).inMinutes;
        finalTotalTime += currentSessionMinutes;
        debugPrint('📊 Adding current session time: ${currentSessionMinutes}m to total: ${finalTotalTime}m');
      }
      
      return {
        'completedTasks': completedTasks,
        'totalTimeMinutes': finalTotalTime,
        'totalTimeText': _formatMinutesToText(finalTotalTime),
        'streak': streak,
        'dailyAverage': dailyAverage,
        'dailyAverageText': dailyAverage.toStringAsFixed(1),
      };
    } catch (e) {
      debugPrint('Error getting activity stats: $e');
      return {
        'completedTasks': 0,
        'totalTimeMinutes': 0,
        'totalTimeText': '0h 0m',
        'streak': 0,
        'dailyAverage': 0.0,
        'dailyAverageText': '0.0',
      };
    }
  }

  // 获取标签统计数据
  Future<List<Map<String, dynamic>>> getTagStatistics() async {
    try {
      return await _repository.getTagStatistics();
    } catch (e) {
      debugPrint('Error getting tag statistics: $e');
      return [];
    }
  }

  // 获取热力图数据（使用SharedPreferences）
  Future<Map<String, int>> getHeatmapData(ActivityPeriod period) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endDate = DateTime.now();
      late DateTime startDate;
      late int daysInPeriod;
      
      switch (period) {
        case ActivityPeriod.oneMonth:
          daysInPeriod = 30;
          startDate = endDate.subtract(Duration(days: daysInPeriod));
          break;
        case ActivityPeriod.threeMonths:
          daysInPeriod = 90;
          startDate = endDate.subtract(Duration(days: daysInPeriod));
          break;
        case ActivityPeriod.sixMonths:
          daysInPeriod = 180;
          startDate = endDate.subtract(Duration(days: daysInPeriod));
          break;
        case ActivityPeriod.oneYear:
          daysInPeriod = 365;
          startDate = endDate.subtract(Duration(days: daysInPeriod));
          break;
      }
      
      final Map<String, int> heatmapData = {};
      
      // 遍历日期范围，从SharedPreferences读取每日数据
      for (int i = 0; i <= daysInPeriod; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final key = 'daily_activity_$dateStr';
        final count = prefs.getInt(key) ?? 0;
        if (count > 0) {
          heatmapData[dateStr] = count;
        }
      }
      
      debugPrint('📊 Heatmap data loaded: ${heatmapData.length} active days');
      return heatmapData;
    } catch (e) {
      debugPrint('Error getting heatmap data: $e');
      return {};
    }
  }

  // 获取成就数据
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final stats = await getActivityStats();
      final completedTasks = stats['completedTasks'] as int;
      final totalTimeMinutes = stats['totalTimeMinutes'] as int;
      final streak = stats['streak'] as int;
      
      return [
        {
          'icon': 'fire',
          'color': 'orange',
          'title': '7-Day Streak',
          'description': 'Completed tasks for 7 consecutive days',
          'achieved': streak >= 7,
          'progress': (streak / 7).clamp(0.0, 1.0),
        },
        {
          'icon': 'timer',
          'color': 'blue', 
          'title': 'Focus Master',
          'description': 'Focused for 50+ hours this month',
          'achieved': totalTimeMinutes >= (50 * 60), // 50 hours in minutes
          'progress': (totalTimeMinutes / (50 * 60)).clamp(0.0, 1.0),
        },
        {
          'icon': 'task',
          'color': 'green',
          'title': 'Task Crusher',
          'description': 'Completed 100+ tasks',
          'achieved': completedTasks >= 100,
          'progress': (completedTasks / 100).clamp(0.0, 1.0),
        },
      ];
    } catch (e) {
      debugPrint('Error getting achievements: $e');
      return [];
    }
  }

  // 格式化时间显示
  String _formatMinutesToText(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  // SharedPreferences活动追踪方法
  Future<void> _updateDailyActivity(String activityType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final key = 'daily_activity_$today';
      final currentCount = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, currentCount + 1);
      debugPrint('📈 Updated daily activity for $today: ${currentCount + 1} ($activityType)');
    } catch (e) {
      debugPrint('❌ Error updating daily activity: $e');
    }
  }

  // 基于SharedPreferences计算连续活跃天数
  Future<int> _getCurrentStreakFromSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int streak = 0;
      final today = DateTime.now();
      
      // 从今天开始往前逐天检查
      for (int i = 0; i < 365; i++) { // 最多检查365天
        final checkDate = today.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
        final key = 'daily_activity_$dateStr';
        final activityCount = prefs.getInt(key) ?? 0;
        
        if (activityCount > 0) {
          streak++;
          debugPrint('🔥 Day $dateStr has $activityCount activities, streak: $streak');
        } else {
          // 如果某天没有活动，停止计算streak
          debugPrint('🚫 Day $dateStr has no activity, stopping streak calculation at $streak');
          break;
        }
      }
      
      debugPrint('📊 Final streak: $streak days');
      return streak;
    } catch (e) {
      debugPrint('❌ Error calculating streak from SharedPrefs: $e');
      return 0;
    }
  }
  
  // ========== AI Suggestion Integration Methods ==========
  
  /// Track AI suggestion usage for analytics
  Future<void> _trackAiSuggestionUsage(
    TaskSuggestionResponse suggestions,
    Map<String, bool> suggestionUsage,
  ) async {
    try {
      if (_aiSuggestionController == null) return;
      
      // Record feedback for each suggestion type
      for (final entry in suggestionUsage.entries) {
        final suggestionType = entry.key;
        final wasUsed = entry.value;
        
        if (wasUsed) {
          _aiSuggestionController!.acceptSuggestion(suggestionType);
          aiSuggestionsUsed.value++;
        } else {
          _aiSuggestionController!.rejectSuggestion(suggestionType);
        }
      }
      
      // Update acceptance rate
      aiAcceptanceRate.value = _aiSuggestionController!.acceptanceRate;
      
      debugPrint('📊 AI Suggestion usage tracked: $suggestionUsage');
    } catch (e) {
      debugPrint('❌ Error tracking AI suggestion usage: $e');
    }
  }
  

  
  /// Convert suggested tags to TagModel instances
  List<TagModel> _convertSuggestedTags(List<SuggestedTag> suggestedTags) {
    try {
      final convertedTags = suggestedTags.map((suggestedTag) => suggestedTag.toTagModel()).toList();
      
      debugPrint('🏷️ Converted ${suggestedTags.length} suggested tags to ${convertedTags.length} TagModels');
      return convertedTags;
    } catch (e) {
      debugPrint('❌ Error converting suggested tags: $e');
      return [];
    }
  }
  
  /// Get AI suggestion controller for external access
  AiSuggestionController? get aiSuggestionController => _aiSuggestionController;
  
  /// Get AI suggestion statistics
  Map<String, dynamic> get aiSuggestionStats => {
    'totalTasksCreated': totalTasksCreated.value,
    'tasksCreatedWithAi': tasksCreatedWithAi.value,
    'aiUsageRate': totalTasksCreated.value > 0 
        ? tasksCreatedWithAi.value / totalTasksCreated.value 
        : 0.0,
    'aiSuggestionsUsed': aiSuggestionsUsed.value,
    'aiAcceptanceRate': aiAcceptanceRate.value,
    'isAiAvailable': _aiSuggestionController?.isServiceAvailable.value ?? false,
    'currentAiService': _aiSuggestionController?.currentServiceName.value ?? 'None',
  };
  
  /// Record user feedback when they modify AI suggestions
  void recordAiSuggestionModification(
    String suggestionType,
    dynamic originalValue,
    dynamic newValue,
  ) {
    _aiSuggestionController?.modifySuggestion(suggestionType, newValue);
    debugPrint('📝 Recorded AI suggestion modification: $suggestionType from $originalValue to $newValue');
  }
  
  /// Force refresh AI suggestions for current task analysis
  Future<void> refreshAiSuggestions(String title) async {
    if (_aiSuggestionController != null) {
      await _aiSuggestionController!.forceAnalysis(title);
    }
  }
  
  /// Clear current AI suggestions
  void clearAiSuggestions() {
    _aiSuggestionController?.clearSuggestions();
  }
} 