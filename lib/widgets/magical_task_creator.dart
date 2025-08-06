import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:get/get.dart';
import '../controllers/ai_suggestion_controller.dart';
import '../pages/ai_create_task/ai_create_task_page.dart';
import 'ai_loading_overlay.dart';

/// 🧞‍♂️ 魔法任务创建器 - 阿拉丁神灯风格的任务创建动画
/// 
/// 功能：
/// - 从下往上、从小变大的出现动画
/// - 先快后慢的速度曲线
/// - 背景高斯模糊
/// - 浅紫色渐变背景
/// - 美观的波浪纹理
/// - 任务标题输入框
/// - 确认按钮淡出动画
class MagicalTaskCreator extends StatefulWidget {
  final VoidCallback? onTaskCreated;
  final VoidCallback? onDismiss;
  
  const MagicalTaskCreator({
    super.key,
    this.onTaskCreated,
    this.onDismiss,
  });

  @override
  State<MagicalTaskCreator> createState() => _MagicalTaskCreatorState();
}

class _MagicalTaskCreatorState extends State<MagicalTaskCreator>
    with TickerProviderStateMixin {
  
  // 动画控制器
  late AnimationController _emergenceController;
  late AnimationController _confirmButtonController;
  late AnimationController _waveController;
  
  // 动画
  late Animation<double> _scaleAnimation;
  late Animation<double> _translationAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _confirmButtonOpacity;
  late Animation<double> _waveAnimation;
  
  // 输入控制器
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  
  // 状态
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startEmergenceAnimation();
  }

  void _initializeAnimations() {
    // 出现动画控制器 (1.2秒)
    _emergenceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // 确认按钮控制器 (500毫秒)
    _confirmButtonController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // 波浪动画控制器 (持续循环，加快速度)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // 缩放动画 - 从0.1到1.0，先快后慢
    _scaleAnimation = Tween<double>(
      begin: 0.1,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _emergenceController,
      curve: Curves.elasticOut,
    ));
    
    // 位移动画 - 从底部到中上部
    _translationAnimation = Tween<double>(
      begin: 300.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _emergenceController,
      curve: Curves.easeOutCubic,
    ));
    
    // 透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _emergenceController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    // 确认按钮透明度
    _confirmButtonOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _confirmButtonController,
      curve: Curves.easeOut,
    ));
    
    // 波浪动画
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_waveController);
  }

  void _startEmergenceAnimation() {
    _emergenceController.forward();
    
    // 延迟聚焦到输入框 (减少延迟时间)
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        _titleFocusNode.requestFocus();
      }
    });
  }

  void _handleConfirm() async {
    if (_titleController.text.trim().isEmpty || _isConfirming) return;
    
    setState(() {
      _isConfirming = true;
    });
    
    try {
      // 开始确认按钮淡出动画
      _confirmButtonController.forward();
      
      // 关闭当前魔法创建器
      widget.onDismiss?.call();
      
      // 显示AI加载页面
      _showAILoadingAndAnalyze();
      
      widget.onTaskCreated?.call();
      
    } catch (e) {
      debugPrint('🚨 启动AI分析失败: $e');
      setState(() {
        _isConfirming = false;
      });
    }
  }

  /// 🤖 显示AI加载页面并进行分析
  void _showAILoadingAndAnalyze() {
    Navigator.of(Get.context!).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AILoadingOverlay(
            title: 'AI is generating task suggestions for you...',
            onCancel: () {
              Navigator.of(context).pop();
            },
          );
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ).then((_) {
      // 加载页面关闭后的回调
      debugPrint('🎭 AI loading overlay dismissed');
    });

    // 开始AI分析
    _performAIAnalysis();
  }

  /// 🧠 执行AI分析
  Future<void> _performAIAnalysis() async {
    try {
      debugPrint('🤖 Starting AI analysis for: ${_titleController.text.trim()}');
      
      // 获取AI建议控制器
      final aiController = Get.find<AiSuggestionController>();
      
      // 开始分析任务标题
      await aiController.analyzeTask(_titleController.text.trim(), forceAnalysis: true);
      
      // 无限等待AI分析完成
      while (true) {
        await Future.delayed(const Duration(seconds: 1));
        
        // 检查是否完成分析
        if (!aiController.isAnalyzing.value) {
          final suggestions = aiController.currentSuggestions.value;
          final error = aiController.analysisError.value;
          
          if (suggestions != null) {
            debugPrint('✅ AI analysis completed successfully');
            _navigateToCreateTaskPage(suggestions);
            return;
          } else if (error != null) {
            debugPrint('❌ AI analysis failed: $error');
            _navigateToCreateTaskPage(null);
            return;
          }
        }
        
        debugPrint('⏳ AI analysis in progress...');
      }
      
    } catch (e) {
      debugPrint('🚨 AI analysis error: $e');
      _navigateToCreateTaskPage(null);
    }
  }

  /// 🎯 导航到任务创建页面
  void _navigateToCreateTaskPage(dynamic suggestions) {
    // 关闭加载页面
    Navigator.of(Get.context!).pop();
    
    // 稍微延迟后跳转到创建页面
    Future.delayed(const Duration(milliseconds: 300), () {
      Get.to(() => AICreateTaskPage(
        taskTitle: _titleController.text.trim(),
        suggestions: suggestions,
      ));
    });
  }

  void _handleDismiss() {
    _emergenceController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _emergenceController.dispose();
    _confirmButtonController.dispose();
    _waveController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _emergenceController,
          _confirmButtonController,
          _waveController,
        ]),
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.3), // 半透明背景
            child: GestureDetector(
              onTap: _handleDismiss,
              behavior: HitTestBehavior.opaque, // 确保整个区域都能响应点击
              child: _buildMainContent(),
            ),
          );
        },
      ),
    );
  }



  Widget _buildMainContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 确保高度不为负数，并且有合理的最小值
          SizedBox(
            height: (screenHeight * 0.25 - _translationAnimation.value).clamp(50.0, screenHeight),
          ),
          Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildUnifiedMagicalCard(),
            ),
          ),
          const Spacer(), // 填充剩余空间
        ],
      ),
    );
  }

  /// 🧞‍♂️ 统一的魔法卡片 - 包含所有内容和按钮
  Widget _buildUnifiedMagicalCard() {
    return GestureDetector(
      onTap: () {}, // 阻止点击事件冒泡到父级
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // 统一的渐变背景
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE1BEE7), // 浅紫色
              Color(0xFFCE93D8), // 中紫色
              Color(0xFFBA68C8), // 深紫色
              Color(0xFFE8EAF6), // 浅紫蓝色
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 波浪纹理
            _buildWaveTexture(),
            
            // 统一的内容
            _buildUnifiedCardContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveTexture() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: WaveTexturePainter(_waveAnimation.value),
        ),
      ),
    );
  }

  /// 📝 统一的卡片内容 - 包含标题、输入框和按钮
  Widget _buildUnifiedCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        const Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Create New Task',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 副标题
        const Text(
          'Let AI add smart suggestions to your tasks',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            letterSpacing: 0.3,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 输入框
        _buildTaskTitleInput(),
        
        const SizedBox(height: 32),
        
        // 确认按钮 - 现在整合在卡片内部，使用透明度淡出效果
        Opacity(
          opacity: _confirmButtonOpacity.value,
          child: !_isConfirming ? _buildUnifiedConfirmButton() : _buildUnifiedConfirmingButton(),
        ),
      ],
    );
  }

  Widget _buildTaskTitleInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Enter task title...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          prefixIcon: Icon(
            Icons.task_alt,
            color: Colors.purple.shade400,
          ),
        ),
        onSubmitted: (_) => _handleConfirm(),
        textInputAction: TextInputAction.done,
      ),
    );
  }

  /// 🎯 统一样式的确认按钮 - 融入紫色背景
  Widget _buildUnifiedConfirmButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleConfirm,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.purple.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Task',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
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

  /// ⏳ 统一样式的处理中按钮 - 融入紫色背景
  Widget _buildUnifiedConfirmingButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.7),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade400),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Processing...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.purple.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

/// 🌊 波浪纹理绘制器
class WaveTexturePainter extends CustomPainter {
  final double animationValue;
  
  WaveTexturePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    const waveHeight = 20.0;
    final waveLength = size.width / 3;
    
    // 绘制多层波浪
    for (int i = 0; i < 3; i++) {
      path.reset();
      final yOffset = size.height * 0.2 + i * 60;
      final phase = animationValue + i * math.pi / 3;
      
      path.moveTo(0, yOffset);
      
      for (double x = 0; x <= size.width; x += 5) {
        final y = yOffset + 
                  waveHeight * math.sin((x / waveLength * 2 * math.pi) + phase) +
                  waveHeight * 0.5 * math.sin((x / waveLength * 4 * math.pi) + phase * 2);
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, paint);
    }
    
    // 绘制一些星星装饰
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < 8; i++) {
      final x = (size.width / 8) * i + 20;
      final y = size.height * 0.1 + 
                30 * math.sin(animationValue * 2 + i * math.pi / 4);
      _drawStar(canvas, starPaint, Offset(x, y), 3);
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    const numberOfPoints = 5;
    const angle = 2 * math.pi / numberOfPoints;
    
    for (int i = 0; i < numberOfPoints; i++) {
      final x = center.dx + radius * math.cos(i * angle - math.pi / 2);
      final y = center.dy + radius * math.sin(i * angle - math.pi / 2);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveTexturePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
} 