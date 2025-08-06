import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/task_controller.dart';
import '../models/task_models.dart';
import '../pages/add_task/add_task_page.dart';
import 'task_item_widget.dart';

class SwipeableTaskItem extends StatelessWidget {
  final TaskModel task;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  
  const SwipeableTaskItem({
    super.key,
    required this.task,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('task-${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Left swipe - Edit task
          await _navigateToEditTask(context);
          return false; // Don't dismiss the item
        } else if (direction == DismissDirection.endToStart) {
          // Right swipe - Delete confirmation
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Task'),
              content: Text('Are you sure you want to delete "${task.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ?? false;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final controller = Get.find<TaskController>();
          controller.deleteTask(task);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${task.title}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // TODO: Implement undo functionality
                },
              ),
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.blue,
        child: const Icon(
          Icons.edit,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: TaskItemWidget(
        task: task,
        isCollapsed: isCollapsed,
        onToggleCollapse: onToggleCollapse,
      ),
    );
  }
  
  Future<void> _navigateToEditTask(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTaskPage(editingTask: task),
      ),
    );
  }
} 