import 'package:flutter/material.dart';
import '../../../models/task_models.dart';

class PriorityIndicator extends StatelessWidget {
  final TaskPriority priority;
  final bool compact;
  
  const PriorityIndicator({
    super.key,
    required this.priority,
    this.compact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final config = _getPriorityConfig();
    
    if (compact) {
      return Container(
        width: 4,
        height: 24,
        decoration: BoxDecoration(
          color: config.color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 14,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 根据 priority 返回对应的 config
  _PriorityConfig _getPriorityConfig() {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return _PriorityConfig(
          color: Colors.red[600]!,
          icon: Icons.flag,
          label: 'Urgent',
        );
      case TaskPriority.importantNotUrgent:
        return _PriorityConfig(
          color: Colors.orange[600]!,
          icon: Icons.star,
          label: 'Important',
        );
      case TaskPriority.urgentNotImportant:
        return _PriorityConfig(
          color: Colors.blue[600]!,
          icon: Icons.schedule,
          label: 'Quick',
        );
    }
  }
}

class _PriorityConfig {
  final Color color;
  final IconData icon;
  final String label;
  
  _PriorityConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
} 