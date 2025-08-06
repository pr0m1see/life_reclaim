import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../controllers/task_controller.dart';
import '../models/task_models.dart';
import 'priority_indicator.dart';

class TaskItemWidget extends HookWidget {
  final TaskModel task;
  final bool isSubtask;
  final VoidCallback? onToggleCollapse;
  final bool isCollapsed;
  
  const TaskItemWidget({
    super.key,
    required this.task,
    this.isSubtask = false,
    this.onToggleCollapse,
    this.isCollapsed = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final isPressed = useState(false);
    
    return Column(
      children: [
        GestureDetector(
          onLongPressStart: (_) {
            isPressed.value = true;
            if (task.status == TaskStatus.active) {
              controller.deactivateTask(task);
            } else if (task.status == TaskStatus.pending) {
              controller.activateTask(task);
            }
          },
          onLongPressEnd: (_) {
            isPressed.value = false;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _getBackgroundColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPressed.value ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            margin: EdgeInsets.only(
              left: isSubtask ? 32 : 8,
              right: 8,
              top: 4,
              bottom: 4,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: task.subtasks.isNotEmpty ? onToggleCollapse : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Priority indicator
                      if (!isSubtask)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: PriorityIndicator(
                            priority: task.priority,
                            compact: true,
                          ),
                        ),
                      // Checkbox - 只有没有子任务的任务才显示checkbox
                      if (task.shouldShowCheckbox)
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: task.status == TaskStatus.completed,
                            onChanged: (value) {
                              if (value == true) {
                                controller.completeTask(task);
                              } else {
                                controller.uncompleteTask(task);
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      // 如果有子任务，显示完成状态指示器而不是checkbox
                      if (!task.shouldShowCheckbox)
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: task.isCompleted ? Colors.green : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: task.isCompleted ? Colors.green : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: task.isCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      const SizedBox(width: 8),
                      // Task content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: isSubtask ? 14 : 16,
                                      fontWeight: isSubtask ? FontWeight.normal : FontWeight.w500,
                                      decoration: task.status == TaskStatus.completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.status == TaskStatus.completed
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                                if (task.estimatedMinutes != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${task.estimatedMinutes}m',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            if (task.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: task.tags.map((tag) => _buildTag(tag)).toList(),
                              ),
                            ],
                            if (!isSubtask && task.subtasks.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${task.subtasks.where((t) => t.status == TaskStatus.completed).length}/${task.subtasks.length} subtasks',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Subtask indicator
                      if (task.subtasks.isNotEmpty && !isSubtask)
                        Icon(
                          isCollapsed ? Icons.expand_more : Icons.expand_less,
                          size: 20,
                          color: Colors.grey,
                        ),
                      // Active indicator
                      if (task.status == TaskStatus.active)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Subtasks with connection lines
        if (!isSubtask && task.subtasks.isNotEmpty && !isCollapsed) ...[
          Stack(
            children: [
              // Connection line
              Positioned(
                left: isSubtask ? 52 : 28,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: Colors.grey[300],
                ),
              ),
              Column(
                children: task.subtasks.map((subtask) {
                  final isLast = task.subtasks.last == subtask;
                  return Stack(
                    children: [
                      // Horizontal connection line
                      Positioned(
                        left: isSubtask ? 52 : 28,
                        top: 20,
                        child: Container(
                          width: 20,
                          height: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                      // Hide vertical line for last item
                      if (isLast)
                        Positioned(
                          left: isSubtask ? 52 : 28,
                          top: 21,
                          bottom: 0,
                          child: Container(
                            width: 1,
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      TaskItemWidget(
                        task: subtask,
                        isSubtask: true,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  Color _getBackgroundColor(BuildContext context) {
    if (task.status == TaskStatus.active) {
      return Theme.of(context).primaryColor.withValues(alpha: 0.1);
    } else if (task.status == TaskStatus.completed) {
      return Colors.grey.withValues(alpha: 0.1);
    }
    return Theme.of(context).cardColor;
  }
  
  Widget _buildTag(TagModel tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tag.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          color: tag.color.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
} 