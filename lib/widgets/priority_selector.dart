import 'package:flutter/material.dart';
import '../models/task_models.dart';

class PrioritySelector extends StatelessWidget {
  final TaskPriority selectedPriority;
  final Function(TaskPriority) onPrioritySelected;
  
  const PrioritySelector({
    super.key,
    required this.selectedPriority,
    required this.onPrioritySelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: TaskPriority.values.map((priority) {
        final config = _getPriorityConfig(priority);
        final isSelected = selectedPriority == priority;
        
        return GestureDetector(
          onTap: () => onPrioritySelected(priority),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? config.color.withValues(alpha: 0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? config.color 
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  config.icon,
                  color: config.color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? config.color : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: config.color,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  _PriorityConfig _getPriorityConfig(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return _PriorityConfig(
          color: Colors.red[600]!,
          icon: Icons.flag,
          title: 'Important & Urgent',
          description: 'Do it now - critical tasks requiring immediate attention',
        );
      case TaskPriority.importantNotUrgent:
        return _PriorityConfig(
          color: Colors.orange[600]!,
          icon: Icons.star,
          title: 'Important & Not Urgent',
          description: 'Schedule it - important for long-term goals',
        );
      case TaskPriority.urgentNotImportant:
        return _PriorityConfig(
          color: Colors.blue[600]!,
          icon: Icons.schedule,
          title: 'Urgent & Not Important',
          description: 'Delegate or do quickly - interruptions and distractions',
        );
    }
  }
}

class _PriorityConfig {
  final Color color;
  final IconData icon;
  final String title;
  final String description;
  
  _PriorityConfig({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });
} 