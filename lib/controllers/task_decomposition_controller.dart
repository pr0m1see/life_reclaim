import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:life_reclaim/models/task_models.dart';
import 'package:life_reclaim/services/task_decomposition_service.dart';
import 'package:life_reclaim/services/manual_task_decomposition_service.dart';

import 'package:life_reclaim/repositories/database_task_repository.dart';
import 'package:life_reclaim/services/database_service.dart';
import 'task_controller.dart';
import 'package:life_reclaim/services/ollama_task_decomposition_service.dart';

/// 任务拆分状态模型
@immutable
class TaskDecompositionState {
  final TaskModel? parentTask;
  final TaskDecompositionResult? result;
  final TaskDecompositionMode currentMode;
  final TaskDecompositionStatus status;
  final String? error;
  final List<SubtaskSuggestion> customSubtasks; // 手动添加的子任务
  final Map<String, dynamic> metadata;

  const TaskDecompositionState({
    this.parentTask,
    this.result,
    this.currentMode = TaskDecompositionMode.ai,
    this.status = TaskDecompositionStatus.initial,
    this.error,
    this.customSubtasks = const [],
    this.metadata = const {},
  });

  TaskDecompositionState copyWith({
    TaskModel? parentTask,
    TaskDecompositionResult? result,
    TaskDecompositionMode? currentMode,
    TaskDecompositionStatus? status,
    String? error,
    List<SubtaskSuggestion>? customSubtasks,
    Map<String, dynamic>? metadata,
  }) {
    return TaskDecompositionState(
      parentTask: parentTask ?? this.parentTask,
      result: result ?? this.result,
      currentMode: currentMode ?? this.currentMode,
      status: status ?? this.status,
      error: error ?? this.error,
      customSubtasks: customSubtasks ?? this.customSubtasks,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 获取所有有效的子任务建议（包括AI和手动）
  List<SubtaskSuggestion> get allValidSuggestions {
    final aiSuggestions = result?.validSuggestions ?? [];
    return [...aiSuggestions, ...customSubtasks.where((s) => s.isValid)];
  }

  /// 是否有任何建议
  bool get hasSuggestions => allValidSuggestions.isNotEmpty;

  /// 获取总的估算时间
  Duration get totalEstimatedDuration {
    final suggestions = allValidSuggestions;
    int totalMinutes = 0;
    for (final suggestion in suggestions) {
      totalMinutes += suggestion.estimatedMinutes ?? 0;
    }
    return Duration(minutes: totalMinutes);
  }

  @override
  String toString() {
    return 'TaskDecompositionState{mode: $currentMode, status: $status, suggestions: ${allValidSuggestions.length}, error: $error}';
  }
}

/// 任务拆分控制器
class TaskDecompositionController extends GetxController 
    implements TaskDecompositionServiceListener {
  
  // 核心状态
  final Rx<TaskDecompositionState> _state = const TaskDecompositionState().obs;
  TaskDecompositionState get state => _state.value;

  // 服务依赖
  late final DatabaseTaskRepository _repository;
  late final TaskController _taskController;
  
  // 服务实例
  TaskDecompositionService? _currentService;

  @override
  void onInit() {
    super.onInit();
    _initializeDependencies();
    // 异步初始化服务
    _initializeServices();
  }

  @override
  void onClose() {
    if (_currentService is ObservableTaskDecompositionService) {
      (_currentService as ObservableTaskDecompositionService).removeListener(this);
    }
    super.onClose();
  }

  /// 初始化依赖
  void _initializeDependencies() {
    final databaseService = Get.find<DatabaseService>();
    _repository = DatabaseTaskRepository(databaseService.database);
    _taskController = Get.find<TaskController>();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      debugPrint('🔄 Initializing task decomposition services...');
      
      // 注册Ollama AI拆分服务（替换模拟的AI服务）
      final ollamaService = OllamaTaskDecompositionService();
      await ollamaService.initialize(); // 确保服务正确初始化
      
      TaskDecompositionServiceFactory.registerService(
        TaskDecompositionMode.ai, 
        ollamaService,
      );

      // 注册手动拆分服务
      final manualService = ManualTaskDecompositionService();
      TaskDecompositionServiceFactory.registerService(
        TaskDecompositionMode.manual, 
        manualService,
      );

      debugPrint('✅ Task decomposition services initialized');
      debugPrint('  - Ollama AI Service: ${ollamaService.isAvailable ? "Available" : "Unavailable"}');
      debugPrint('  - Manual Service: ${manualService.isAvailable ? "Available" : "Unavailable"}');
    } catch (e) {
      debugPrint('❌ Failed to initialize decomposition services: $e');
      // 如果Ollama初始化失败，确保手动服务仍然可用
      final manualService = ManualTaskDecompositionService();
      TaskDecompositionServiceFactory.registerService(
        TaskDecompositionMode.manual, 
        manualService,
      );
    }
  }

  /// 开始拆分任务
  Future<void> startDecomposition(TaskModel task) async {
    try {
      debugPrint('🔄 Starting decomposition for task: ${task.title}');
      
      _updateState(
        parentTask: task,
        status: TaskDecompositionStatus.initial,
        error: null,
      );

      // 检测可用的服务并选择模式
      await _detectAndSelectService();

      // 开始拆分
      await _performDecomposition(task);
    } catch (e) {
      debugPrint('❌ Error starting decomposition: $e');
      _updateState(
        status: TaskDecompositionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// 检测并选择服务
  Future<void> _detectAndSelectService() async {
    // 优先尝试AI服务
    TaskDecompositionService? service = 
        TaskDecompositionServiceFactory.getAvailableService(TaskDecompositionMode.ai);
    
    TaskDecompositionMode selectedMode;
    if (service?.isAvailable == true) {
      selectedMode = TaskDecompositionMode.ai;
      debugPrint('🤖 AI service available, using AI mode');
    } else {
      // 降级到手动模式
      service = TaskDecompositionServiceFactory.getService(TaskDecompositionMode.manual);
      selectedMode = TaskDecompositionMode.manual;
      debugPrint('✏️ AI not available, falling back to manual mode');
    }

    if (service == null) {
      throw Exception('No decomposition service available');
    }

    _currentService = service;
    if (_currentService is ObservableTaskDecompositionService) {
      (_currentService as ObservableTaskDecompositionService).addListener(this);
    }
    
    _updateState(currentMode: selectedMode);
  }

  /// 执行拆分
  Future<void> _performDecomposition(TaskModel task) async {
    if (_currentService == null) {
      throw Exception('No service available for decomposition');
    }

    _updateState(status: TaskDecompositionStatus.loading);

    try {
      final result = await _currentService!.decomposeTask(task);
      
      if (result.isSuccess) {
        _updateState(
          result: result,
          status: TaskDecompositionStatus.success,
        );
        debugPrint('✅ Decomposition completed: ${result.suggestions.length} suggestions');
      } else {
        _updateState(
          status: TaskDecompositionStatus.error,
          error: result.errorMessage ?? 'Unknown decomposition error',
        );
      }
    } catch (e) {
      _updateState(
        status: TaskDecompositionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// 切换拆分模式
  Future<void> switchMode(TaskDecompositionMode mode) async {
    if (state.currentMode == mode) return;

    try {
      debugPrint('🔄 Switching to mode: ${mode.displayName}');
      
      final service = TaskDecompositionServiceFactory.getService(mode);
      if (service?.isAvailable != true) {
        throw Exception('Service for mode ${mode.displayName} is not available');
      }

      if (_currentService is ObservableTaskDecompositionService) {
        (_currentService as ObservableTaskDecompositionService).removeListener(this);
      }
      _currentService = service;
      if (_currentService is ObservableTaskDecompositionService) {
        (_currentService as ObservableTaskDecompositionService).addListener(this);
      }

      _updateState(currentMode: mode);

      // 如果有父任务，重新执行拆分
      if (state.parentTask != null) {
        await _performDecomposition(state.parentTask!);
      }
    } catch (e) {
      debugPrint('❌ Error switching mode: $e');
      _updateState(
        status: TaskDecompositionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// 接受建议
  void acceptSuggestion(String suggestionId) {
    final result = state.result;
    if (result == null) return;

    final updatedSuggestions = result.suggestions.map((suggestion) {
      if (suggestion.id == suggestionId) {
        return suggestion.copyWith(isAccepted: true);
      }
      return suggestion;
    }).toList();

    final updatedResult = result.copyWith(suggestions: updatedSuggestions);
    _updateState(result: updatedResult);

    debugPrint('✅ Accepted suggestion: $suggestionId');
  }

  /// 拒绝建议
  void rejectSuggestion(String suggestionId) {
    final result = state.result;
    if (result == null) return;

    final updatedSuggestions = result.suggestions.map((suggestion) {
      if (suggestion.id == suggestionId) {
        return suggestion.copyWith(isAccepted: false);
      }
      return suggestion;
    }).toList();

    final updatedResult = result.copyWith(suggestions: updatedSuggestions);
    _updateState(result: updatedResult);

    debugPrint('❌ Rejected suggestion: $suggestionId');
  }

  /// 修改建议
  void modifySuggestion(String suggestionId, SubtaskSuggestion updatedSuggestion) {
    final result = state.result;
    if (result == null) return;

    final updatedSuggestions = result.suggestions.map((suggestion) {
      if (suggestion.id == suggestionId) {
        return updatedSuggestion.copyWith(
          isAccepted: true,
          isModified: true,
        );
      }
      return suggestion;
    }).toList();

    final updatedResult = result.copyWith(suggestions: updatedSuggestions);
    _updateState(result: updatedResult);

    debugPrint('📝 Modified suggestion: $suggestionId');
  }

  /// 添加手动子任务
  void addManualSubtask(SubtaskSuggestion subtask) {
    final updatedCustomSubtasks = [...state.customSubtasks, subtask];
    _updateState(customSubtasks: updatedCustomSubtasks);

    debugPrint('➕ Added manual subtask: ${subtask.title}');
  }

  /// 移除手动子任务
  void removeManualSubtask(String subtaskId) {
    final updatedCustomSubtasks = state.customSubtasks
        .where((subtask) => subtask.id != subtaskId)
        .toList();
    _updateState(customSubtasks: updatedCustomSubtasks);

    debugPrint('🗑️ Removed manual subtask: $subtaskId');
  }

  /// 更新手动子任务
  void updateManualSubtask(String subtaskId, SubtaskSuggestion updatedSubtask) {
    final updatedCustomSubtasks = state.customSubtasks.map((subtask) {
      if (subtask.id == subtaskId) {
        return updatedSubtask;
      }
      return subtask;
    }).toList();

    _updateState(customSubtasks: updatedCustomSubtasks);

    debugPrint('📝 Updated manual subtask: $subtaskId');
  }

  /// 批量接受所有建议
  void acceptAllSuggestions() {
    final result = state.result;
    if (result == null) return;

    final updatedSuggestions = result.suggestions.map((suggestion) {
      return suggestion.copyWith(isAccepted: true);
    }).toList();

    final updatedResult = result.copyWith(suggestions: updatedSuggestions);
    _updateState(result: updatedResult);

    debugPrint('✅ Accepted all suggestions');
  }

  /// 重新生成建议
  Future<void> regenerateSuggestions() async {
    if (state.parentTask == null) return;

    await _performDecomposition(state.parentTask!);
    debugPrint('🔄 Regenerated suggestions');
  }

  /// 保存拆分结果
  Future<void> saveDecomposition() async {
    if (state.parentTask == null || !state.hasSuggestions) {
      throw Exception('No valid decomposition to save');
    }

    try {
      _updateState(status: TaskDecompositionStatus.saving);

      final validSuggestions = state.allValidSuggestions;
      debugPrint('💾 Saving ${validSuggestions.length} subtasks');

      // 为每个建议创建子任务
      for (final suggestion in validSuggestions) {
        await _repository.createTask(
          title: suggestion.title,
          status: TaskStatus.pending,
          priority: suggestion.suggestedPriority ?? TaskPriority.importantNotUrgent,
          estimatedMinutes: suggestion.estimatedMinutes,
          parentId: state.parentTask!.id,
          tagIds: [], // TODO: 根据建议的标签创建或查找对应的标签ID
        );
      }

      // 刷新任务列表
      await _taskController.loadTasks();

      _updateState(status: TaskDecompositionStatus.saved);
      debugPrint('✅ Decomposition saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving decomposition: $e');
      _updateState(
        status: TaskDecompositionStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// 重置状态
  void reset() {
    if (_currentService is ObservableTaskDecompositionService) {
      (_currentService as ObservableTaskDecompositionService).removeListener(this);
    }
    _currentService = null;
    _updateState(
      parentTask: null,
      result: null,
      currentMode: TaskDecompositionMode.ai,
      status: TaskDecompositionStatus.initial,
      error: null,
      customSubtasks: [],
      metadata: {},
    );
    debugPrint('🔄 Reset decomposition state');
  }

  /// 更新状态的辅助方法
  void _updateState({
    TaskModel? parentTask,
    TaskDecompositionResult? result,
    TaskDecompositionMode? currentMode,
    TaskDecompositionStatus? status,
    String? error,
    List<SubtaskSuggestion>? customSubtasks,
    Map<String, dynamic>? metadata,
  }) {
    _state.value = _state.value.copyWith(
      parentTask: parentTask,
      result: result,
      currentMode: currentMode,
      status: status,
      error: error,
      customSubtasks: customSubtasks,
      metadata: metadata,
    );
  }

  // TaskDecompositionServiceListener 实现

  @override
  void onServiceAvailabilityChanged(TaskDecompositionService service, bool isAvailable) {
    debugPrint('📡 Service ${service.serviceName} availability changed: $isAvailable');
    // 如果当前服务不可用，尝试切换到其他可用服务
    if (!isAvailable && _currentService == service) {
      final fallbackService = TaskDecompositionServiceFactory.getAvailableService();
      if (fallbackService != null && fallbackService != service) {
        switchMode(fallbackService.supportedMode);
      }
    }
  }

  @override
  void onDecompositionStarted(TaskDecompositionService service, TaskModel task) {
    debugPrint('🚀 Decomposition started by ${service.serviceName} for task: ${task.title}');
  }

  @override
  void onDecompositionCompleted(TaskDecompositionService service, TaskModel task, TaskDecompositionResult result) {
    debugPrint('🎉 Decomposition completed by ${service.serviceName}: ${result.suggestions.length} suggestions');
  }

  @override
  void onDecompositionFailed(TaskDecompositionService service, TaskModel task, String error) {
    debugPrint('💥 Decomposition failed by ${service.serviceName}: $error');
  }
} 