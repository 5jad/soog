import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'api.dart';
import 'screens/cart_screen.dart';
import 'screens/notifications_screen.dart';
import 'lottie_box.dart';

/// مفتاح زر السلة العائم — لاستهداف نقطة هبوط حركة «المنتج يطير للسلة»
final GlobalKey cartFabKey = GlobalKey();

/// هل القيمة غلاف صورة حقيقي (رابط/بايت) وليس بانر CSS قديم؟
bool isUrlCover(String v) =>
    v.startsWith('http') || v.startsWith('/uploads') || v.startsWith('data:') || v.startsWith('/9j');

/// صورة من base64 أو رابط أو إيموجي أول حرف
Widget storeLogo(String logo, {double size = 52, double radius = 14}) {
  if (logo.isEmpty) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text('🏪', style: A.t(size * 0.45)),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size, height: size,
      child: productImageBox(
        logo.startsWith('http')
            ? logo
            : logo.startsWith('/uploads')
                ? Api.base + logo
                : logo,
      ),
    ),
  );
}

Widget productImage(String? image, {double size = 80, double radius = 14}) {
  if (image != null && (image.startsWith('data:') || image.startsWith('/9j'))) {
    try {
      final bytes = base64Decode(image.replaceFirst(RegExp('^data:image/[a-z]+;base64,'), ''));
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
      );
    } catch (_) {}
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
      borderRadius: BorderRadius.circular(radius),
    ),
    alignment: Alignment.center,
    child: Text('🛍', style: A.t(size * 0.45)),
  );
}

/// صورة منتج تعبّئ مساحة الأب بالكامل (مربعة) — أسلوب Shein للبطاقات
/// يدعم: base64 / روابط رفع (/uploads) / إيموجي المنتجات
Widget productImageBox(String? image, {String? base}) {
  final url = (image ?? '').trim();
  Widget ph(String emoji) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: A.t(48)),
      );
  if (url.isEmpty) return ph('🛍');
  if (url.startsWith('data:') || url.startsWith('/9j')) {
    try {
      final bytes = base64Decode(url.replaceFirst(RegExp('^data:image/[a-z]+;base64,'), ''));
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {}
  }
  if (url.startsWith('http')) {
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph('🛍'));
  }
  if (url.startsWith('/')) {
    return Image.network('${base ?? Api.base}$url', fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph('🛍'));
  }
  return ph(url.length > 6 ? url.substring(0, 4) : url);
}

/// بطاقة صلبة (بدل الزجاج) — أبيض + حد + ظل ناعم
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool solid;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 16, this.solid = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: A.card(radius: radius),
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
  const TapScale({super.key, required this.child, this.onTap, this.down = 0.94, this.haptic = false});

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
          duration: _d ? const Duration(milliseconds: 90) : const Duration(milliseconds: 220),
          curve: _d ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// أزرار الحالة (Chip)
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor(status).withOpacity(0.35)),
      ),
      child: Text('${orderIcon(status)} ${statusAr(status)}',
          style: A.t(11, c: statusColor(status), w: FontWeight.w800)),
    );
  }
}

class MoneyBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const MoneyBox({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: A.t(11, c: A.muted)),
          Text(value, style: A.t(15, c: color, w: FontWeight.w900)),
        ]),
      ]),
    );
  }
}

/// زر كتفي صلب — ارتفاع 52 + قبعة (Capsule) + CTA البرتقالي للشراء عبر color
/// الرِبل مرئي الآن: Material بلون الزر + InkWell فوقه (سابقاً كان تحت الخلفية المطلية)
class SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;
  final Color? color;

  /// اهتزاز خفيف عند الضغط — للأزرار الحرجة فقط (إتمام/أضف للسلة) حتى لا يخزّز
  final bool haptic;
  const SolidBtn({super.key, required this.label, required this.onTap, this.loading = false, this.disabled = false, this.color, this.haptic = false});

  @override
  Widget build(BuildContext context) {
    final bg = disabled ? const Color(0xFFB9C0CC) : (color ?? A.primary);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(A.pill),
      elevation: disabled ? 0 : 5,
      shadowColor: bg.withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(A.pill),
        splashColor: Colors.white.withValues(alpha: 0.28),
        highlightColor: Colors.white.withValues(alpha: 0.14),
        onTap: (loading || disabled)
            ? null
            : () {
                if (haptic) HapticFeedback.lightImpact();
                onTap();
              },
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(label, style: A.t(15.5, c: Colors.white, w: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  final String? lottie; // مفتاح في LottieAssets — إن سُجّل يلعب بدل الإيموجي
  const EmptyState({super.key, required this.icon, required this.title, this.sub, this.action, this.onAction, this.lottie});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (lottie != null)
            LottieBox(assetKey: lottie!, width: 120, height: 120, fallback: Text(icon, style: A.t(52)))
          else
            Text(icon, style: A.t(52)),
          const SizedBox(height: 12),
          Text(title, style: A.t(17)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: A.t(12.5, c: A.muted), textAlign: TextAlign.center),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 22),
            SolidBtn(label: action!, onTap: onAction!, haptic: true),
          ],
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionTitle(this.title, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Text(title, style: A.t(16, w: FontWeight.w900)),
        const Spacer(),
        if (onMore != null)
          GestureDetector(onTap: onMore, child: Text('عرض الكل ←', style: A.t(11.5, c: A.primary))),
      ]),
    );
  }
}

class Loader extends StatelessWidget {
  const Loader({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: LottieBox(
          assetKey: 'loading',
          loop: true,
          width: 96,
          height: 96,
          fallback: const CircularProgressIndicator(color: A.primary),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: A.accent, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: A.t(10, c: Colors.white, w: FontWeight.w900)),
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
        boxShadow: [BoxShadow(color: A.ink.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(widget.items.length, (i) {
              final badge = i == widget.badgeIndex ? widget.badgeCount : (widget.extraBadges[i] ?? 0);
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
  const _NavItem({required this.icon, required this.label, required this.selected, required this.badge, required this.haptic, required this.onTap});

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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: _pressed ? 0.86 : (_popped ? 1.16 : 1.0),
                duration: _pressed ? const Duration(milliseconds: 80) : const Duration(milliseconds: 260),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.selected ? A.primary.withValues(alpha: 0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(A.r12),
                  ),
                  child: Icon(widget.icon, color: widget.selected ? A.primary : A.muted, size: 24),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                      decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                      child: Text('$widget.badge',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.label,
              style: A.t(10.5, c: widget.selected ? A.primary : A.muted, w: widget.selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: error ? A.danger : A.ink,
    duration: const Duration(seconds: 2),
  ));
}

/// تفاعل «انضاف للسلة» — بوب مركزي فوق كل شي: صغرة المنتج + اسمه +
/// علامة ✓ برتقالية تنبض، يطفو للأعلى ويتلاشى + طيران المنتج لزر السلة
void addPop(BuildContext context, String name, {String? img, String sub = 'انضاف للسلة', Offset? origin}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _AddPop(name: name, img: img, sub: sub, remove: () => entry.remove()));
  overlay.insert(entry);
  _flyToCart(overlay, img: img, origin: origin);
}

/// صورة المنتج تطير من موضع الإضافة إلى زر السلة العائم بمسار منحني
void _flyToCart(OverlayState overlay, {String? img, Offset? origin}) {
  final from = origin;
  if (from == null) return;
  final box = cartFabKey.currentContext?.findRenderObject() as RenderBox?;
  final Offset dest;
  if (box != null && box.hasSize) {
    dest = box.localToGlobal(Offset.zero) + Offset(box.size.width / 2, box.size.height / 2);
  } else {
    final size = MediaQuery.sizeOf(overlay.context);
    dest = Offset(size.width - 46, size.height - 114);
  }
  late final OverlayEntry fly;
  fly = OverlayEntry(builder: (_) => _FlyToCart(
        from: from,
        to: dest,
        img: img,
        remove: () => fly.remove(),
        onDone: () => _burstAtCart(overlay, dest),
      ));
  overlay.insert(fly);
}

/// لحظة هبوط المنتج — انفجار Lottie حول زر السلة
void _burstAtCart(OverlayState overlay, Offset dest) {
  late final OverlayEntry e;
  e = OverlayEntry(builder: (_) => IgnorePointer(
        child: Positioned(
          left: dest.dx - 58,
          top: dest.dy - 58,
          child: LottieBox(assetKey: 'cart_ok', width: 116, height: 116, fallback: const SizedBox.shrink()),
        ),
      ));
  overlay.insert(e);
  Future.delayed(const Duration(milliseconds: 2300), () => e.remove());
}

class _FlyToCart extends StatefulWidget {
  final Offset from;
  final Offset to;
  final String? img;
  final VoidCallback remove;
  final VoidCallback onDone;
  const _FlyToCart({required this.from, required this.to, this.img, required this.remove, required this.onDone});

  @override
  State<_FlyToCart> createState() => _FlyToCartState();
}

class _FlyToCartState extends State<_FlyToCart> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeInCubic);

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
        child: Transform.scale(scale: 1 - 0.45 * _t.value, child: productImage(widget.img, size: 44, radius: 14)),
      ),
    );
  }
}

class _AddPop extends StatefulWidget {
  final String name;
  final String? img;
  final String sub;
  final VoidCallback remove;
  const _AddPop({required this.name, this.img, required this.sub, required this.remove});
  @override
  State<_AddPop> createState() => _AddPopState();
}

class _AddPopState extends State<_AddPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.22, curve: Curves.easeOutBack));
  late final Animation<double> _op =
      CurvedAnimation(parent: _c, curve: const Interval(0.25, 1, curve: Curves.easeIn));
  late final Animation<double> _up =
      Tween(begin: 0.0, end: -16.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.25, 1, curve: Curves.easeIn)));

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
              builder: (_, child) => Transform.translate(offset: Offset(0, _up.value), child: child),
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: A.ink.withValues(alpha: 0.14), blurRadius: 26, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      productImage(widget.img, size: 44, radius: 12),
                      Positioned(
                        left: -5,
                        bottom: -5,
                        child: LottieBox(
                          assetKey: 'cart_ok',
                          width: 30,
                          height: 30,
                          fallback: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.name,
                          style: A.t(12.5, w: FontWeight.w800, c: A.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(widget.sub, style: A.t(10.5, c: A.muted, w: FontWeight.w600)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// مودال عام
Future<dynamic> showSheet(BuildContext context, Widget child, {bool scroll = true}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: scroll ? SingleChildScrollView(child: child) : child,
    ),
  );
}

class SheetTitle extends StatelessWidget {
  final String title;
  const SheetTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(children: [
        Text(title, style: A.t(17, w: FontWeight.w900)),
        const Spacer(),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: A.muted)),
      ]),
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
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
            builder: (_, v, child) => Transform.scale(scale: 1 + 0.2 * (1 - v), child: child),
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
                duration: _pressed ? const Duration(milliseconds: 90) : const Duration(milliseconds: 240),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    color: A.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: A.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  width: 60,
                  height: 60,
                  child: Stack(alignment: Alignment.center, children: [
                    const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 27),
                    if (count > 0)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: AnimatedScale(
                          scale: _popped ? 1.4 : 1.0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                  ]),
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

/// ← شاشة قصّ الصورة (بدون مكتبات إضافية — يعمل بجميع الأجهزة)
/// إطار ثابت حسب النسبة (مربع/بانر) مع تحريك + تقريب/تبعيد، ويقصّ الإطار تماماً
/// تُرجع البايتات المقصوصة أو null عند الإلغاء
Future<Uint8List?> cropImage(BuildContext context, Uint8List bytes, {double aspect = 1, String title = 'قصّ الصورة ✂️'}) async {
  return await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(builder: (_) => CropScreen(bytes: bytes, aspectRatio: aspect, title: title)),
  );
}

/// قماش قصّ المرسوم يدوياً: الصورة داخل الإطار + تعتيم الخارج + شبكة الأثلاث
class _CropPainter extends CustomPainter {
  final ui.Image img;
  final Rect frame;
  final double scale;
  final Offset draw;
  final double outK;
  final void Function(Rect src, int outW, int outH) onRegion;
  _CropPainter({required this.img, required this.frame, required this.scale, required this.draw, required this.outK, required this.onRegion});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      ((frame.left - draw.dx) / scale).clamp(0, img.width.toDouble()),
      ((frame.top - draw.dy) / scale).clamp(0, img.height.toDouble()),
      (frame.width / scale).clamp(1, img.width.toDouble()),
      (frame.height / scale).clamp(1, img.height.toDouble()),
    );
    onRegion(src, (frame.width * outK).round(), (frame.height * outK).round());

    // الصورة نفسها — مقصوصة على الإطار
    canvas.save();
    canvas.clipRect(frame);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(draw.dx, draw.dy, img.width * scale, img.height * scale),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();

    // تعتيم خارج الإطار
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(10)));
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.62));

    // حدّ الإطار
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(10));
    canvas.drawRRect(rrect, border);

    // شبكة الأثلاث
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.35);
    for (final t in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(frame.left + frame.width * t, frame.top), Offset(frame.left + frame.width * t, frame.bottom), grid);
      canvas.drawLine(Offset(frame.left, frame.top + frame.height * t), Offset(frame.right, frame.top + frame.height * t), grid);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.img != img || old.frame != frame || old.scale != scale || old.draw != draw;
}

class CropScreen extends StatefulWidget {
  final Uint8List bytes;
  final double aspectRatio; // نسبة العرض للطول (1 = مربع، 16/9 = بانر)
  final String title;
  const CropScreen({super.key, required this.bytes, this.aspectRatio = 1, this.title = 'قصّ الصورة ✂️'});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _img;
  bool _loaded = false;
  double _scale = 1; // تكبير البداية = يغطر الإطار بالكامل
  Offset _pan = Offset.zero;
  double _startScale = 1;
  double _outK = 2; // دقة الحفظ (أضعاف مقاس الإطار)
  Rect _lastSrc = Rect.zero;
  Size _lastOut = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final comp = await ui.instantiateImageCodec(widget.bytes);
      final frame = await comp.getNextFrame();
      setState(() { _img = frame.image; _loaded = true; });
    } catch (_) {}
  }

  /// إطار القصّ: نسبة ثابتة، موسّط بحدود الشاشة
  Rect _frame(Size view) {
    final pad = 18.0;
    var w = view.width - pad * 2;
    var h = w / widget.aspectRatio;
    if (h > view.height - pad * 2) {
      h = view.height - pad * 2;
      w = h * widget.aspectRatio;
    }
    return Rect.fromCenter(center: Offset(view.width / 2, view.height / 2), width: w, height: h);
  }

  Future<Uint8List?> _save() async {
    final img = _img!;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(
      img,
      _lastSrc,
      Rect.fromLTWH(0, 0, _lastOut.width, _lastOut.height),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = rec.endRecording();
    final bi = await picture.toImage(_lastOut.width.toInt(), _lastOut.height.toInt());
    final by = await bi.toByteData(format: ui.ImageByteFormat.png);
    return by?.buffer.asUint8List();
  }

  void _clampPan(Size view) {
    final img = _img!;
    final frame = _frame(view);
    final base = math.max(frame.width / img.width, frame.height / img.height);
    final s = base * _scale;
    final dw = img.width * s, dh = img.height * s;
    final maxX = math.max(0.0, (dw - frame.width) / 2), maxY = math.max(0.0, (dh - frame.height) / 2);
    _pan = Offset(_pan.dx.clamp(-maxX, maxX), _pan.dy.clamp(-maxY, maxY));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title)),
      body: Stack(children: [
        if (!_loaded)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          LayoutBuilder(builder: (_, cons) {
            final view = Size(cons.maxWidth, cons.maxHeight);
            final img = _img!;
            final frame = _frame(view);
            final base = math.max(frame.width / img.width, frame.height / img.height);
            final s = base * _scale;
            final dx = frame.center.dx - (img.width * s) / 2 + _pan.dx;
            final dy = frame.center.dy - (img.height * s) / 2 + _pan.dy;
            return Column(children: [
              Expanded(
                child: GestureDetector(
                  onScaleStart: (d) { _startScale = _scale; },
                  onScaleUpdate: (d) {
                    setState(() {
                      _scale = (_startScale * d.scale).clamp(1.0, 5.0);
                      _pan += Offset(d.focalPointDelta.dx, d.focalPointDelta.dy);
                    });
                  },
                  onScaleEnd: (_) => setState(() => _clampPan(view)),
                  onDoubleTap: () => setState(() {
                    _scale = _scale > 1.4 ? 1 : 2.5;
                    _clampPan(view);
                  }),
                  child: CustomPaint(
                    size: view,
                    painter: _CropPainter(
                      img: img,
                      frame: frame,
                      scale: s,
                      draw: Offset(dx, dy),
                      outK: _outK,
                      onRegion: (src, ow, oh) { _lastSrc = src; _lastOut = Size(ow.toDouble(), oh.toDouble()); },
                    ),
                  ),
                ),
              ),
              SafeArea(top: false, child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    onPressed: () => setState(() { _scale = 1; _pan = Offset.zero; }),
                    child: const Text('إعادة'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () => setState(() { _scale = (_scale * 0.78).clamp(1.0, 5.0); _clampPan(view); }),
                    icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                    tooltip: 'تصغير',
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() { _scale = (_scale * 1.28).clamp(1.0, 5.0); _clampPan(view); }),
                    icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                    tooltip: 'تقريب',
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final out = await _save();
                      if (out != null && mounted) Navigator.pop(context, out);
                    },
                    child: const Text('قصّ ✓'),
                  ),
                ]),
              )),
            ]);
          }),
      ]),
    );
  }
}

/// الشعار الموحد: مربع كحلي بأيقونة سلة + نقطة برتقالية (نقطة «الزاي» — توقيع الهوية) + «زبون»
class TopBarPill extends StatelessWidget {
  const TopBarPill({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: A.gradNavy,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: A.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          const Center(child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white)),
          // نقطة «الزاي» البرتقالية — توقيع الهوية (نقطة واحدة فوق حرف ز)
          Positioned(
            left: 5,
            top: 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 9),
      Text('زبون',
          style: A.t(20, c: A.ink, w: FontWeight.w700).copyWith(fontFamily: 'ElMessiri')),
    ]);
  }
}

/// جرس الإشعارات الموحد مع عدّاد غير المقروء
class NotifBell extends StatelessWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconGlass(
        icon: Icons.notifications_none_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      Positioned(
        right: -1,
        top: -1,
        child: ValueListenableBuilder<num>(
          valueListenable: AppState.i.unreadNotifs,
          builder: (_, v, __) => CountBadge(v.toInt()),
        ),
      ),
    ]);
  }
}

/* ═══════════ نظام تحديث النسخ — الشريط يفتح تحميل النسخة الأحدث من الموقع ═══════════ */
/// نسخة التطبيق الحالية (مطابقة app-version.json على السيرفر)
const String kAppVersion = '1.0.0';
const int kAppBuild = 23;

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? latest;
  String? url;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final d = await Api.get('/api/app/version');
      final v = (d['version'] ?? '').toString();
      final b = (d['build'] as num?)?.toInt() ?? 0;
      if ((v.isNotEmpty && v != kAppVersion) || b > kAppBuild) {
        setState(() {
          latest = v;
          url = Api.base + (d['download_url'] ?? '/download');
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final v = latest;
    if (v == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: A.gradNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: A.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Text('📦', style: A.t(24)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('نسخة جديدة متوفرة ($v)', style: A.t(13, c: Colors.white, w: FontWeight.w900)),
            Text('حمّلها من موقعنا — أحدث إصدار دائماً', style: A.t(10.5, c: Colors.white.withOpacity(0.9))),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final u = url;
            if (u != null) await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text('حمّل', style: A.t(12.5, c: A.accentDeep, w: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }
}
