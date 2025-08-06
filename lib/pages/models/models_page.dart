import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ai_test_controller.dart';
import '../../widgets/ollama_setup_dialog.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  /// 显示IP配置对话框
  void _showIpConfigDialog(BuildContext context, AiTestController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OllamaSetupDialog(
        onSetupComplete: () {
          // 配置完成后刷新状态
          controller.refreshStatus();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AiTestController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure IP Address',
            onPressed: () => _showIpConfigDialog(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: () => controller.refreshStatus(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 服务状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ollama Service Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Obx(() => Row(
                      children: [
                        Icon(
                          controller.isServiceAvailable.value
                              ? Icons.check_circle
                              : Icons.error,
                          color: controller.isServiceAvailable.value
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.isServiceAvailable.value
                              ? 'Connected'
                              : 'Disconnected',
                        ),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Obx(() => Text(
                      'URL: ${controller.serverUrl.value}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )),
                    Obx(() => Text(
                      'Model: ${controller.currentModel.value}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // AI测试区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Test',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    
                    // 预设的测试prompt
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Prompt:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Obx(() => Text(
                            controller.testPrompt.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 测试按钮
                    SizedBox(
                      width: double.infinity,
                      child: Obx(() => ElevatedButton.icon(
                        onPressed: controller.isLoading.value
                            ? null
                            : () => controller.runAiTest(),
                        icon: controller.isLoading.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.psychology),
                        label: Text(
                          controller.isLoading.value ? 'Testing...' : 'Test AI',
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 结果显示区域
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Response',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            child: Obx(() {
                              if (controller.isLoading.value) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (controller.errorMessage.value.isNotEmpty) {
                                return Text(
                                  'Error: ${controller.errorMessage.value}',
                                  style: TextStyle(color: Colors.red[700]),
                                );
                              } else if (controller.aiResponse.value.isNotEmpty) {
                                return SelectableText(
                                  controller.aiResponse.value,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                );
                              } else {
                                return Text(
                                  'Click "Test AI" to see the response here...',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                );
                              }
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 统计信息
            Obx(() => controller.responseTime.value > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Response time: ${controller.responseTime.value}ms',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
} 