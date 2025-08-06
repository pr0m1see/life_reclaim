import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../models/task_models.dart';
import '../controllers/task_controller.dart';

class TagSelector extends HookWidget {
  final List<TagModel> selectedTags;
  final Function(List<TagModel>) onTagsChanged;
  
  const TagSelector({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final availableTags = useState<List<TagModel>>([]);
    final isLoading = useState(true);
    
    // Load tags from database
    useEffect(() {
      Future<void> loadTags() async {
        try {
          debugPrint('🏷️ Loading tags...');
          final tags = await controller.getAllTags();
          debugPrint('📋 Loaded ${tags.length} tags');
          for (final tag in tags) {
            debugPrint('  Tag: ${tag.name} (${tag.color})');
          }
          availableTags.value = tags;
        } catch (e) {
          debugPrint('❌ Error loading tags: $e');
        } finally {
          isLoading.value = false;
        }
      }
      
      loadTags();
      return null;
    }, []);
    
    if (isLoading.value) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available tags
        if (availableTags.value.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags.value.map((tag) {
              final isSelected = selectedTags.any((t) => t.name.toLowerCase() == tag.name.toLowerCase());
              
              return GestureDetector(
                onTap: () {
                  List<TagModel> newTags;
                  if (isSelected) {
                    newTags = selectedTags.where((t) => t.name.toLowerCase() != tag.name.toLowerCase()).toList();
                  } else {
                    newTags = [...selectedTags, tag];
                  }
                  onTagsChanged(newTags);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? tag.color.withValues(alpha: 0.2)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? tag.color 
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tag.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? tag.color : Colors.black87,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check,
                          size: 16,
                          color: tag.color,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        
        // Add some spacing only if there are available tags
        if (availableTags.value.isNotEmpty) const SizedBox(height: 16),
        
        // Custom tag input
        GestureDetector(
          onTap: () => _showCustomTagDialog(context, controller, availableTags),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create custom tag',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  void _showCustomTagDialog(
    BuildContext context, 
    TaskController controller, 
    ValueNotifier<List<TagModel>> availableTags,
  ) {
    final textController = TextEditingController();
    Color selectedColor = Colors.blue;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Custom Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Tag name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Choose color:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Colors.blue,
                  Colors.green,
                  Colors.red,
                  Colors.purple,
                  Colors.orange,
                  Colors.teal,
                  Colors.indigo,
                  Colors.cyan,
                  Colors.pink,
                  Colors.amber,
                ].map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (textController.text.trim().isNotEmpty) {
                  try {
                    // Save to database first
                    await controller.createTag(textController.text.trim(), selectedColor);
                    
                    // Reload tags from database
                    final updatedTags = await controller.getAllTags();
                    availableTags.value = updatedTags;
                    
                    // Find the newly created tag and add it to selected tags
                    final newTag = updatedTags.firstWhere(
                      (tag) => tag.name == textController.text.trim(),
                      orElse: () => TagModel(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: textController.text.trim(),
                        color: selectedColor,
                      ),
                    );
                    
                    final newTags = [...selectedTags, newTag];
                    onTagsChanged(newTags);
                    
                    Navigator.of(context).pop();
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tag "${textController.text.trim()}" created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating tag: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
} 