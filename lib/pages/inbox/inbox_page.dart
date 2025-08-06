import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:life_reclaim/controllers/task_controller.dart';
import 'widgets/inbox_task_item.dart';

class InboxPage extends HookWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(TaskController());
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Inbox',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Obx(() => controller.activeTask.value != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Task list
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final pendingTasks = controller.pendingTasks;
                
                if (pendingTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All tasks completed!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Press + to create new tasks',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: pendingTasks.length,
                  itemBuilder: (context, index) {
                    final task = pendingTasks[index];
                    // Only show root tasks (subtasks are shown within parent)
                    if (task.parentId != null) return const SizedBox.shrink();
                    
                    return Obx(() => AnimatedInboxTaskItem(
                      task: task,
                      mode: TaskItemMode.inbox,
                      isCollapsed: controller.collapsedTasks[task.id] ?? false,
                      onToggleCollapse: () {
                        controller.toggleSubtaskCollapse(task.id);
                      },
                      onBreakDown: () {
                        _showBreakDownDialog(context, task, controller);
                      },
                    ));
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showBreakDownDialog(BuildContext context, task, TaskController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Break Down Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task: ${task.title}'),
            const SizedBox(height: 16),
            const Text(
              'AI-powered task breakdown will be implemented in future phases. For now, you can manually create subtasks.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to add subtask page
              Navigator.pushNamed(context, '/add-task');
            },
            child: const Text('Add Subtask'),
          ),
        ],
      ),
    );
  }
} 