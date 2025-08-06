import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

// 生成代码的占位符
part 'database.g.dart';

// 任务状态枚举
enum TaskStatus { pending, active, completed }

// 任务优先级枚举
enum TaskPriority { 
  importantUrgent, 
  importantNotUrgent, 
  urgentNotImportant 
}

// 1. 任务表
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
  IntColumn get status => intEnum<TaskStatus>()();
  IntColumn get priority => intEnum<TaskPriority>()();
  
  // 时间相关字段
  IntColumn get estimatedMinutes => integer().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()(); // 第一次开始工作时间
  DateTimeColumn get currentSessionStartedAt => dateTime().nullable()(); // 当前会话开始时间
  DateTimeColumn get completedAt => dateTime().nullable()(); // 完成时间
  IntColumn get actualMinutes => integer().nullable()(); // 实际工作时间（分钟）
  
  // 基础字段
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 2. 标签表
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()(); // Color.value
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))(); // 系统预设标签
}

// 3. 任务-标签关联表
class TaskTags extends Table {
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  
  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

@DriftDatabase(tables: [Tasks, Tags, TaskTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultTags();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // 在这里添加字段迁移逻辑
        // 暂时先用简单的ALTER TABLE语句
        await customStatement('ALTER TABLE tasks ADD COLUMN current_session_started_at INTEGER');
      }
    },
  );

  // 插入默认标签
  Future<void> _insertDefaultTags() async {
    await batch((batch) {
      batch.insertAll(tags, [
        TagsCompanion.insert(
          name: 'Work', 
          color: 0xFF2196F3, // Colors.blue.value
          isSystem: const Value(true),
          createdAt: DateTime.now(),
        ),
        TagsCompanion.insert(
          name: 'Personal', 
          color: 0xFF4CAF50, // Colors.green.value
          isSystem: const Value(true),
          createdAt: DateTime.now(),
        ),
        TagsCompanion.insert(
          name: 'Learning', 
          color: 0xFFFF9800, // Colors.orange.value
          isSystem: const Value(true),
          createdAt: DateTime.now(),
        ),
        TagsCompanion.insert(
          name: 'Health', 
          color: 0xFFF44336, // Colors.red.value
          isSystem: const Value(true),
          createdAt: DateTime.now(),
        ),
      ]);
    });
  }

  // 任务相关查询方法
  Future<List<Task>> getAllRootTasks() async {
    return await (select(tasks)
          ..where((t) => t.isDeleted.equals(false) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<Task>> getSubtasks(int parentId) async {
    return await (select(tasks)
          ..where((t) => t.parentId.equals(parentId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<Tag>> getTaskTags(int taskId) async {
    final query = select(tags).join([
      innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
    ])..where(taskTags.taskId.equals(taskId));
    
    return await query.map((row) => row.readTable(tags)).get();
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
    return await transaction(() async {
      final taskId = await into(tasks).insert(TasksCompanion(
        title: Value(title),
        parentId: Value(parentId),
        status: Value(status),
        priority: Value(priority),
        estimatedMinutes: Value(estimatedMinutes),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      // 添加标签关联
      if (tagIds != null && tagIds.isNotEmpty) {
        await batch((batch) {
          for (final tagId in tagIds) {
            batch.insert(
              taskTags,
              TaskTagsCompanion(
                taskId: Value(taskId),
                tagId: Value(tagId),
              ),
            );
          }
        });
      }

      return taskId;
    });
  }

  // 更新任务
  Future<bool> updateTask(int id, TasksCompanion taskData) async {
    final updatedRows = await (update(tasks)..where((t) => t.id.equals(id)))
        .write(taskData.copyWith(updatedAt: Value(DateTime.now())));
    return updatedRows > 0;
  }

  // 更新任务标签关联
  Future<bool> updateTaskTags(int taskId, List<int> tagIds) async {
    return await transaction(() async {
      print('🔄 Updating tags for task $taskId: $tagIds');
      
      // 1. 删除现有的标签关联
      final deletedRows = await (delete(taskTags)..where((tt) => tt.taskId.equals(taskId))).go();
      print('🗑️ Deleted $deletedRows existing tag associations for task $taskId');
      
      // 2. 添加新的标签关联
      if (tagIds.isNotEmpty) {
        await batch((batch) {
          for (final tagId in tagIds) {
            batch.insert(
              taskTags,
              TaskTagsCompanion(
                taskId: Value(taskId),
                tagId: Value(tagId),
              ),
            );
          }
        });
        print('✅ Added ${tagIds.length} new tag associations for task $taskId');
      } else {
        print('📭 No tags to add for task $taskId');
      }
      
      return true;
    });
  }

  // 开始任务计时
  Future<bool> startTask(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return false;

    final now = DateTime.now();
    return await updateTask(
      taskId,
      TasksCompanion(
        status: const Value(TaskStatus.active),
        // 如果是第一次开始，设置 startedAt
        startedAt: task.startedAt == null ? Value(now) : const Value.absent(),
        // 设置当前会话开始时间
        currentSessionStartedAt: Value(now),
      ),
    );
  }

  // 停止任务计时
  Future<bool> stopTask(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task?.currentSessionStartedAt == null) return false;

    // 计算当前会话的工作时间
    final sessionMinutes = DateTime.now().difference(task!.currentSessionStartedAt!).inMinutes;

    return await updateTask(
      taskId,
      TasksCompanion(
        status: const Value(TaskStatus.pending),
        // 累加到总工作时间
        actualMinutes: Value((task.actualMinutes ?? 0) + sessionMinutes),
        // 清除当前会话，但保留第一次开始时间
        currentSessionStartedAt: const Value(null),
        // 不清除 startedAt
      ),
    );
  }

  // 完成任务
  Future<bool> completeTask(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return false;

    int? actualMinutes = task.actualMinutes;
    
    // 如果正在进行当前会话，计算当前会话时间
    if (task.currentSessionStartedAt != null) {
      final sessionMinutes = DateTime.now().difference(task.currentSessionStartedAt!).inMinutes;
      actualMinutes = (actualMinutes ?? 0) + sessionMinutes;
    }

    return await updateTask(
      taskId,
      TasksCompanion(
        status: const Value(TaskStatus.completed),
        completedAt: Value(DateTime.now()),
        actualMinutes: Value(actualMinutes),
        // 清除当前会话，保留第一次开始时间
        currentSessionStartedAt: const Value(null),
      ),
    );
  }

  // 软删除任务
  Future<bool> deleteTask(int taskId) async {
    return await updateTask(
      taskId,
      const TasksCompanion(isDeleted: Value(true)),
    );
  }

  // 标签相关方法
  Future<List<Tag>> getAllTags() async {
    return await (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<int> createTag(String name, int color) async {
    return await into(tags).insert(TagsCompanion(
      name: Value(name),
      color: Value(color),
      createdAt: Value(DateTime.now()),
    ));
  }

  // 添加标签到任务
  Future<void> addTagToTask(int taskId, int tagId) async {
    await into(taskTags).insert(
      TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  // 从任务移除标签
  Future<void> removeTagFromTask(int taskId, int tagId) async {
    await (delete(taskTags)
          ..where((tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId)))
        .go();
  }

  // 获取活跃任务
  Future<Task?> getActiveTask() async {
    return await (select(tasks)..where((t) => t.status.equalsValue(TaskStatus.active))).getSingleOrNull();
  }

  // 根据ID获取任务
  Future<Task?> getTaskById(int taskId) async {
    return await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
  }

  // 取消完成任务
  Future<bool> uncompleteTask(int taskId) async {
    return await updateTask(
      taskId,
      const TasksCompanion(
        status: Value(TaskStatus.pending),
        completedAt: Value(null),
        actualMinutes: Value(null),
      ),
    );
  }

  // Activity页面统计方法
  // 获取时间段内每日完成的任务数
  Future<Map<String, int>> getDailyTaskCounts(DateTime startDate, DateTime endDate) async {
    final query = customSelect('''
      SELECT DATE(completed_at) as date, COUNT(*) as count
      FROM tasks 
      WHERE completed_at >= ? AND completed_at < ? AND status = ? AND is_deleted = 0
      GROUP BY DATE(completed_at)
      ORDER BY date
    ''', variables: [
      Variable.withDateTime(startDate),
      Variable.withDateTime(endDate),
      Variable.withInt(TaskStatus.completed.index),
    ]);

    final results = await query.get();
    final Map<String, int> dailyCounts = {};
    
    for (final row in results) {
      final date = row.read<String>('date');
      final count = row.read<int>('count');
      dailyCounts[date] = count;
    }
    
    return dailyCounts;
  }

  // 获取已完成任务的总数
  Future<int> getCompletedTasksCount() async {
    final query = customSelect('''
      SELECT COUNT(*) as count
      FROM tasks 
      WHERE status = ? AND is_deleted = 0
    ''', variables: [
      Variable.withInt(TaskStatus.completed.index),
    ]);

    final result = await query.getSingle();
    return result.read<int>('count');
  }

  // 获取总专注时间（分钟）- 修复：统计所有有工作时间的任务
  Future<int> getTotalFocusTime() async {
    final query = customSelect('''
      SELECT SUM(COALESCE(actual_minutes, 0)) as total
      FROM tasks 
      WHERE actual_minutes > 0 AND is_deleted = 0
    ''');

    final result = await query.getSingle();
    return result.read<int?>('total') ?? 0;
  }

  // 获取最早任务创建日期
  Future<DateTime?> getFirstTaskDate() async {
    final query = customSelect('''
      SELECT MIN(created_at) as first_date
      FROM tasks 
      WHERE is_deleted = 0
    ''');

    final result = await query.getSingle();
    return result.read<DateTime?>('first_date');
  }

  // 获取连续完成任务的天数
  Future<int> getCurrentStreak() async {
    final today = DateTime.now();
    final query = customSelect('''
      SELECT DISTINCT DATE(completed_at) as date
      FROM tasks 
      WHERE status = ? AND is_deleted = 0 AND completed_at IS NOT NULL
      ORDER BY date DESC
    ''', variables: [
      Variable.withInt(TaskStatus.completed.index),
    ]);

    final results = await query.get();
    if (results.isEmpty) return 0;

    int streak = 0;
    DateTime currentDate = DateTime(today.year, today.month, today.day);
    
    for (final row in results) {
      final dateStr = row.readNullable<String>('date');
      if (dateStr == null) continue;
      final taskDate = DateTime.parse(dateStr);
      final daysDiff = currentDate.difference(taskDate).inDays;
      
      if (daysDiff == streak) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else if (daysDiff == streak + 1 && streak == 0) {
        // 允许昨天的任务算作连续
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  // 获取标签统计
  Future<List<Map<String, dynamic>>> getTagStatistics() async {
    final query = customSelect('''
      SELECT t.name, t.color, COUNT(tt.task_id) as task_count
      FROM tags t
      LEFT JOIN task_tags tt ON t.id = tt.tag_id
      LEFT JOIN tasks ta ON tt.task_id = ta.id AND ta.is_deleted = 0
      GROUP BY t.id, t.name, t.color
      HAVING task_count > 0
      ORDER BY task_count DESC
    ''');

    final results = await query.get();
    return results.map((row) => {
      'name': row.readNullable<String>('name') ?? 'Unknown',
      'color': row.read<int>('color'),
      'count': row.read<int>('task_count'),
    }).toList();
  }

  // 获取时间段内的任务活动强度（用于热力图）
  Future<Map<String, int>> getActivityIntensity(DateTime startDate, DateTime endDate) async {
    final query = customSelect('''
      SELECT DATE(completed_at) as date, COUNT(*) as count
      FROM tasks 
      WHERE completed_at >= ? AND completed_at < ? AND status = ? AND is_deleted = 0
      GROUP BY DATE(completed_at)
    ''', variables: [
      Variable.withDateTime(startDate),
      Variable.withDateTime(endDate),
      Variable.withInt(TaskStatus.completed.index),
    ]);

    final results = await query.get();
    final Map<String, int> intensity = {};
    
    for (final row in results) {
      final date = row.readNullable<String>('date');
      final count = row.read<int>('count');
      if (date != null) {
        intensity[date] = count;
      }
    }
    
    return intensity;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'life_reclaim.db'));
    return NativeDatabase(file);
  });
} 