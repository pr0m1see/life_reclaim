import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../../controllers/task_controller.dart';
import '../../controllers/ai_suggestion_controller.dart';
import '../../models/task_models.dart';
import '../../models/task_suggestion_models.dart';
import '../../widgets/priority_selector.dart';
import '../../widgets/tag_selector.dart';

/// 🤖 AI驱动的任务创建页面
/// 
/// 功能：
/// - 显示AI生成的建议（标签、优先级、时间估算）
/// - 允许用户编辑和确认
/// - 简洁圆润的UI设计
/// - 跟踪用户对AI建议的接受/拒绝/修改
class AICreateTaskPage extends HookWidget {
  final String taskTitle;
  final TaskSuggestionResponse? suggestions;
  
  const AICreateTaskPage({
    super.key,
    required this.taskTitle,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final aiController = Get.find<AiSuggestionController>();
    
    final titleController = useTextEditingController(text: taskTitle);
    final isLoading = useState(false);
    final availableTags = useState<List<TagModel>>([]);
    
    // 初始化状态 - 使用AI建议或默认值
    final selectedPriority = useState<TaskPriority>(
      suggestions?.prioritySuggestion.priority ?? TaskPriority.importantNotUrgent
    );
    
    final selectedTags = useState<List<TagModel>>([]);
    
    final estimatedMinutes = useState<int?>(
      suggestions?.timeSuggestion.estimatedMinutes ?? 30
    );

    // 加载标签并匹配AI建议
    useEffect(() {
      Future<void> loadAndMatchTags() async {
        try {
          debugPrint('🤖 AI Suggestions received:');
          debugPrint('   - Priority: ${suggestions?.prioritySuggestion.priority}');
          debugPrint('   - Tags: ${suggestions?.tagSuggestions.map((t) => t.name).join(', ')}');
          debugPrint('   - Time: ${suggestions?.timeSuggestion.estimatedMinutes} minutes');
          
          // 加载现有标签
          final allTags = await controller.getAllTags();
          availableTags.value = allTags;
          debugPrint('📋 Loaded ${allTags.length} existing tags: ${allTags.map((t) => t.name).join(', ')}');
          
          // 如果有AI建议的标签，尝试匹配现有标签
          if (suggestions?.tagSuggestions.isNotEmpty == true) {
            final matchedTags = <TagModel>[];
            
            for (final suggestedTag in suggestions!.tagSuggestions) {
              // 首先尝试匹配现有标签
              TagModel? existingTag;
              try {
                existingTag = allTags.firstWhere(
                  (tag) => tag.name.toLowerCase() == suggestedTag.name.toLowerCase(),
                );
                debugPrint('✅ Matched existing tag: ${existingTag.name}');
              } catch (e) {
                existingTag = null;
                debugPrint('➕ Creating new tag: ${suggestedTag.name}');
              }
              
              if (existingTag != null) {
                // 使用现有标签
                matchedTags.add(existingTag);
              } else {
                // 创建新标签并保存到数据库
                try {
                  final newTagId = await controller.createTag(suggestedTag.name, suggestedTag.color);
                  final newTag = TagModel(
                    id: newTagId,
                    name: suggestedTag.name,
                    color: suggestedTag.color,
                    isSystem: false,
                  );
                  matchedTags.add(newTag);
                  debugPrint('✅ Created new tag: ${newTag.name} with ID: ${newTag.id}');
                  
                  // 重新加载所有标签以包含新创建的标签
                  final updatedTags = await controller.getAllTags();
                  availableTags.value = updatedTags;
                } catch (e) {
                  debugPrint('❌ Failed to create tag ${suggestedTag.name}: $e');
                  // 如果创建失败，使用临时TagModel作为fallback
                  matchedTags.add(suggestedTag.toTagModel());
                }
              }
            }
            
            selectedTags.value = matchedTags;
            debugPrint('🏷️ Final selected tags: ${selectedTags.value.map((t) => '${t.name}(${t.id})').join(', ')}');
          }
          
        } catch (e) {
          debugPrint('❌ Error loading tags: $e');
        }
      }
      
      loadAndMatchTags();
      return null;
    }, []);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🎨 自定义顶部栏
            _buildCustomAppBar(context),
            
            // 📝 主要内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🤖 AI建议状态指示器
                    _buildAISuggestionHeader(),
                    
                    const SizedBox(height: 32),
                    
                    // 📝 任务标题
                    _buildTaskTitleSection(titleController),
                    
                    const SizedBox(height: 32),
                    
                    // 🏷️ 标签建议
                    _buildTagSuggestionSection(selectedTags),
                    
                    const SizedBox(height: 32),
                    
                    // ⭐ 优先级建议
                    _buildPrioritySuggestionSection(selectedPriority),
                    
                    const SizedBox(height: 32),
                    
                    // ⏰ 时间估算建议
                    _buildTimeSuggestionSection(estimatedMinutes),
                    
                    const SizedBox(height: 48),
                    
                    // 💾 保存按钮
                    _buildSaveButton(
                      context,
                      controller,
                      aiController,
                      titleController,
                      selectedPriority,
                      selectedTags,
                      estimatedMinutes,
                      isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 自定义顶部栏
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 关闭按钮
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 标题
          const Expanded(
            child: Text(
              'AI Task Creator',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          // AI标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🤖 AI建议状态指示器
  Widget _buildAISuggestionHeader() {
    if (suggestions == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI suggestions unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Please fill in the details manually',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.purple.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI suggestions ready',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(suggestions!.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // 置信度指示器
          _buildConfidenceIndicator(suggestions!.confidence),
        ],
      ),
    );
  }

  /// 📊 置信度指示器
  Widget _buildConfidenceIndicator(double confidence) {
    final color = confidence >= 0.8 
        ? Colors.green 
        : confidence >= 0.6 
            ? Colors.orange 
            : Colors.red;
    
    return Container(
      width: 48,
      height: 8,
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: confidence,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  /// 📝 任务标题部分
  Widget _buildTaskTitleSection(TextEditingController titleController) {
    return _buildSection(
      title: 'Task Title',
      icon: Icons.task_alt,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: titleController,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter task title...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  /// 🏷️ 标签建议部分
  Widget _buildTagSuggestionSection(ValueNotifier<List<TagModel>> selectedTags) {
    return _buildSection(
      title: 'Tags',
      icon: Icons.label,
      isAISuggested: suggestions?.tagSuggestions.isNotEmpty == true,
             child: TagSelector(
         selectedTags: selectedTags.value,
         onTagsChanged: (tags) => selectedTags.value = tags,
       ),
    );
  }

  /// ⭐ 优先级建议部分
  Widget _buildPrioritySuggestionSection(ValueNotifier<TaskPriority> selectedPriority) {
    return _buildSection(
      title: 'Priority',
      icon: Icons.flag,
      isAISuggested: suggestions?.prioritySuggestion != null,
             child: PrioritySelector(
         selectedPriority: selectedPriority.value,
         onPrioritySelected: (priority) => selectedPriority.value = priority,
       ),
    );
  }

  /// ⏰ 时间估算建议部分
  Widget _buildTimeSuggestionSection(ValueNotifier<int?> estimatedMinutes) {
    return _buildSection(
      title: 'Time Estimate',
      icon: Icons.schedule,
      isAISuggested: suggestions?.timeSuggestion != null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                estimatedMinutes.value != null 
                    ? '${estimatedMinutes.value} minutes'
                    : 'No estimate',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showTimeEstimateDialog(estimatedMinutes),
            ),
          ],
        ),
      ),
    );
  }

  /// 📋 通用部分构建器
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool isAISuggested = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isAISuggested) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  /// 💾 保存按钮
  Widget _buildSaveButton(
    BuildContext context,
    TaskController controller,
    AiSuggestionController aiController,
    TextEditingController titleController,
    ValueNotifier<TaskPriority> selectedPriority,
    ValueNotifier<List<TagModel>> selectedTags,
    ValueNotifier<int?> estimatedMinutes,
    ValueNotifier<bool> isLoading,
  ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading.value ? null : () => _saveTask(
            context,
            controller,
            aiController,
            titleController.text,
            selectedPriority.value,
            selectedTags.value,
            estimatedMinutes.value,
            isLoading,
          ),
          child: Center(
            child: isLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Create Task',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// ⏰ 时间估算对话框
  void _showTimeEstimateDialog(ValueNotifier<int?> estimatedMinutes) {
    // TODO: 实现时间估算选择对话框
  }

  /// 💾 保存任务
  Future<void> _saveTask(
    BuildContext context,
    TaskController controller,
    AiSuggestionController aiController,
    String title,
    TaskPriority priority,
    List<TagModel> tags,
    int? minutes,
    ValueNotifier<bool> isLoading,
  ) async {
    if (title.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a task title',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      return;
    }

    try {
      isLoading.value = true;

             // 创建任务
       await controller.createTask(
         title.trim(),
         priority: priority,
         estimatedMinutes: minutes,
         tags: tags,
         aiSuggestions: suggestions,
         suggestionUsage: suggestions != null ? {
           'tags': suggestions!.tagSuggestions.isNotEmpty,
           'priority': true,
           'time': suggestions!.timeSuggestion.estimatedMinutes > 0,
         } : null,
       );

      // 记录AI建议的使用情况
      if (suggestions != null) {
        aiController.acceptSuggestion('full_task_creation');
      }

      // 显示成功消息
      Get.snackbar(
        'Success',
        'Task created successfully!',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );

      // 关闭页面
      Navigator.of(context).pop();

    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create task: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }
} 