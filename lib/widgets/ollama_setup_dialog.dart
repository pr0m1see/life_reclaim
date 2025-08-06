import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_config_service.dart';

/// Ollama初始设置对话框
/// 
/// 在用户第一次使用AI功能时显示，让用户配置Ollama服务器的IP地址
class OllamaSetupDialog extends StatefulWidget {
  final VoidCallback? onSetupComplete;
  
  const OllamaSetupDialog({
    super.key,
    this.onSetupComplete,
  });

  @override
  State<OllamaSetupDialog> createState() => _OllamaSetupDialogState();
}

class _OllamaSetupDialogState extends State<OllamaSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '11434');
  final _networkConfig = NetworkConfigService();
  
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  
  @override
  void initState() {
    super.initState();
    // 预设一个常用的IP地址
    _ipController.text = '192.168.50.219';
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击空白区域收起键盘
        FocusScope.of(context).unfocus();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Setup',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Configure Ollama server connection',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, 
                           color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Setup Required',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enter the IP address of your computer running Ollama server. This enables AI-powered task suggestions and decomposition.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IP Address field
                  Text(
                    'Server IP Address',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g., 192.168.1.100',
                      prefixIcon: const Icon(Icons.computer),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an IP address';
                      }
                      
                      // Basic IP address validation
                      final parts = value.trim().split('.');
                      if (parts.length != 4) {
                        return 'Invalid IP address format';
                      }
                      
                      for (final part in parts) {
                        final num = int.tryParse(part);
                        if (num == null || num < 0 || num > 255) {
                          return 'Invalid IP address format';
                        }
                      }
                      
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Port field
                  Text(
                    'Port (Optional)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '11434 (default)',
                      prefixIcon: const Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final port = int.tryParse(value.trim());
                        if (port == null || port < 1 || port > 65535) {
                          return 'Port must be between 1 and 65535';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            
            // Connection Status
            if (_connectionStatus != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _connectionStatus!.contains('success') || _connectionStatus!.contains('available')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _connectionStatus!.contains('success') || _connectionStatus!.contains('available')
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _connectionStatus!.contains('success') || _connectionStatus!.contains('available')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _connectionStatus!.contains('success') || _connectionStatus!.contains('available')
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _connectionStatus!,
                        style: TextStyle(
                          fontSize: 14,
                          color: _connectionStatus!.contains('success') || _connectionStatus!.contains('available')
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                // Test Connection button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading || _isTestingConnection ? null : _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Save button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _isTestingConnection ? null : _saveConfiguration,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save & Continue'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  /// 测试连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });
    
    try {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 11434;
      final testUrl = 'http://$ip:$port';
      
      final result = await _networkConfig.performHealthCheck(testUrl);
      
      setState(() {
        if (result.isAvailable) {
          _connectionStatus = 'Connection successful! Found ${result.availableModels.length} models available.';
        } else {
          _connectionStatus = 'Connection failed: ${result.error ?? 'Unknown error'}';
        }
      });
      
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  /// 保存配置
  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 11434;
      
      // 保存配置并标记为非第一次使用
      await _networkConfig.setInitialHost(ip, port);
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 关闭对话框
        Navigator.of(context).pop();
        
        // 调用完成回调
        widget.onSetupComplete?.call();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 