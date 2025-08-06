import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 网络配置服务
///
/// 负责管理Ollama服务器的连接配置，包括：
/// - 自动平台检测和配置
/// - 手动配置选项
/// - 连接健康检查
/// - 网络状态监控
class NetworkConfigService {
  /// shared preferences key
  static const String _hostKey = 'ollama_host';
  static const String _portKey = 'ollama_port';
  static const String _enabledKey = 'ollama_enabled';
  static const String _lastHealthCheckKey = 'ollama_last_health_check';
  static const String _isFirstTimeKey = 'ollama_is_first_time';

  static const int _defaultPort = 11434;
  static const Duration _healthCheckTimeout = Duration(seconds: 5);

  late final SharedPreferences _prefs;
  late final Connectivity _connectivity;

  bool _isInitialized = false;

  /// 初始化网络配置服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _connectivity = Connectivity();
    _isInitialized = true;
  }

  /// 获取Ollama服务的基础URL
  Future<String> getOllamaBaseUrl() async {
    await initialize();

    // 检查是否有手动配置的主机地址
    final customHost = _prefs.getString(_hostKey);
    if (customHost != null && customHost.isNotEmpty) {
      final port = _prefs.getInt(_portKey) ?? _defaultPort;
      return 'http://$customHost:$port';
    }

    debugPrint('No custom host found, using auto detected url');

    // 自动检测平台配置
    return await _getAutoDetectedUrl();
  }

  /// 自动检测平台配置
  Future<String> _getAutoDetectedUrl() async {
    if (kIsWeb) {
      // Web平台，假设服务运行在localhost
      return 'http://localhost:$_defaultPort';
    }

    if (Platform.isAndroid) {
      // Android模拟器使用特殊IP地址
      if (_isRunningOnEmulator()) {
        return 'http://10.0.2.2:$_defaultPort';
      } else {
        // 物理设备，需要用户配置PC的IP地址
        return await _getPhysicalDeviceUrl();
      }
    }

    if (Platform.isIOS) {
      // iOS模拟器可以使用localhost
      if (_isRunningOnSimulator()) {
        return 'http://localhost:$_defaultPort';
      } else {
        // 物理设备，需要用户配置PC的IP地址
        return await _getPhysicalDeviceUrl();
      }
    }

    // 默认配置
    return 'http://localhost:$_defaultPort';
  }

  /// 检测是否运行在Android模拟器上
  bool _isRunningOnEmulator() {
    // 这里可以添加更复杂的检测逻辑
    // 目前简单返回false，实际项目中可以检查系统属性
    return Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment['ANDROID_EMULATOR'] == 'true';
  }

  /// 检测是否运行在iOS模拟器上
  bool _isRunningOnSimulator() {
    // iOS模拟器检测逻辑
    return Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
  }

  /// 获取物理设备的URL配置
  Future<String> _getPhysicalDeviceUrl() async {
    // 对于物理设备，尝试从网络发现或使用默认配置
    final networkAddresses = await _discoverPossibleAddresses();

    for (final address in networkAddresses) {
      final url = 'http://$address:$_defaultPort';
      if (await _isOllamaAvailable(url)) {
        return url;
      }
    }

    // 如果都不可用，返回需要用户配置的提示地址
    return 'http://192.168.50.171:$_defaultPort';
  }

  /// 发现可能的网络地址
  Future<List<String>> _discoverPossibleAddresses() async {
    final addresses = <String>[];

    try {
      // 获取当前设备的网络信息
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // 基于当前设备IP推测可能的服务器地址
            final segments = addr.address.split('.');
            if (segments.length == 4) {
              // 尝试常见的主机地址
              addresses.addAll([
                '${segments[0]}.${segments[1]}.${segments[2]}.1', // 路由器地址
                '${segments[0]}.${segments[1]}.${segments[2]}.100', // 常见PC地址
                '${segments[0]}.${segments[1]}.${segments[2]}.101', // 常见PC地址
              ]);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error discovering network addresses: $e');
    }

    return addresses;
  }

  /// 检查Ollama服务是否可用
  Future<bool> _isOllamaAvailable(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_healthCheckTimeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 执行完整的健康检查
  Future<HealthCheckResult> performHealthCheck([String? customUrl]) async {
    await initialize(); // 确保服务已初始化
    final url = customUrl ?? await getOllamaBaseUrl();
    final startTime = DateTime.now();

    try {
      // 检查基本连接
      final response = await http.get(
        Uri.parse('$url/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_healthCheckTimeout);

      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List?)
                ?.map((m) => m['name'] as String)
                .toList() ??
            [];

        // 更新最后健康检查时间
        await _prefs.setString(
            _lastHealthCheckKey, DateTime.now().toIso8601String());

        return HealthCheckResult(
          isAvailable: true,
          latencyMs: latency,
          availableModels: models,
          url: url,
          error: null,
        );
      } else {
        return HealthCheckResult(
          isAvailable: false,
          latencyMs: latency,
          availableModels: [],
          url: url,
          error: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds;

      return HealthCheckResult(
        isAvailable: false,
        latencyMs: latency,
        availableModels: [],
        url: url,
        error: e.toString(),
      );
    }
  }

  /// 设置自定义主机配置
  Future<void> setCustomHost(String host, [int? port]) async {
    await initialize();

    await _prefs.setString(_hostKey, host);
    if (port != null) {
      await _prefs.setInt(_portKey, port);
    }
  }

  /// 清除自定义配置，回到自动检测
  Future<void> clearCustomHost() async {
    await initialize();

    await _prefs.remove(_hostKey);
    await _prefs.remove(_portKey);
  }

  /// 获取当前配置信息
  Future<NetworkConfig> getCurrentConfig() async {
    await initialize();

    final customHost = _prefs.getString(_hostKey);
    final customPort = _prefs.getInt(_portKey);
    final isEnabled = _prefs.getBool(_enabledKey) ?? true;
    final lastHealthCheck = _prefs.getString(_lastHealthCheckKey);

    return NetworkConfig(
      customHost: customHost,
      customPort: customPort,
      isEnabled: isEnabled,
      lastHealthCheck:
          lastHealthCheck != null ? DateTime.parse(lastHealthCheck) : null,
      autoDetectedUrl: await _getAutoDetectedUrl(),
    );
  }

  /// 启用或禁用Ollama服务
  Future<void> setEnabled(bool enabled) async {
    await initialize();
    await _prefs.setBool(_enabledKey, enabled);
  }

  /// 检查是否是第一次使用
  Future<bool> isFirstTime() async {
    await initialize();
    return _prefs.getBool(_isFirstTimeKey) ?? true;
  }

  /// 设置初始化IP地址并标记为非第一次使用
  Future<void> setInitialHost(String host, [int? port]) async {
    await setCustomHost(host, port);
    await _prefs.setBool(_isFirstTimeKey, false);
  }

  /// 监听网络连接状态变化
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;
}

/// 健康检查结果
class HealthCheckResult {
  final bool isAvailable;
  final int latencyMs;
  final List<String> availableModels;
  final String url;
  final String? error;

  const HealthCheckResult({
    required this.isAvailable,
    required this.latencyMs,
    required this.availableModels,
    required this.url,
    this.error,
  });

  @override
  String toString() {
    if (isAvailable) {
      return 'Ollama服务可用 (${latencyMs}ms延迟, ${availableModels.length}个模型)';
    } else {
      return 'Ollama服务不可用: $error';
    }
  }
}

/// 网络配置信息
class NetworkConfig {
  final String? customHost;
  final int? customPort;
  final bool isEnabled;
  final DateTime? lastHealthCheck;
  final String autoDetectedUrl;

  const NetworkConfig({
    this.customHost,
    this.customPort,
    required this.isEnabled,
    this.lastHealthCheck,
    required this.autoDetectedUrl,
  });

  /// 获取当前生效的URL
  String get effectiveUrl {
    if (customHost != null) {
      final port = customPort ?? 11434;
      return 'http://$customHost:$port';
    }
    return autoDetectedUrl;
  }

  /// 是否使用自定义配置
  bool get isUsingCustomConfig => customHost != null;
}
