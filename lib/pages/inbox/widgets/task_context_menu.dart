import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_reclaim/models/task_models.dart';

class TaskContextMenu extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onActivate;
  final VoidCallback? onBreakDown;
  final VoidCallback onDismiss;
  final Offset? position; // 长按位置

  const TaskContextMenu({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
    this.onBreakDown,
    required this.onDismiss,
    this.position,
  });

  @override
  State<TaskContextMenu> createState() => _TaskContextMenuState();
}

class _TaskContextMenuState extends State<TaskContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            // 全屏背景虚化
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black.withValues(alpha: 0.5 * _fadeAnimation.value),
            child: GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // 智能定位的菜单
                  _buildAdaptiveMenu(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdaptiveMenu(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenPadding = MediaQuery.of(context).padding;
    
    // 菜单尺寸
    const menuWidth = 280.0;
    const menuHeight = 220.0;
    
    // 默认位置（屏幕中心）
    Offset menuPosition = Offset(
      (screenSize.width - menuWidth) / 2,
      (screenSize.height - menuHeight) / 2,
    );
    
    // 如果有具体的长按位置，则智能调整
    if (widget.position != null) {
      final position = widget.position!;
      double x = position.dx;
      double y = position.dy;
      
      // 水平方向调整
      if (x + menuWidth > screenSize.width - 20) {
        // 如果右边空间不够，显示在左边
        x = x - menuWidth;
      }
      if (x < 20) {
        // 如果左边空间不够，贴边显示
        x = 20;
      }
      
      // 垂直方向调整
      if (y + menuHeight > screenSize.height - screenPadding.bottom - 20) {
        // 如果下方空间不够，显示在上方
        y = y - menuHeight;
      }
      if (y < screenPadding.top + 20) {
        // 如果上方空间不够，贴边显示
        y = screenPadding.top + 20;
      }
      
      menuPosition = Offset(x, y);
    }
    
    return Positioned(
      left: menuPosition.dx,
      top: menuPosition.dy,
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            width: menuWidth,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.task_alt,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Task Options',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 菜单项
                _buildMenuItem(
                  context,
                  icon: Icons.edit_rounded,
                  title: 'Edit Task',
                  subtitle: 'Modify task details',
                  onTap: () {
                    _dismiss();
                    Future.delayed(const Duration(milliseconds: 100), widget.onEdit);
                  },
                ),
                
                _buildDivider(),
                
                _buildMenuItem(
                  context,
                  icon: widget.task.isActive ? Icons.pause_circle_filled : Icons.play_circle_outline,
                  title: widget.task.isActive ? 'Stop Task' : 'Activate Task',
                  subtitle: widget.task.isActive ? 'Stop timing this task' : 'Start timing this task',
                  onTap: () {
                    _dismiss();
                    Future.delayed(const Duration(milliseconds: 100), widget.onActivate);
                  },
                ),
                
                if (widget.onBreakDown != null) ...[
                  _buildDivider(),
                  
                  _buildMenuItemWithWidget(
                    context,
                    iconWidget: SvgPicture.asset(
                      'assets/graph.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    title: 'Break Down',
                    subtitle: 'Split into smaller tasks',
                    onTap: () {
                      _dismiss();
                      Future.delayed(const Duration(milliseconds: 100), widget.onBreakDown!);
                    },
                  ),
                ],
                
                _buildDivider(),
                
                _buildMenuItem(
                  context,
                  icon: Icons.delete_rounded,
                  title: 'Delete Task',
                  subtitle: 'Permanently remove',
                  isDestructive: true,
                  onTap: () {
                    _dismiss();
                    Future.delayed(const Duration(milliseconds: 100), widget.onDelete);
                  },
                ),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return _buildMenuItemWithWidget(
      context,
      iconWidget: Icon(
        icon,
        size: 20,
        color: isDestructive 
            ? Colors.red[600]
            : Theme.of(context).primaryColor,
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      isDestructive: isDestructive,
    );
  }

  Widget _buildMenuItemWithWidget(
    BuildContext context, {
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withValues(alpha: 0.1)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: iconWidget,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive 
                          ? Colors.red[600]
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDestructive 
                          ? Colors.red[400]
                          : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }
}

// 新增：智能上下文菜单显示器
class SmartContextMenuOverlay {
  static OverlayEntry? _currentOverlay;
  
  static void show({
    required BuildContext context,
    required TaskModel task,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onActivate,
    VoidCallback? onBreakDown,
    Offset? position,
  }) {
    // 先关闭已存在的菜单
    dismiss();
    
    _currentOverlay = OverlayEntry(
      builder: (context) => TaskContextMenu(
        task: task,
        onEdit: onEdit,
        onDelete: onDelete,
        onActivate: onActivate,
        onBreakDown: onBreakDown,
        onDismiss: dismiss,
        position: position,
      ),
    );
    
    Overlay.of(context).insert(_currentOverlay!);
  }
  
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
} 