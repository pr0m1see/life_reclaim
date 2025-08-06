import 'package:flutter/material.dart';
import '../models/task_models.dart';
import 'priority_indicator.dart';

class TimeEntryCard extends StatelessWidget {
  final TaskModel task;
  final DateTime date;
  
  const TimeEntryCard({
    super.key,
    required this.task,
    required this.date,
  });
  
  @override
  Widget build(BuildContext context) {
    final duration = Duration(minutes: task.estimatedMinutes ?? 0);
    final progressValue = _getProgressValue();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(),
              ),
              minHeight: 4,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Task icon/category
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getTaskColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getTaskIcon(),
                      color: _getTaskColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Task info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PriorityIndicator(
                              priority: task.priority,
                              compact: true,
                            ),
                            const SizedBox(width: 8),
                            if (task.tags.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: task.tags.first.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task.tags.first.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: task.tags.first.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _formatTime(task.completedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Duration
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getProgressColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 14,
                        color: _getProgressColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  double _getProgressValue() {
    // Mock progress based on task completion
    return task.status == TaskStatus.completed ? 1.0 : 0.7;
  }
  
  Color _getProgressColor() {
    switch (task.priority) {
      case TaskPriority.importantUrgent:
        return Colors.red[600]!;
      case TaskPriority.importantNotUrgent:
        return Colors.orange[600]!;
      case TaskPriority.urgentNotImportant:
        return Colors.blue[600]!;
    }
  }
  
  Color _getTaskColor() {
    if (task.tags.isNotEmpty) {
      return task.tags.first.color;
    }
    return _getProgressColor();
  }
  
  IconData _getTaskIcon() {
    if (task.tags.isNotEmpty) {
      final tagName = task.tags.first.name.toLowerCase();
      if (tagName.contains('work')) return Icons.work;
      if (tagName.contains('coding')) return Icons.code;
      if (tagName.contains('meeting')) return Icons.people;
      if (tagName.contains('exercise')) return Icons.fitness_center;
      if (tagName.contains('reading')) return Icons.book;
    }
    return Icons.task_alt;
  }
  
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }
} 