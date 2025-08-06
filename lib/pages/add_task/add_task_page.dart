import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../../controllers/task_controller.dart';
import '../../models/task_models.dart';
import '../../widgets/priority_selector.dart';
import '../../widgets/tag_selector.dart';

class AddTaskPage extends HookWidget {
  final TaskModel? editingTask;
  
  const AddTaskPage({super.key, this.editingTask});
  
  bool get isEditing => editingTask != null;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final titleController = useTextEditingController(text: editingTask?.title ?? '');
    final selectedPriority = useState<TaskPriority>(editingTask?.priority ?? TaskPriority.importantNotUrgent);
    final selectedTags = useState<List<TagModel>>(editingTask?.tags ?? []);
    final estimatedMinutes = useState<int?>(editingTask?.estimatedMinutes ?? (isEditing ? null : 30));
    final isLoading = useState(false);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Task' : 'Add Task',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: isLoading.value ? null : () => _saveTask(
              context,
              controller,
              titleController.text,
              selectedPriority.value,
              selectedTags.value,
              estimatedMinutes.value,
              isLoading,
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleController.text.trim().isEmpty
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task title
            _buildSectionTitle('Task Title'),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(fontSize: 16),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            
            // Priority
            _buildSectionTitle('Priority'),
            const SizedBox(height: 8),
            PrioritySelector(
              selectedPriority: selectedPriority.value,
              onPrioritySelected: (priority) {
                selectedPriority.value = priority;
              },
            ),
            const SizedBox(height: 24),
            
            // Tags
            _buildSectionTitle('Tags'),
            const SizedBox(height: 8),
            TagSelector(
              selectedTags: selectedTags.value,
              onTagsChanged: (tags) {
                selectedTags.value = tags;
              },
            ),
            const SizedBox(height: 24),
            
            // Time estimation
            _buildSectionTitle('Estimated Time'),
            const SizedBox(height: 8),
            _buildTimeEstimation(estimatedMinutes),
            const SizedBox(height: 32),
            
            // AI Suggestions (placeholder) - Only show for new tasks
            if (!isEditing && titleController.text.trim().isNotEmpty) ...[
              _buildSectionTitle('AI Suggestions'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'AI Analysis',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI task analysis will be implemented in future phases. For now, manually set priority, tags, and time estimation.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
  
  Widget _buildTimeEstimation(ValueNotifier<int?> estimatedMinutes) {
    final commonTimes = [15, 30, 45, 60, 90, 120];
    
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commonTimes.map((minutes) {
            final isSelected = estimatedMinutes.value == minutes;
            return GestureDetector(
              onTap: () {
                estimatedMinutes.value = isSelected ? null : minutes;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(Get.context!).primaryColor
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${minutes}m',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          estimatedMinutes.value != null
              ? 'Estimated: ${estimatedMinutes.value} minutes'
              : 'Default: 30 minutes (will be used if none selected)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: estimatedMinutes.value == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
  
  Future<void> _saveTask(
    BuildContext context,
    TaskController controller,
    String title,
    TaskPriority priority,
    List<TagModel> tags,
    int? estimatedMinutes,
    ValueNotifier<bool> isLoading,
  ) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    isLoading.value = true;
    
    // Save task
    try {
      if (isEditing) {
        // Update existing task
        final updatedTask = editingTask!.copyWith(
          title: title.trim(),
          priority: priority,
          estimatedMinutes: estimatedMinutes,
          tags: tags,
        );
        await controller.updateTask(updatedTask);
      } else {
        // Create new task
        await controller.createTask(
          title.trim(),
          priority: priority,
          estimatedMinutes: estimatedMinutes,
          tags: tags,
        );
      }
      
      isLoading.value = false;
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing 
              ? 'Task "${title.trim()}" updated successfully'
              : 'Task "${title.trim()}" created successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      isLoading.value = false;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing 
              ? 'Error updating task: $e'
              : 'Error creating task: $e'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 