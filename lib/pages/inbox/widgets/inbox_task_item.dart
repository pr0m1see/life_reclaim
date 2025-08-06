import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:life_reclaim/controllers/task_controller.dart';
import 'package:life_reclaim/models/task_models.dart';
import 'package:life_reclaim/pages/add_task/add_task_page.dart';
import 'package:life_reclaim/pages/task_decomposition/task_decomposition_page.dart';
import 'task_context_menu.dart';
import 'dart:math';

enum TaskItemMode {
  inbox,
  today,
}

// 带动画效果的任务项组件（用于Inbox页面）
class AnimatedInboxTaskItem extends HookWidget {
  final TaskModel task;
  final bool isSubtask;
  final VoidCallback? onToggleCollapse;
  final bool isCollapsed;
  final VoidCallback? onBreakDown;
  final TaskItemMode mode;

  const AnimatedInboxTaskItem({
    super.key,
    required this.task,
    this.isSubtask = false,
    this.onToggleCollapse,
    this.isCollapsed = false,
    this.onBreakDown,
    this.mode = TaskItemMode.inbox,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final isAnimating = useState(false);

    // 动画定义
    final slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.5), // 向下滑动较小距离，更自然
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut), // 更早开始淡出
    ));

    final scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9, // 轻微缩放，不要太剧烈
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // 完成时的绿色高亮动画
    final highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    if (highlightAnimation.value > 0)
                      BoxShadow(
                        color: Colors.green
                            .withOpacity(0.3 * highlightAnimation.value),
                        blurRadius: 20 * highlightAnimation.value,
                        spreadRadius: 2 * highlightAnimation.value,
                      ),
                  ],
                ),
                child: InboxTaskItem(
                  task: task,
                  isSubtask: isSubtask,
                  onToggleCollapse: onToggleCollapse,
                  isCollapsed: isCollapsed,
                  onBreakDown: onBreakDown,
                  mode: mode,
                  onComplete: () async {
                    if (!isAnimating.value) {
                      isAnimating.value = true;

                      // 添加触觉反馈
                      HapticFeedback.lightImpact();

                      // 播放动画
                      await animationController.forward();

                      // 动画完成后实际完成任务
                      await controller.completeTask(task);

                      isAnimating.value = false;
                      animationController.reset();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class InboxTaskItem extends HookWidget {
  final TaskModel task;
  final bool isSubtask;
  final VoidCallback? onToggleCollapse;
  final bool isCollapsed;
  final VoidCallback? onBreakDown;
  final TaskItemMode mode;
  final VoidCallback? onComplete;

  const InboxTaskItem({
    super.key,
    required this.task,
    this.isSubtask = false,
    this.onToggleCollapse,
    this.isCollapsed = false,
    this.onBreakDown,
    this.mode = TaskItemMode.inbox,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();

    return _buildTaskCard(context, controller);
  }

  Widget _buildTaskCard(BuildContext context, TaskController controller) {
    // 根据模式调整外边距
    final marginValue = mode == TaskItemMode.today ? 8.0 : 16.0;
    final verticalMargin = mode == TaskItemMode.today ? 4.0 : 8.0;

    return Column(
      children: [
        // Main card
        Container(
          margin: EdgeInsets.only(
            left: isSubtask ? 40 : marginValue,
            right: marginValue,
            top: verticalMargin,
            bottom: verticalMargin,
          ),
          child: Material(
            elevation: task.isActive ? 12 : 2,
            borderRadius: BorderRadius.circular(16),
            shadowColor: task.isActive
                ? _getRandomIconConfig().color.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _getCardColor(context),
                border: task.isActive
                    ? Border.all(color: _getRandomIconConfig().color, width: 3)
                    : Border.all(
                        color: Colors.grey.withValues(alpha: 0.1), width: 1),
                gradient: task.isActive
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getCardColor(context),
                          _getRandomIconConfig().color.withValues(alpha: 0.03),
                        ],
                      )
                    : null,
                boxShadow: task.isActive
                    ? [
                        BoxShadow(
                          color: _getRandomIconConfig()
                              .color
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 6,
                          spreadRadius: -2,
                          offset: const Offset(0, -1),
                        ),
                      ]
                    : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (task.hasSubtasks) {
                    // 有子任务时，单击展开/收起
                    onToggleCollapse?.call();
                  } else {
                    // 无子任务时，单击进入编辑或详情
                    _onActivate(controller);
                  }
                },
                onDoubleTap: () {
                  _printTaskDetails();
                },
                onLongPressStart: mode == TaskItemMode.today
                    ? null
                    : (details) {
                        print(
                            '👆 Long press detected on main area: ${task.title}');
                        print('📍 Position: ${details.globalPosition}');
                        SmartContextMenuOverlay.show(
                          context: context,
                          task: task,
                          onEdit: () => _onEdit(context),
                          onDelete: () => _onDelete(controller),
                          onActivate: () => _onActivate(controller),
                          onBreakDown: () => _onBreakDown(context),
                          position: details.globalPosition,
                        );
                      },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // 左侧彩色图标区域 - 占满整个高度
                        if (!isSubtask)
                          Container(
                            width: 48, // 窄宽度
                            decoration: BoxDecoration(
                              color: _getRandomIconConfig().color,
                            ),
                            child: Center(
                              child: Icon(
                                _getRandomIconConfig().icon,
                                color: const Color.fromARGB(195, 255, 255, 255),
                                size: 24,
                              ),
                            ),
                          ),

                        // 主内容区域
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 第一行：时间 + 操作按钮
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      // 时间信息 - 使用Flexible.loose占用尽可能多的空间
                                      if ((mode == TaskItemMode.today &&
                                              task.todayTimeText.isNotEmpty) ||
                                          (mode == TaskItemMode.inbox &&
                                              task.estimatedMinutes !=
                                                  null)) ...[
                                        Flexible(
                                          fit: FlexFit.loose, // 关键：loose模式
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  mode == TaskItemMode.today
                                                      ? task.todayTimeText
                                                      : '${task.estimatedMinutes}m',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 间距
                                        SizedBox(
                                            width: mode == TaskItemMode.inbox
                                                ? 15
                                                : 8),
                                      ],
                                      // 操作按钮组 - 不用Flexible包装，让按钮占用自然大小
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Activate按钮
                                          GestureDetector(
                                            onTap: () {
                                              print(
                                                  '⏱️ Activate button tapped');
                                              if (task.isActive) {
                                                controller.deactivateTask(task);
                                              } else {
                                                controller.activateTask(task);
                                              }
                                            },
                                            onLongPressStart: mode ==
                                                    TaskItemMode.today
                                                ? null
                                                : (details) {
                                                    SmartContextMenuOverlay
                                                        .show(
                                                      context: context,
                                                      task: task,
                                                      onEdit: () =>
                                                          _onEdit(context),
                                                      onDelete: () =>
                                                          _onDelete(controller),
                                                      onActivate: () =>
                                                          _onActivate(
                                                              controller),
                                                      onBreakDown: () =>
                                                          _onBreakDown(context),
                                                      position: details
                                                          .globalPosition,
                                                    );
                                                  },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              child: Icon(
                                                task.isActive
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_outline,
                                                size: 20,
                                                color: task.isActive
                                                    ? _getRandomIconConfig()
                                                        .color
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Break down按钮（仅图标）- 在Today模式下隐藏
                                          if (!task.hasSubtasks &&
                                              !isSubtask &&
                                              onBreakDown != null &&
                                              mode == TaskItemMode.inbox)
                                            GestureDetector(
                                              onTap: () {
                                                print(
                                                    '🔄 Break down button tapped');
                                                _onBreakDown(context);
                                              },
                                              onLongPressStart: mode ==
                                                      TaskItemMode.today
                                                  ? null
                                                  : (details) {
                                                      SmartContextMenuOverlay
                                                          .show(
                                                        context: context,
                                                        task: task,
                                                        onEdit: () =>
                                                            _onEdit(context),
                                                        onDelete: () =>
                                                            _onDelete(
                                                                controller),
                                                        onActivate: () =>
                                                            _onActivate(
                                                                controller),
                                                        onBreakDown: () =>
                                                            _onBreakDown(
                                                                context),
                                                        position: details
                                                            .globalPosition,
                                                      );
                                                    },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                child: SvgPicture.asset(
                                                  'assets/graph.svg',
                                                  width: 20,
                                                  height: 20,
                                                  colorFilter: ColorFilter.mode(
                                                    Colors.blue[600]!,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 第二行：任务标题
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: isSubtask ? 15 : 17,
                                    fontWeight: FontWeight.w600,
                                    color: task.isCompleted
                                        ? Colors.grey[600]
                                        : Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.color,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 12),

                                // 第三行：标签和子任务信息
                                Row(
                                  children: [
                                    // Tags
                                    if (task.tags.isNotEmpty)
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: task.tags
                                              .map((tag) => _buildTag(tag))
                                              .toList(),
                                        ),
                                      ),

                                    // Spacing between tags and subtask info
                                    if (task.tags.isNotEmpty &&
                                        !isSubtask &&
                                        task.subtasks.isNotEmpty)
                                      const SizedBox(width: 8),

                                    // Subtask info
                                    if (!isSubtask && task.subtasks.isNotEmpty)
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.orange[200]!),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.list,
                                                size: 14,
                                                color: Colors.orange[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '${task.subtasks.where((t) => t.isCompleted).length}/${task.subtasks.length}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.orange[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                // Active indicator
                                if (task.isActive) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Working on this task',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 右侧checkbox区域
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildRightButton(context, controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Subtasks with smooth animation
        if (!isSubtask && task.subtasks.isNotEmpty)
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
              alignment: Alignment.topCenter,
              heightFactor: isCollapsed ? 0.0 : 1.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isCollapsed ? 0.0 : 1.0,
                child: Column(
                  children: task.subtasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final subtask = entry.value;
                    return AnimatedSlide(
                      duration: Duration(milliseconds: 200 + (index * 50)),
                      curve: Curves.easeOutCubic,
                      offset: isCollapsed ? const Offset(0, -0.5) : Offset.zero,
                      child: InboxTaskItem(
                        task: subtask,
                        isSubtask: true,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRightButton(BuildContext context, TaskController controller) {
    if (task.hasSubtasks && !isSubtask) {
      // Collapse/expand button for parent tasks
      return GestureDetector(
        onTap: () {
          print('📂 Expand/collapse button tapped');
          onToggleCollapse?.call();
        },
        onLongPressStart: mode == TaskItemMode.today
            ? null
            : (details) {
                print('👆 Long press detected on expand/collapse button');
                print('📍 Position: ${details.globalPosition}');
                // 传递长按事件到父级
                SmartContextMenuOverlay.show(
                  context: context,
                  task: task,
                  onEdit: () => _onEdit(context),
                  onDelete: () => _onDelete(controller),
                  onActivate: () => _onActivate(controller),
                  onBreakDown: () => _onBreakDown(context),
                  position: details.globalPosition,
                );
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              isCollapsed
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              key: ValueKey(isCollapsed),
              color: Colors.grey[600],
              size: 28,
            ),
          ),
        ),
      );
    } else {
      // Checkbox for tasks without subtasks - 支持长按
      return GestureDetector(
        onTap: () {
          print(
              '✅ Checkbox tapped - ${task.isCompleted ? 'Uncompleting' : 'Completing'} task');
          if (task.isCompleted) {
            controller.uncompleteTask(task);
          } else {
            // 在Inbox模式下，如果有onComplete回调，使用动画效果
            if (mode == TaskItemMode.inbox && onComplete != null) {
              onComplete!();
            } else {
              // 其他模式直接完成任务
              controller.completeTask(task);
            }
          }
        },
        onLongPressStart: mode == TaskItemMode.today
            ? null
            : (details) {
                print('👆 Long press detected on checkbox');
                print('📍 Position: ${details.globalPosition}');
                // 传递长按事件到父级
                SmartContextMenuOverlay.show(
                  context: context,
                  task: task,
                  onEdit: () => _onEdit(context),
                  onDelete: () => _onDelete(controller),
                  onActivate: () => _onActivate(controller),
                  onBreakDown: () => _onBreakDown(context),
                  position: details.globalPosition,
                );
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? _getRandomIconConfig().color
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: task.isCompleted
                  ? null
                  : Border.all(
                      color: _getRandomIconConfig().color,
                      width: 3,
                    ),
            ),
            child: task.isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        ),
      );
    }
  }

  Color _getCardColor(BuildContext context) {
    if (task.isCompleted) {
      return Colors.grey[50]!;
    } else if (task.isActive) {
      return Theme.of(context).primaryColor.withValues(alpha: 0.05);
    }
    return Colors.white;
  }

  Widget _buildTag(TagModel tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tag.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tag.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          color: tag.color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 生成随机图标和颜色配置，增加区分度
  _IconConfig _getRandomIconConfig() {
    final random = Random(task.id.hashCode); // 使用任务ID作为种子，确保同一任务的图标颜色固定

    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.red[600]!,
      Colors.teal[600]!,
      Colors.indigo[600]!,
      Colors.pink[600]!,
      Colors.cyan[600]!,
      Colors.amber[600]!,
    ];

    final icons = [
      Icons.lightbulb_outline,
      Icons.rocket_launch,
      Icons.palette,
      Icons.psychology,
      Icons.science,
      Icons.auto_awesome,
      Icons.emoji_objects,
      Icons.explore,
      Icons.travel_explore,
      Icons.analytics,
      Icons.architecture,
      Icons.construction,
      Icons.design_services,
      Icons.engineering,
      Icons.handyman,
      Icons.insights,
      Icons.inventory_2,
      Icons.memory,
      Icons.precision_manufacturing,
      Icons.sports_esports,
    ];

    final selectedColor = colors[random.nextInt(colors.length)];
    final selectedIcon = icons[random.nextInt(icons.length)];

    return _IconConfig(color: selectedColor, icon: selectedIcon);
  }

  void _onEdit(BuildContext context) {
    Get.to(
      () => AddTaskPage(editingTask: task),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onDelete(TaskController controller) {
    controller.deleteTask(task);
  }

  void _onActivate(TaskController controller) {
    if (task.isActive) {
      controller.deactivateTask(task);
    } else {
      controller.activateTask(task);
    }
  }

  void _onBreakDown(BuildContext context) {
    Get.to(
      () => TaskDecompositionPage(task: task),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _printTaskDetails() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📋 TASK DETAILS - Double Tap Debug Info');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🆔 ID: ${task.id}');
    debugPrint('📝 Title: ${task.title}');
    debugPrint('👨‍👧‍👦 Parent ID: ${task.parentId ?? 'None (Root Task)'}');
    debugPrint('');

    debugPrint('📊 STATUS & PRIORITY:');
    debugPrint('   Status: ${task.status} (${task.statusText})');
    debugPrint('   Priority: ${task.priority} (${task.priorityText})');
    debugPrint('   Is Active: ${task.isActive}');
    debugPrint('   Is Completed: ${task.isCompleted}');
    debugPrint('');

    debugPrint('⏱️ TIME TRACKING:');
    debugPrint('   Estimated Minutes: ${task.estimatedMinutes ?? 'Not set'}');
    debugPrint('   Actual Minutes: ${task.actualMinutes ?? 'None'}');
    debugPrint('   Total Minutes (Real-time): ${task.totalMinutes}');
    debugPrint('   Duration Text: ${task.durationText}');
    debugPrint('   Today Time Text: ${task.todayTimeText}');
    debugPrint('   Started At: ${task.startedAt ?? 'Never started'}');
    debugPrint(
        '   Current Session Started: ${task.currentSessionStartedAt ?? 'No active session'}');
    debugPrint('   Completed At: ${task.completedAt ?? 'Not completed'}');
    debugPrint('');

    debugPrint('🗂️ SUBTASKS:');
    debugPrint('   Has Subtasks: ${task.hasSubtasks}');
    debugPrint('   Subtasks Count: ${task.subtasks.length}');
    debugPrint('   Should Show Checkbox: ${task.shouldShowCheckbox}');
    if (task.hasSubtasks) {
      debugPrint('   All Subtasks Completed: ${task.allSubtasksCompleted}');
      debugPrint(
          '   Completed Subtasks: ${task.completedSubtasksCount}/${task.subtasks.length}');
      debugPrint('   Subtask Details:');
      for (int i = 0; i < task.subtasks.length; i++) {
        final subtask = task.subtasks[i];
        debugPrint('     ${i + 1}. ${subtask.title} (${subtask.status})');
      }
    }
    debugPrint('');

    debugPrint('🏷️ TAGS:');
    if (task.tags.isNotEmpty) {
      debugPrint('   Tags Count: ${task.tags.length}');
      for (int i = 0; i < task.tags.length; i++) {
        final tag = task.tags[i];
        debugPrint(
            '     ${i + 1}. ${tag.name} (Color: ${tag.color}, System: ${tag.isSystem})');
      }
    } else {
      debugPrint('   No tags assigned');
    }
    debugPrint('');

    debugPrint('📅 TIMESTAMPS:');
    debugPrint('   Created At: ${task.createdAt}');
    debugPrint('   Updated At: ${task.updatedAt}');
    debugPrint('');

    debugPrint('🎛️ UI STATE:');
    debugPrint('   Mode: $mode');
    debugPrint('   Is Subtask: $isSubtask');
    debugPrint('   Is Collapsed: $isCollapsed');
    debugPrint('═══════════════════════════════════════');
  }
}

class _IconConfig {
  final Color color;
  final IconData icon;

  _IconConfig({required this.color, required this.icon});
}
