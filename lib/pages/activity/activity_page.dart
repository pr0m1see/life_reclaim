import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import '../../controllers/task_controller.dart';
import '../../models/task_models.dart';

class ActivityPage extends HookWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final taskController = Get.find<TaskController>();
    final activityStats = useState<Map<String, dynamic>>({});
    final tagStats = useState<List<Map<String, dynamic>>>([]);
    final heatmapData = useState<Map<String, int>>({});
    final achievements = useState<List<Map<String, dynamic>>>([]);
    final isLoading = useState<bool>(true);
    
    // 添加ScrollController来控制热力图滚动
    final scrollController = useScrollController();

    // 加载数据的函数（修改为一年）
    Future<void> loadData() async {
      isLoading.value = true;
      try {
        final stats = await taskController.getActivityStats();
        final tags = await taskController.getTagStatistics();
        final heatmap =
            await taskController.getHeatmapData(ActivityPeriod.sixMonths);
        final achievementData = await taskController.getAchievements();

        activityStats.value = stats;
        tagStats.value = tags;
        heatmapData.value = heatmap;
        achievements.value = achievementData;
        
        // 数据加载完成后，滚动到最右边（今天的位置）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      } catch (e) {
        debugPrint('Error loading activity data: $e');
      } finally {
        isLoading.value = false;
      }
    }

    // 初始加载
    useEffect(() {
      loadData();
      return null;
    }, []);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Activity',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity heatmap (GitHub-style)
                    _buildHeatmapCard(context, heatmapData.value, scrollController),

                    const SizedBox(height: 24),

                    // Statistics
                    Text(
                      'Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : _buildStatsGrid(
                            context, activityStats.value, tagStats.value),

                    const SizedBox(height: 24),

                    // Recent achievements
                    isLoading.value
                        ? const SizedBox.shrink()
                        : _buildRecentAchievements(context, achievements.value),

                    const SizedBox(
                        height: 100), // Bottom padding for navigation
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCard(BuildContext context, Map<String, int> heatmap, ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_view,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                'Last 6 months',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Heatmap
          _buildHeatmap(heatmap, scrollController),

          const SizedBox(height: 16),
          // Legend
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              ..._buildLegend(),
              const SizedBox(width: 8),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(Map<String, int> heatmap, ScrollController scrollController) {
    const weeks = 26; // 6个月固定26周

    return Column(
      children: [
        // Month labels - 生成过去6个月的月份标签
        Row(
          children: [
            const SizedBox(width: 32),
            Expanded(
              child: _buildMonthLabels(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Heatmap grid
        Row(
          children: [
            // Weekday labels - 修正位置
            Column(
              children: [
                _buildWeekdayLabel(''), // 空白对应顶部
                _buildWeekdayLabel('Mon'), // 星期一
                _buildWeekdayLabel(''), // 空白
                _buildWeekdayLabel('Wed'), // 星期三
                _buildWeekdayLabel(''), // 空白
                _buildWeekdayLabel('Fri'), // 星期五
                _buildWeekdayLabel(''), // 空白
              ],
            ),
            const SizedBox(width: 8),

            // Grid
            Expanded(
              child: SizedBox(
                height: 84, // 7 days * 12px per cell
                child: ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: weeks,
                  itemBuilder: (context, weekIndex) {
                    return Container(
                      width: 12,
                      margin: const EdgeInsets.only(right: 2),
                      child: Column(
                        children: List.generate(7, (dayIndex) {
                          // 计算实际日期
                          final startDate = _getStartDateForPeriod();
                          final currentDate = startDate
                              .add(Duration(days: weekIndex * 7 + dayIndex));
                          final dateKey =
                              '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

                          // 从真实数据获取强度，如果没有数据则为0
                          final intensity = heatmap[dateKey] ?? 0;

                          return Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _getColorForIntensity(intensity),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdayLabel(String label) {
    return Container(
      height: 12,
      width: 24,
      alignment: Alignment.centerRight,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMonthLabels() {
    final months = <String>[];
    final now = DateTime.now();

    // 生成过去6个月的月份标签
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthName = _getMonthName(month.month);
      months.add(monthName);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: months
          .map((month) => Text(
                month,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ))
          .toList(),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return monthNames[month - 1];
  }

  DateTime _getStartDateForPeriod() {
    final now = DateTime.now();
    return now.subtract(const Duration(days: 180)); // 6个月
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats,
      List<Map<String, dynamic>> tagStats) {
    return Column(
      children: [
        // Main stats grid
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.task_alt,
                color: Colors.blue,
                title: 'Total Tasks',
                value: stats['completedTasks']?.toString() ?? '0',
                subtitle: 'Completed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.timer,
                color: Colors.orange,
                title: 'Total Time',
                value: stats['totalTimeText'] ?? '0h 0m',
                subtitle: 'Focused',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.trending_up,
                color: Colors.green,
                title: 'Daily Average',
                value: stats['dailyAverageText'] ?? '0.0',
                subtitle: 'Tasks/day',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.local_fire_department,
                color: Colors.red,
                title: 'Streak',
                value: stats['streak']?.toString() ?? '0',
                subtitle: 'Days',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Tag breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              if (tagStats.isEmpty)
                Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey[600]),
                )
              else
                ...tagStats.map((tag) {
                  final totalTasks = tagStats.fold<int>(
                      0, (sum, t) => sum + (t['count'] as int));
                  return _buildTagProgress(
                    tag['name'],
                    Color(tag['color']),
                    tag['count'],
                    totalTasks,
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagProgress(String name, Color color, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count tasks',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAchievements(
      BuildContext context, List<Map<String, dynamic>> achievements) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.orange[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Achievements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Achievement items
          if (achievements.isEmpty)
            Text(
              'No achievements yet',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ...achievements.asMap().entries.map((entry) {
              final index = entry.key;
              final achievement = entry.value;
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  _buildAchievementItem(
                    icon: _getIconFromString(achievement['icon']),
                    color: _getColorFromString(achievement['color']),
                    title: achievement['title'],
                    description: achievement['description'],
                    achieved: achievement['achieved'],
                    progress: achievement['progress'],
                  ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAchievementItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool achieved,
    double? progress,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: achieved
                ? color.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: achieved ? color : Colors.grey[400],
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: achieved ? Colors.black87 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (!achieved && progress != null) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 3,
                ),
              ],
            ],
          ),
        ),
        if (achieved)
          Icon(
            Icons.check_circle,
            color: color,
            size: 20,
          )
        else if (progress != null)
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildLegend() {
    final colors = [
      Colors.grey[200]!,
      Colors.green[200]!,
      Colors.green[400]!,
      Colors.green[600]!,
      Colors.green[800]!,
    ];

    return colors
        .map((color) => Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ))
        .toList();
  }

  Color _getColorForIntensity(int intensity) {
    if (intensity == 0) return Colors.grey[200]!;
    if (intensity <= 1) return Colors.green[200]!;
    if (intensity <= 2) return Colors.green[400]!;
    if (intensity <= 3) return Colors.green[600]!;
    return Colors.green[800]!;
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'fire':
        return Icons.local_fire_department;
      case 'timer':
        return Icons.timer;
      case 'task':
        return Icons.task_alt;
      default:
        return Icons.star;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
