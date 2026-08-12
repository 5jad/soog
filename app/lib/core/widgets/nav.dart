import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/cards.dart';
import 'package:zaboon/core/widgets/cart_animations.dart';
import 'package:zaboon/features/cart_checkout/screens/cart_screen.dart';
import 'package:zaboon/features/notifications/screens/notifications_screen.dart';

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: AppType.style(10, color: Colors.white, weight: FontWeight.w900),
      ),
    );
  }
}
/// شريط سفلي صلب (بدل الزجاج/الـ blur) — ارتفاع 64 + شارات + خط مؤشر
/// تفاعل: انضغاط فوري (0.86) + نبضة الأيقونة (1.16 بمنحنى ارتداد) + نبضة الشارة + اهتزاز لتبويب السلة
class GlassBottomNav extends StatefulWidget {
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;

  /// فهرس عنصر «السلة» — يظهر عليه عدّاد أصناف السلة فقط
  final int? badgeIndex;

  /// عدد أصناف السلة — يُعرض فوق زر السلة في الشريط
  final int badgeCount;

  /// شارات إضافية لتبويبات أخرى: الفهرس ← العدد (مثل المفضلة)
  final Map<int, int> extraBadges;
  const GlassBottomNav({
    super.key,
    required this.index,
    required this.items,
    required this.onTap,
    this.badgeIndex,
    this.badgeCount = 0,
    this.extraBadges = const {},
  });

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(widget.items.length, (i) {
              final badge = i == widget.badgeIndex
                  ? widget.badgeCount
                  : (widget.extraBadges[i] ?? 0);
              return Expanded(
                child: _NavItem(
                  icon: widget.items[i].$1,
                  label: widget.items[i].$2,
                  selected: i == widget.index,
                  badge: badge,
                  haptic: i == widget.badgeIndex,
                  onTap: () => widget.onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final bool haptic;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.haptic,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;
  bool _popped = false;

  void _tap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    setState(() => _popped = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _popped = false);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final showBadge = widget.badge > 0;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: _pressed ? 0.86 : (_popped ? 1.16 : 1.0),
                  duration: _pressed
                      ? const Duration(milliseconds: 80)
                      : const Duration(milliseconds: 260),
                  curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.selected
                          ? AppColors.primary
                          : AppColors.muted,
                      size: 24,
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -1,
                    top: -3,
                    child: AnimatedScale(
                      scale: _popped ? 1.4 : 1.0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.badge > 99 ? '99+' : '$widget.badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: AppType.style(
                10.5,
                color: widget.selected ? AppColors.primary : AppColors.muted,
                weight: widget.selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// زر السلة العائم — يظهر تلقائياً بالزاوية اليمنى السفلى بمجرد إضافة منتج،
/// ويختفي عند فراغ السلة. يوضع داخل Stack في جسم الشاشة.
/// تفاعل: انضغاط 0.9 + نبضة 1.12 + نبضة الشارة + اهتزاز
class FloatingCartFab extends StatefulWidget {
  final double bottom; // الارتفاع عن الحافة السفلى (فوق الشريط عند الحاجة)
  const FloatingCartFab({super.key, this.bottom = 88});

  @override
  State<FloatingCartFab> createState() => _FloatingCartFabState();
}

class _FloatingCartFabState extends State<FloatingCartFab> {
  bool _pressed = false;
  bool _popped = false;

  void _open() {
    HapticFeedback.lightImpact();
    setState(() => _popped = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _popped = false);
    });
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppState.i.cartCount,
      builder: (_, count, __) {
        if (count <= 0) return const SizedBox.shrink();
        return Positioned(
          right: 16,
          bottom: widget.bottom,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('fabBump$count'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, v, child) =>
                Transform.scale(scale: 1 + 0.2 * (1 - v), child: child),
            child: Listener(
              key: cartFabKey,
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: AnimatedScale(
                  scale: _pressed ? 0.9 : (_popped ? 1.12 : 1.0),
                  duration: _pressed
                      ? const Duration(milliseconds: 90)
                      : const Duration(milliseconds: 240),
                  curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                        if (count > 0)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: AnimatedScale(
                              scale: _popped ? 1.4 : 1.0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutBack,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
/// جرس الإشعارات الموحد مع عدّاد غير المقروء
class NotifBell extends StatelessWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconGlass(
          icon: Icons.notifications_none_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        Positioned(
          right: -1,
          top: -1,
          child: ValueListenableBuilder<num>(
            valueListenable: AppState.i.unreadNotifs,
            builder: (_, v, __) => CountBadge(v.toInt()),
          ),
        ),
      ],
    );
  }
}
