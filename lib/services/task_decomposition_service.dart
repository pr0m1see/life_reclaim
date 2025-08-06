import '../models/task_models.dart';

/// 任务拆分服务抽象接口
/// 
/// 提供统一的任务拆分能力，支持AI和手动两种模式
/// 实现类需要提供具体的拆分逻辑
abstract class TaskDecompositionService {
  /// 服务名称
  String get serviceName;
  
  /// 服务是否可用
  bool get isAvailable;
  
  /// 支持的拆分模式
  TaskDecompositionMode get supportedMode;
  
  /// 拆分任务
  /// 
  /// [task] 要拆分的父任务
  /// [context] 可选的上下文信息（用户偏好、历史数据等）
  /// 
  /// 返回拆分结果，包含建议的子任务列表
  Future<TaskDecompositionResult> decomposeTask(
    TaskModel task, {
    Map<String, dynamic> context = const {},
  });
  
  /// 验证拆分结果
  /// 
  /// [result] 拆分结果
  /// 
  /// 返回验证是否通过
  bool validateResult(TaskDecompositionResult result) {
    // 默认验证逻辑
    return result.suggestions.isNotEmpty && 
           result.suggestions.every((s) => s.isValid);
  }
  
  /// 获取服务健康状态
  /// 
  /// 返回服务的详细状态信息
  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'serviceName': serviceName,
      'isAvailable': isAvailable,
      'supportedMode': supportedMode.name,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// 任务拆分服务工厂
/// 
/// 负责创建和管理不同类型的拆分服务
class TaskDecompositionServiceFactory {
  static final Map<TaskDecompositionMode, TaskDecompositionService> _services = {};
  
  /// 注册服务
  static void registerService(TaskDecompositionMode mode, TaskDecompositionService service) {
    _services[mode] = service;
  }
  
  /// 获取服务
  static TaskDecompositionService? getService(TaskDecompositionMode mode) {
    return _services[mode];
  }
  
  /// 获取可用的服务
  static TaskDecompositionService? getAvailableService([TaskDecompositionMode? preferredMode]) {
    // 如果指定了偏好模式且服务可用，优先使用
    if (preferredMode != null) {
      final service = _services[preferredMode];
      if (service?.isAvailable == true) {
        return service;
      }
    }
    
    // 按优先级查找可用服务：AI > Manual
    for (final mode in [TaskDecompositionMode.ai, TaskDecompositionMode.manual]) {
      final service = _services[mode];
      if (service?.isAvailable == true) {
        return service;
      }
    }
    
    return null;
  }
  
  /// 获取所有已注册的服务
  static List<TaskDecompositionService> getAllServices() {
    return _services.values.toList();
  }
  
  /// 清空所有服务
  static void clear() {
    _services.clear();
  }
}

/// 任务拆分服务状态监听器
abstract class TaskDecompositionServiceListener {
  /// 服务可用性变化时调用
  void onServiceAvailabilityChanged(TaskDecompositionService service, bool isAvailable);
  
  /// 拆分开始时调用
  void onDecompositionStarted(TaskDecompositionService service, TaskModel task);
  
  /// 拆分完成时调用
  void onDecompositionCompleted(TaskDecompositionService service, TaskModel task, TaskDecompositionResult result);
  
  /// 拆分失败时调用
  void onDecompositionFailed(TaskDecompositionService service, TaskModel task, String error);
}

/// 带有监听器支持的任务拆分服务基类
abstract class ObservableTaskDecompositionService extends TaskDecompositionService {
  final List<TaskDecompositionServiceListener> _listeners = [];
  
  /// 添加监听器
  void addListener(TaskDecompositionServiceListener listener) {
    _listeners.add(listener);
  }
  
  /// 移除监听器
  void removeListener(TaskDecompositionServiceListener listener) {
    _listeners.remove(listener);
  }
  
  /// 通知可用性变化
  void notifyAvailabilityChanged(bool isAvailable) {
    for (final listener in _listeners) {
      listener.onServiceAvailabilityChanged(this, isAvailable);
    }
  }
  
  /// 通知拆分开始
  void notifyDecompositionStarted(TaskModel task) {
    for (final listener in _listeners) {
      listener.onDecompositionStarted(this, task);
    }
  }
  
  /// 通知拆分完成
  void notifyDecompositionCompleted(TaskModel task, TaskDecompositionResult result) {
    for (final listener in _listeners) {
      listener.onDecompositionCompleted(this, task, result);
    }
  }
  
  /// 通知拆分失败
  void notifyDecompositionFailed(TaskModel task, String error) {
    for (final listener in _listeners) {
      listener.onDecompositionFailed(this, task, error);
    }
  }
} 