import 'dart:math';
import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

class InteractiveWheelDialog extends StatefulWidget {
  final int pointsWon;
  final VoidCallback onFinish;

  const InteractiveWheelDialog({
    super.key,
    required this.pointsWon,
    required this.onFinish,
  });

  @override
  State<InteractiveWheelDialog> createState() => _InteractiveWheelDialogState();
}

class _InteractiveWheelDialogState extends State<InteractiveWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;
  bool _spinning = false;
  bool _finished = false;

  final List<int> slices = [0, 20, 30, 50, 100, 200, 50, 30, 20, 100];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Find the slice index for the points won
    int targetIndex = slices.indexOf(widget.pointsWon);
    if (targetIndex == -1) targetIndex = 0; // fallback

    // Calculate rotation to stop at target slice
    final sliceAngle = (2 * pi) / slices.length;
    // We want the target slice to be at the top (which is -pi/2 in standard circle, but CustomPainter usually starts 0 at right, so top is -pi/2. We will handle offset in painter)
    // Add multiple full rotations (e.g., 5 full circles)
    final double targetRotation = (5 * 2 * pi) - (targetIndex * sliceAngle);

    _animation = Tween<double>(begin: 0, end: targetRotation).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCirc),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _finished = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
            widget.onFinish();
          }
        });
      }
    });

    // Start spinning automatically after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _spinning = true);
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'عجلة الحظ 🎡',
              style: AppType.style(20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _finished
                  ? (widget.pointsWon > 0
                      ? 'ألف مبروك! ربحت نقاط'
                      : 'حظ أوفر المرة الجاية 💔')
                  : 'جاري السحب...',
              style: AppType.style(
                13,
                color: AppColors.muted,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animation.value,
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: CustomPaint(
                          painter: _WheelPainter(slices),
                        ),
                      ),
                    );
                  },
                ),
                // Indicator Arrow
                Transform.translate(
                  offset: const Offset(0, -15),
                  child: const Icon(
                    Icons.arrow_drop_down_circle_rounded,
                    color: AppColors.danger,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _finished
                  ? Column(
                      children: [
                        Text(
                          widget.pointsWon > 0 ? '+${widget.pointsWon}' : '0',
                          style: AppType.style(
                            48,
                            color: widget.pointsWon > 0
                                ? AppColors.success
                                : AppColors.muted,
                            weight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'نقطة ولاء',
                          style: AppType.style(14, weight: FontWeight.w800),
                        ),
                      ],
                    )
                  : const SizedBox(height: 82),
            ),
            const SizedBox(height: 16),
            if (_finished)
              SolidBtn(
                label: 'استلام',
                color: widget.pointsWon > 0
                    ? AppColors.primary
                    : AppColors.ink,
                onTap: () {
                  Navigator.pop(context);
                  widget.onFinish();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<int> slices;

  _WheelPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / slices.length;
    
    // Offset by -pi/2 so the first slice is exactly at the top
    final startOffset = -pi / 2 - (sweepAngle / 2);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < slices.length; i++) {
      final startAngle = startOffset + (i * sweepAngle);
      
      // Draw slice
      final paint = Paint()
        ..color = i % 2 == 0 ? AppColors.primary : AppColors.accent
        ..style = PaintingStyle.fill;
        
      if (slices[i] == 0) {
        paint.color = AppColors.line;
      } else if (slices[i] == 200) {
        paint.color = AppColors.warning; // The jackpot slice
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw text
      canvas.save();
      
      final textAngle = startAngle + (sweepAngle / 2);
      // Move to center, rotate, move outwards
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);
      canvas.translate(radius * 0.65, 0);
      
      // Rotate text so it's readable
      canvas.rotate(pi / 2);

      textPainter.text = TextSpan(
        text: slices[i].toString(),
        style: TextStyle(
          color: slices[i] == 0 ? AppColors.ink : Colors.white,
          fontSize: slices[i] == 200 ? 20 : 16,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
    
    // Draw center peg
    canvas.drawCircle(
      center,
      16,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
