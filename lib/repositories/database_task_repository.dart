import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import '../models/task_models.dart';
import '../services/database/database.dart';

class DatabaseTaskRepository {
  final AppDatabase _database;

  DatabaseTaskRepository(this._database);

  // 将数据库Task转换为业务模型TaskModel
  TaskModel _taskToModel(Task task, {List<TaskModel>? subtasks, List<TagModel>? tags}) {
    return TaskModel(
      id: task.id,
      title: task.title,
      parentId: task.parentId,
      status: task.status,
      priority: task.priority,
      estimatedMinutes: task.estimatedMinutes,
      startedAt: task.startedAt,
      currentSessionStartedAt: task.currentSessionStartedAt,
      completedAt: task.completedAt,
      actualMinutes: task.actualMinutes,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      subtasks: subtasks ?? [],
      tags: tags ?? [],
    );
  }

  // 将数据库Tag转换为业务模型TagModel
  TagModel _tagToModel(Tag tag) {
    return TagModel(
      id: tag.id,
      name: tag.name,
      color: Color(tag.color),
      isSystem: tag.isSystem,
    );
  }

  // 获取所有根任务（包含子任务和标签）
  Future<List<TaskModel>> getAllRootTasks() async {
    final rootTasks = await _database.getAllRootTasks();
    
    List<TaskModel> result = [];
    for (final task in rootTasks) {
      // 获取子任务
      final subtasksData = await _database.getSubtasks(task.id);
      final subtasks = subtasksData.map((t) => _taskToModel(t)).toList();
      
      // 获取标签
      final tagsData = await _database.getTaskTags(task.id);
      final tags = tagsData.map((t) => _tagToModel(t)).toList();
      
      result.add(_taskToModel(task, subtasks: subtasks, tags: tags));
    }
    
    return result;
  }

  // 获取任务的子任务
  Future<List<TaskModel>> getSubtasks(int parentId) async {
    final tasks = await _database.getSubtasks(parentId);
    return tasks.map((task) => _taskToModel(task)).toList();
  }

  // 创建任务
  Future<int> createTask({
    required String title,
    int? parentId,
    required TaskStatus status,
    required TaskPriority priority,
    int? estimatedMinutes,
    List<int>? tagIds,
  }) async {
    return await _database.createTask(
      title: title,
      parentId: parentId,
      status: status,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      tagIds: tagIds,
    );
  }

  // 更新任务
  Future<bool> updateTask(int taskId, TaskModel updatedTask) async {
    try {
            // 1. 更新任务基本信息
             final taskUpdateResult = await _database.updateTask(
        taskId,
        TasksCompanion(
          title: Value(updatedTask.title),
          parentId: Value(updatedTask.parentId),
          status: Value(updatedTask.status),
          priority: Value(updatedTask.priority),
          estimatedMinutes: Value(updatedTask.estimatedMinutes),
          startedAt: Value(updatedTask.startedAt),
          currentSessionStartedAt: Value(updatedTask.currentSessionStartedAt),
          completedAt: Value(updatedTask.completedAt),
          actualMinutes: Value(updatedTask.actualMinutes),
        ),
      );

      // 2. 更新标签关联
      final tagIds = updatedTask.tags.map((tag) => tag.id).toList();
      final tagUpdateResult = await _database.updateTaskTags(taskId, tagIds);

      return taskUpdateResult && tagUpdateResult;
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      return false;
    }
  }

  // 开始任务计时
  Future<bool> startTask(int taskId) async {
    return await _database.startTask(taskId);
  }

  // 停止任务计时
  Future<bool> stopTask(int taskId) async {
    return await _database.stopTask(taskId);
  }

  // 完成任务
  Future<bool> completeTask(int taskId) async {
    return await _database.completeTask(taskId);
  }

  // 取消完成任务
  Future<bool> uncompleteTask(int taskId) async {
    return await _database.uncompleteTask(taskId);
  }

  // 删除任务
  Future<bool> deleteTask(int taskId) async {
    return await _database.deleteTask(taskId);
  }

  // 获取所有标签
  Future<List<TagModel>> getAllTags() async {
    final tags = await _database.getAllTags();
    return tags.map((tag) => _tagToModel(tag)).toList();
  }

  // 创建标签
  Future<int> createTag(String name, Color color) async {
    return await _database.createTag(name, color.value);
  }

  // 获取任务的标签
  Future<List<TagModel>> getTaskTags(int taskId) async {
    final tags = await _database.getTaskTags(taskId);
    return tags.map((tag) => _tagToModel(tag)).toList();
  }

  // 添加标签到任务
  Future<void> addTagToTask(int taskId, int tagId) async {
    await _database.addTagToTask(taskId, tagId);
  }

  // 从任务移除标签
  Future<void> removeTagFromTask(int taskId, int tagId) async {
    await _database.removeTagFromTask(taskId, tagId);
  }

  // 获取活跃任务
  Future<TaskModel?> getActiveTask() async {
    final task = await _database.getActiveTask();
    if (task == null) return null;
    
    // 获取标签
    final tags = await getTaskTags(task.id);
    return _taskToModel(task, tags: tags);
  }

  // 获取任务及其所有子任务（用于父子任务状态检查）
  Future<TaskModel?> getTaskWithSubtasks(int taskId) async {
    // 获取任务基本信息
    final task = await _database.getTaskById(taskId);
    if (task == null) return null;
    
    // 获取子任务
    final subtasksData = await _database.getSubtasks(taskId);
    final subtasks = subtasksData.map((t) => _taskToModel(t)).toList();
    
    // 获取标签
    final tagsData = await _database.getTaskTags(taskId);
    final tags = tagsData.map((t) => _tagToModel(t)).toList();
    
    return _taskToModel(task, subtasks: subtasks, tags: tags);
  }

  // 获取日期范围内的任务统计
  Future<Map<DateTime, int>> getTaskStats(DateTime startDate, DateTime endDate) async {
    // 这里需要实现数据库查询来获取统计数据
    // 暂时返回空数据，后续可以添加专门的查询方法
    return {};
  }

  // 获取标签统计
  Future<Map<String, int>> getTagStats() async {
    // 这里需要实现数据库查询来获取标签统计
    // 暂时返回空数据，后续可以添加专门的查询方法
    return {};
  }

  // Activity页面统计方法
  // 获取已完成任务总数
  Future<int> getCompletedTasksCount() async {
    return await _database.getCompletedTasksCount();
  }

  // 获取总专注时间（分钟）
  Future<int> getTotalFocusTime() async {
    return await _database.getTotalFocusTime();
  }

  // 获取最早任务创建日期
  Future<DateTime?> getFirstTaskDate() async {
    return await _database.getFirstTaskDate();
  }

  // 获取连续完成任务的天数
  Future<int> getCurrentStreak() async {
    return await _database.getCurrentStreak();
  }

  // 获取标签统计（带颜色信息）
  Future<List<Map<String, dynamic>>> getTagStatistics() async {
    return await _database.getTagStatistics();
  }

  // 获取活动强度数据（用于热力图）
  Future<Map<String, int>> getActivityIntensity(DateTime startDate, DateTime endDate) async {
    return await _database.getActivityIntensity(startDate, endDate);
  }

  // 获取每日任务完成数量
  Future<Map<String, int>> getDailyTaskCounts(DateTime startDate, DateTime endDate) async {
    return await _database.getDailyTaskCounts(startDate, endDate);
  }

  // 计算日均任务数
  Future<double> getDailyAverageTaskCount() async {
    final firstDate = await getFirstTaskDate();
    if (firstDate == null) return 0.0;
    
    final totalTasks = await getCompletedTasksCount();
    final daysSinceFirst = DateTime.now().difference(firstDate).inDays + 1;
    
    return totalTasks / daysSinceFirst;
  }
} 