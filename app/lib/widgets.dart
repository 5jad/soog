import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'api.dart';
import 'screens/cart_screen.dart';
import 'screens/notifications_screen.dart';

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
class SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;
  final Color? color;
  const SolidBtn({super.key, required this.label, required this.onTap, this.loading = false, this.disabled = false, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = disabled ? const Color(0xFFB9C0CC) : (color ?? A.primary);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(A.pill),
        boxShadow: disabled
            ? const []
            : [
                BoxShadow(color: bg.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(A.pill),
          onTap: (loading || disabled) ? null : onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
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
  const EmptyState({super.key, required this.icon, required this.title, this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: A.t(52)),
        const SizedBox(height: 12),
        Text(title, style: A.t(17)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!, style: A.t(12.5, c: A.muted)),
        ],
      ]),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: A.primary),
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
class GlassBottomNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: A.line, width: 1)),
        boxShadow: [BoxShadow(color: A.ink.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == index;
              final badge = i == badgeIndex ? badgeCount : (extraBadges[i] ?? 0);
              final showBadge = badge > 0;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? A.primary.withOpacity(0.10) : Colors.transparent,
                            borderRadius: BorderRadius.circular(A.r12),
                          ),
                          child: Icon(items[i].$1,
                              color: selected ? A.primary : A.muted, size: 24),
                        ),
                        if (showBadge)
                          Positioned(
                            right: -1,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                              decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                              child: Text('$badge',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(items[i].$2,
                        style: A.t(10.5, c: selected ? A.primary : A.muted, w: selected ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }),
          ),
        ),
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
class FloatingCartFab extends StatelessWidget {
  final double bottom; // الارتفاع عن الحافة السفلى (فوق الشريط عند الحاجة)
  const FloatingCartFab({super.key, this.bottom = 88});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppState.i.cartCount,
      builder: (_, count, __) {
        if (count <= 0) return const SizedBox.shrink();
        return Positioned(
          right: 16,
          bottom: bottom,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                // فتح السلة
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: A.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: A.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                width: 60,
                height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 27),
                  if (count > 0)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
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

/// الشريط العلوي الموحد: واسط·الكوت + عدد المتاجر (يظهر بكل الصفحات)
class TopBarPill extends StatelessWidget {
  const TopBarPill({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: A.card(radius: A.pill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_on_rounded, color: A.primary, size: 15),
          const SizedBox(width: 5),
          Text('واسط · الكوت', style: A.t(12.5, c: A.primary, w: FontWeight.w700)),
        ]),
      ),
      const SizedBox(width: 8),
      ValueListenableBuilder<num>(
        valueListenable: AppState.i.storesCount,
        builder: (_, v, __) => Text('${v.toInt()} متجر متاح', style: A.t(11, c: A.muted, w: FontWeight.w500)),
      ),
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
const int kAppBuild = 5;

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
        gradient: A.gradSun,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: A.accent.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
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
