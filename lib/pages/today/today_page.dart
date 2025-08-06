import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../../controllers/task_controller.dart';
import '../../models/task_models.dart';
import 'package:intl/intl.dart';
import '../inbox/widgets/inbox_task_item.dart';
import 'widgets/calendar_picker.dart';

class TodayPage extends HookWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final selectedDate = useState(DateTime.now());
    final showCalendar = useState(false);
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                // Header with month and controls
                _buildHeader(context, selectedDate.value, selectedDate, showCalendar),
                
                // Week calendar view - 用Obx包装以响应任务数据变化
                Obx(() {
                  // 触发GetX响应式更新的关键：访问tasks数据
                  final _ = controller.tasks.length;
                  return _buildWeekCalendar(context, selectedDate);
                }),
                
                // Planned tasks section
                Expanded(
                  child: _buildPlannedSection(context, controller, selectedDate.value),
                ),
              ],
            ),
          ),
        ),
        // Calendar overlay
        if (showCalendar.value)
          CalendarPicker(
            selectedDate: selectedDate.value,
            onDateSelected: (date) {
              selectedDate.value = date;
              showCalendar.value = false;
            },
            onClose: () {
              showCalendar.value = false;
            },
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DateTime selectedDate, ValueNotifier<DateTime> selectedDateNotifier, ValueNotifier<bool> showCalendar) {
    final now = DateTime.now();
    final isToday = _isSameDay(selectedDate, now);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(selectedDate),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              // Today按钮 - 只在非今日时显示
              if (!isToday) ...[
                GestureDetector(
                  onTap: () {
                    selectedDateNotifier.value = now;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.today,
                          size: 14,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 日历图标
              IconButton(
                onPressed: () {
                  showCalendar.value = true;
                },
                icon: const Icon(Icons.calendar_month),
                iconSize: 24,
                color: Colors.grey[600],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar(BuildContext context, ValueNotifier<DateTime> selectedDate) {
    final now = DateTime.now();
    // 基于选中日期计算本周的开始日期（周一为一周开始）
    final selectedWeekday = selectedDate.value.weekday;
    final startOfWeek = selectedDate.value.subtract(Duration(days: selectedWeekday - 1));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (index) {
          final date = startOfWeek.add(Duration(days: index));
          final isToday = _isSameDay(date, now);
          final isSelected = _isSameDay(date, selectedDate.value);
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                selectedDate.value = date;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('E').format(date).substring(0, 2),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? (isToday ? Colors.blue : Colors.grey[300])
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                              ? (isToday ? Colors.white : Colors.grey[700])
                              : (isToday ? Colors.blue[600] : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                    // Task indicator dots
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _buildTaskIndicators(date),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildTaskIndicators(DateTime date) {
    final controller = Get.find<TaskController>();
    
    // 获取该日期的所有任务
    final tasksForDate = controller.getTasksForDate(date);
    
    // 收集所有任务的标签颜色，去重
    final Set<Color> tagColors = {};
    for (final task in tasksForDate) {
      for (final tag in task.tags) {
        tagColors.add(tag.color);
      }
    }
    
    // 如果没有标签，返回空列表
    if (tagColors.isEmpty) {
      return [];
    }
    
    // 将颜色转换为小圆点，最多显示4个
    final colorList = tagColors.take(4).toList();
    
    return colorList.map((color) {
      return Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }).toList();
  }

  Widget _buildPlannedSection(BuildContext context, TaskController controller, DateTime selectedDate) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Obx(() {
        final activeTask = controller.activeTask.value;
        
        // 使用新的方法获取今天的任务
        final todayTasks = controller.getTasksForDate(selectedDate);
        
        // 按startedAt排序（最新的在上面）
        todayTasks.sort((a, b) {
          final timeA = a.startedAt ?? a.completedAt ?? DateTime.now();
          final timeB = b.startedAt ?? b.completedAt ?? DateTime.now();
          return timeB.compareTo(timeA);
        });
        
        // 从todayTasks中移除当前激活的任务（它会在顶部单独显示）
        final otherTasks = todayTasks.where((task) => 
          activeTask == null || task.id != activeTask.id
        ).toList();
        
        if (otherTasks.isEmpty && activeTask == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No tasks worked on today',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // Active task at the top (if any)
            if (activeTask != null) ...[
              _buildActiveTaskItem(context, activeTask, controller),
              const SizedBox(height: 16),
            ],
            
            // Other tasks worked on today
            ...otherTasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTodayTaskItem(context, task, controller),
            )),
          ],
        );
      }),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Widget _buildActiveTaskItem(BuildContext context, TaskModel task, TaskController controller) {
    // 创建一个修改后的task，用actualMinutes或实时计算的时间替换estimatedMinutes
    final modifiedTask = task.copyWith(
      estimatedMinutes: task.isActive ? task.totalMinutes : task.actualMinutes,
    );
    
    return Obx(() => InboxTaskItem(
      task: modifiedTask,
      mode: TaskItemMode.today,
      isCollapsed: controller.collapsedTasks[task.id] ?? false,
      onToggleCollapse: () {
        controller.toggleSubtaskCollapse(task.id);
      },
      onBreakDown: () {
        // TODO: 实现Break Down功能
        print('Break down task: ${task.title}');
      },
    ));
  }

  Widget _buildTodayTaskItem(BuildContext context, TaskModel task, TaskController controller) {
    // 创建一个修改后的task，用actualMinutes替换estimatedMinutes
    final modifiedTask = task.copyWith(
      estimatedMinutes: task.actualMinutes,
    );
    
    return Obx(() => InboxTaskItem(
      task: modifiedTask,
      mode: TaskItemMode.today,
      isCollapsed: controller.collapsedTasks[task.id] ?? false,
      onToggleCollapse: () {
        controller.toggleSubtaskCollapse(task.id);
      },
      onBreakDown: () {
        // TODO: 实现Break Down功能
        print('Break down task: ${task.title}');
      },
    ));
  }
} 