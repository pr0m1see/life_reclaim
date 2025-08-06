import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🤖 现代科技风格的AI加载覆盖层
/// 
/// 功能：
/// - 科技感的动画效果
/// - 脉冲波纹
/// - 粒子动画
/// - AI生成提示文本
class AILoadingOverlay extends StatefulWidget {
  final String title;
  final VoidCallback? onCancel;
  
  const AILoadingOverlay({
    super.key,
    this.title = 'AI is generating task suggestions for you...',
    this.onCancel,
  });

  @override
  State<AILoadingOverlay> createState() => _AILoadingOverlayState();
}

class _AILoadingOverlayState extends State<AILoadingOverlay>
    with TickerProviderStateMixin {
  
  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _textController;
  
  // 动画
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // 脉冲动画 (1.5秒循环)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // 旋转动画 (3秒循环)
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    // 粒子动画 (2秒循环)
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleController);
    
    // 文字闪烁动画 (2.5秒循环)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    _textOpacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _particleController.repeat();
    _textController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _rotationController,
            _particleController,
            _textController,
          ]),
          builder: (context, child) {
            return Stack(
              children: [
                // 背景粒子效果
                _buildParticleBackground(),
                
                // 主要内容
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // AI加载动画
                      _buildAILoadingAnimation(),
                      
                      const SizedBox(height: 48),
                      
                      // 加载文本
                      _buildLoadingText(),
                      
                      const SizedBox(height: 32),
                      
                      // 进度指示器
                      _buildProgressIndicator(),
                      
                      const SizedBox(height: 48),
                      
                      // 取消按钮
                      if (widget.onCancel != null) _buildCancelButton(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🌌 粒子背景效果
  Widget _buildParticleBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ParticleBackgroundPainter(_particleAnimation.value),
      ),
    );
  }

  /// 🤖 AI加载动画
  Widget _buildAILoadingAnimation() {
    return Transform.scale(
      scale: _pulseAnimation.value,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.blue.shade400.withOpacity(0.8),
              Colors.purple.shade600.withOpacity(0.6),
              Colors.transparent,
            ],
            stops: const [0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 外圈旋转环
            Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.shade300,
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: ArcPainter(
                    progress: _particleAnimation.value,
                    color: Colors.blue.shade400,
                  ),
                ),
              ),
            ),
            
            // 内圈反向旋转环
            Transform.rotate(
              angle: -_rotationAnimation.value * 0.7,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.purple.shade300,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            
            // 中心AI图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Colors.blue.shade600,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📝 加载文本
  Widget _buildLoadingText() {
    return Opacity(
      opacity: _textOpacityAnimation.value,
      child: Column(
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'This may take a few seconds...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 进度指示器
  Widget _buildProgressIndicator() {
    return Container(
      width: 200,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.blue.shade400,
          ),
        ),
      ),
    );
  }

  /// ❌ 取消按钮
  Widget _buildCancelButton() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: widget.onCancel,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 🎨 弧形进度绘制器
class ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    
    // 绘制进度弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(ArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ⭐ 粒子背景绘制器
class ParticleBackgroundPainter extends CustomPainter {
  final double animationValue;
  
  ParticleBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // 绘制浮动粒子
    for (int i = 0; i < 20; i++) {
      final x = (size.width / 20) * i + 
                50 * math.sin(animationValue * 2 * math.pi + i * 0.5);
      final y = (size.height / 10) * (i % 10) + 
                30 * math.cos(animationValue * 2 * math.pi + i * 0.3);
      
      final opacity = (0.1 + 0.2 * math.sin(animationValue * 4 * math.pi + i)).clamp(0.0, 0.3);
      
      paint.color = Colors.blue.withOpacity(opacity);
      
      canvas.drawCircle(
        Offset(x, y),
        2 + math.sin(animationValue * 3 * math.pi + i) * 1,
        paint,
      );
    }
    
    // 绘制连接线
    paint
      ..color = Colors.purple.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    for (int i = 0; i < 5; i++) {
      final startX = size.width * 0.2 * i;
      final startY = size.height * 0.3 + 
                     50 * math.sin(animationValue * math.pi + i);
      final endX = size.width * 0.2 * (i + 1);
      final endY = size.height * 0.7 + 
                   50 * math.cos(animationValue * math.pi + i);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticleBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
} 