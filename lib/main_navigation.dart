import 'package:flutter/material.dart';
import 'pages/inbox/inbox_page.dart';
import 'pages/today/today_page.dart';
import 'pages/models/models_page.dart';
import 'pages/activity/activity_page.dart';
import 'widgets/magical_task_creator.dart';
import 'widgets/ollama_setup_dialog.dart';
import 'services/network_config_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _networkConfig = NetworkConfigService();
  
  final List<Widget> _pages = const [
    InboxPage(),
    TodayPage(),
    ModelsPage(),
    ActivityPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddTaskPressed,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? 
               Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧两个导航项
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.inbox, 'Inbox'),
                _buildNavItem(1, Icons.today, 'Today'),
              ],
            ),
          ),
          
          // 中间空白区域（为FAB预留空间）
          const Expanded(
            flex: 1,
            child: SizedBox(),
          ),
          
          // 右侧两个导航项
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(2, Icons.psychology, 'Models'),
                _buildNavItem(3, Icons.grid_view, 'Activity'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? theme.primaryColor 
                  : theme.unselectedWidgetColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected 
                    ? theme.primaryColor 
                    : theme.unselectedWidgetColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理添加任务按钮点击
  Future<void> _handleAddTaskPressed() async {
    try {
      // 检查是否是第一次使用
      final isFirstTime = await _networkConfig.isFirstTime();
      
      if (isFirstTime) {
        // 第一次使用，显示设置对话框
        _showOllamaSetupDialog();
      } else {
        // 非第一次使用，显示魔法任务创建器
        _showMagicalTaskCreator();
      }
    } catch (e) {
      // 如果检查失败，默认显示魔法任务创建器
      debugPrint('Error checking first time usage: $e');
      _showMagicalTaskCreator();
    }
  }

  /// 显示Ollama设置对话框
  void _showOllamaSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (context) => OllamaSetupDialog(
        onSetupComplete: () {
          // 设置完成后，显示魔法任务创建器
          _showMagicalTaskCreator();
        },
      ),
    );
  }

  /// 🧞‍♂️ 显示魔法任务创建器
  void _showMagicalTaskCreator() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // 透明背景
        barrierDismissible: false, // 不允许点击外部关闭
        pageBuilder: (context, animation, secondaryAnimation) {
          return MagicalTaskCreator(
            onTaskCreated: () {
              // 任务创建完成后的回调
              debugPrint('🎉 任务创建完成！');
              // 这里可以添加任务创建的实际逻辑
            },
            onDismiss: () {
              // 关闭魔法创建器
              Navigator.of(context).pop();
            },
          );
        },
        transitionDuration: Duration.zero, // 不使用默认的页面切换动画
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
} 