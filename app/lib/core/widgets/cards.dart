import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

/// بطاقة صلبة (بدل الزجاج) — أبيض + حد + ظل ناعم
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool solid;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.solid = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: AppDecor.card(radius: radius),
        child: child,
      ),
    );
  }
}
/// غلاف التفاعل اللمسي الموحد — انضغاط فوري عند اللمس + رجوع ناعم + اهتزاز اختياري
/// (القرار: كل عنصر تفاعلي يرد خلال ≤100ms — الدراسة)
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double down;
  final bool haptic;
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.down = 0.94,
    this.haptic = false,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _d = false;
  void _set(bool v) => setState(() => _d = v);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.haptic) HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _d ? widget.down : 1,
          duration: _d
              ? const Duration(milliseconds: 90)
              : const Duration(milliseconds: 220),
          curve: _d ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}
class MoneyBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const MoneyBox({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.style(11, color: AppColors.muted)),
              Text(
                value,
                style: AppType.style(15, color: color, weight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
/// غلاف زجاجي للـ BottomSheet — المستوى المتوسط (blurLayer2) الثابت لهذا النمط.
/// القاعدة: نص القوائم يجلس على طبقات صلبة فوق الزجاج (القاعدة 3).
class GlassSheet extends StatelessWidget {
  final Widget child;
  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: AppGlass.blurMedium,
          sigmaY: AppGlass.blurMedium,
        ),
        child: ColoredBox(color: AppGlass.fillLight, child: child),
      ),
    );
  }
}
/// مودال عام
Future<dynamic> showSheet(
  BuildContext context,
  Widget child, {
  bool scroll = true,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: scroll ? SingleChildScrollView(child: child) : child,
    ),
  );
}
class IconGlass extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final double radius;
  final Color? iconColor;
  const IconGlass({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.color = AppColors.ink,
    this.radius = 12,
    this.iconColor,
  });
  @override
  State<IconGlass> createState() => _IconGlassState();
}

class _IconGlassState extends State<IconGlass> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: _pressed
              ? const Duration(milliseconds: 90)
              : const Duration(milliseconds: 220),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: AppDecor.card(radius: widget.radius),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              color: widget.iconColor ?? widget.color,
              size: widget.size * 0.45,
            ),
          ),
        ),
      ),
    );
  }
}
