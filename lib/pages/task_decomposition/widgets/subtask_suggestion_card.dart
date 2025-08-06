import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/task_decomposition_models.dart';
import '../../../models/task_models.dart';

class SubtaskSuggestionCard extends StatelessWidget {
  final SubtaskSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const SubtaskSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(
          color: suggestion.isAccepted 
              ? const Color(0xFF4facfe).withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: suggestion.isAccepted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          if (suggestion.isAccepted)
            BoxShadow(
              color: const Color(0xFF4facfe).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and edit button
                Row(
                  children: [
                    // Status indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: suggestion.isAccepted 
                            ? const Color(0xFF4facfe)
                            : Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        boxShadow: suggestion.isAccepted
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4facfe).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Order number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        '${suggestion.order}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Modified indicator
                    if (suggestion.isModified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'Modified',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    // Edit button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onEdit,
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Description
                if (suggestion.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    suggestion.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Time estimate and tags
                Row(
                  children: [
                    // Time estimate
                    if (suggestion.estimatedDuration != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF667eea).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(suggestion.estimatedDuration!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    // Priority indicator
                    if (suggestion.suggestedPriority != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(suggestion.suggestedPriority!).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getPriorityColor(suggestion.suggestedPriority!).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getPriorityText(suggestion.suggestedPriority!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _getPriorityColor(suggestion.suggestedPriority!),
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Tags indicator
                    if (suggestion.suggestedTags.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_offer_outlined,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${suggestion.suggestedTags.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    // Reject button
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: suggestion.isAccepted 
                              ? Colors.red.withOpacity(0.15)
                              : Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: suggestion.isAccepted 
                                ? Colors.red.withOpacity(0.3)
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onReject,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  suggestion.isAccepted ? Icons.remove_circle_outline : Icons.close,
                                  size: 16,
                                  color: suggestion.isAccepted ? Colors.red : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  suggestion.isAccepted ? 'Remove' : 'Reject',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: suggestion.isAccepted ? Colors.red : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Accept button
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: suggestion.isAccepted
                              ? const LinearGradient(
                                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                                )
                              : null,
                          color: suggestion.isAccepted 
                              ? null 
                              : Colors.white.withOpacity(0.1),
                          border: suggestion.isAccepted 
                              ? null 
                              : Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                          boxShadow: suggestion.isAccepted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4facfe).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onAccept,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  suggestion.isAccepted ? Icons.check_circle : Icons.add_circle_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  suggestion.isAccepted ? 'Accepted' : 'Accept',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return Colors.red;
      case TaskPriority.importantNotUrgent:
        return Colors.orange;
      case TaskPriority.urgentNotImportant:
        return Colors.yellow;
    }
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.importantUrgent:
        return 'High';
      case TaskPriority.importantNotUrgent:
        return 'Medium';
      case TaskPriority.urgentNotImportant:
        return 'Low';
    }
  }
} 