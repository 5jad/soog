import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/images.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';

/// مفتاح زر السلة العائم — لاستهداف نقطة هبوط حركة «المنتج يطير للسلة»
final GlobalKey cartFabKey = GlobalKey();
void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? AppColors.danger : AppColors.ink,
      duration: const Duration(seconds: 2),
    ),
  );
}
/// تفاعل «انضاف للسلة» — بوب مركزي فوق كل شي: صغرة المنتج + اسمه +
/// علامة ✓ برتقالية تنبض، يطفو للأعلى ويتلاشى + طيران المنتج لزر السلة
void addPop(
  BuildContext context,
  String name, {
  String? img,
  String sub = 'انضاف للسلة',
  Offset? origin,
}) {
  toast(context, 'تمت الإضافة للسلة 🛍️');
  if (origin != null) {
    _flyToCart(Overlay.of(context), img: img, origin: origin);
  }
}
/// صورة المنتج تطير من موضع الإضافة إلى زر السلة العائم بمسار منحني
void _flyToCart(OverlayState overlay, {String? img, Offset? origin}) {
  final from = origin;
  if (from == null) return;
  final box = cartFabKey.currentContext?.findRenderObject() as RenderBox?;
  final Offset dest;
  if (box != null && box.hasSize) {
    dest =
        box.localToGlobal(Offset.zero) +
        Offset(box.size.width / 2, box.size.height / 2);
  } else {
    final size = MediaQuery.sizeOf(overlay.context);
    dest = Offset(size.width - 46, size.height - 114);
  }
  late final OverlayEntry fly;
  fly = OverlayEntry(
    builder: (_) => _FlyToCart(
      from: from,
      to: dest,
      img: img,
      remove: () => fly.remove(),
      onDone: () => _burstAtCart(overlay, dest),
    ),
  );
  overlay.insert(fly);
}
/// لحظة هبوط المنتج — انفجار Lottie حول زر السلة
void _burstAtCart(OverlayState overlay, Offset dest) {
  late final OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Positioned(
        left: dest.dx - 58,
        top: dest.dy - 58,
        child: LottieBox(
          assetKey: 'cart_confirm', // نبضة تأكيد السلة — once
          loop: false,
          width: 116,
          height: 116,
          fallback: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  overlay.insert(e);
  Future.delayed(const Duration(milliseconds: 2300), () => e.remove());
}
class _FlyToCart extends StatefulWidget {
  final Offset from;
  final Offset to;
  final String? img;
  final VoidCallback remove;
  final VoidCallback onDone;
  const _FlyToCart({
    required this.from,
    required this.to,
    this.img,
    required this.remove,
    required this.onDone,
  });

  @override
  State<_FlyToCart> createState() => _FlyToCartState();
}

class _FlyToCartState extends State<_FlyToCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().then((_) {
      widget.remove();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _quad(Offset a, Offset c, Offset b, double t) {
    final mt = 1 - t;
    return a * (mt * mt) + c * (2 * mt * t) + b * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t.value;
    final mid = Offset(
      (widget.from.dx + widget.to.dx) / 2,
      math.min(widget.from.dy, widget.to.dy) - 120,
    );
    final pos = _quad(widget.from, mid, widget.to, t);
    return Positioned(
      left: pos.dx - 22,
      top: pos.dy - 22,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 - 0.45 * _t.value,
          child: productImage(widget.img, size: 44, radius: 14),
        ),
      ),
    );
  }
}
class _AddPop extends StatefulWidget {
  final String name;
  final String? img;
  final String sub;
  final VoidCallback remove;
  const _AddPop({
    required this.name,
    this.img,
    required this.sub,
    required this.remove,
  });
  @override
  State<_AddPop> createState() => _AddPopState();
}

class _AddPopState extends State<_AddPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.22, curve: Curves.easeOutBack),
  );
  late final Animation<double> _op = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 1, curve: Curves.easeIn),
  );
  late final Animation<double> _up = Tween(begin: 0.0, end: -16.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 1, curve: Curves.easeIn),
    ),
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _c.forward().then((_) {
      if (mounted) widget.remove();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _op,
            child: AnimatedBuilder(
              animation: _up,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _up.value),
                child: child,
              ),
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          productImage(widget.img, size: 44, radius: 12),
                          Positioned(
                            left: -5,
                            bottom: -5,
                            child: LottieBox(
                              assetKey:
                                  'cart_confirm', // نبضة تأكيد الإضافة — once
                              loop: false,
                              width: 30,
                              height: 30,
                              fallback: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.name,
                            style: AppType.style(
                              12.5,
                              weight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.sub,
                            style: AppType.style(
                              10.5,
                              color: AppColors.muted,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
