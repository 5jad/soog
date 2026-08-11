import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// هوية «زبون» v2 — النظام التصميمي المثبت من الدراسة
/// (كحلي ليلي + برتقالي CTA وحيد + محايدات دافئة + شبكة 8pt + Tajawal)
/// ═══════════════════════════════════════════════════════════════
class A {
  /* ── الألوان (قاعدة 60-30-10) ── */
  static const primary = Color(0xFF12294E); // كحلي ليلي — الأساسي الوحيد
  static const primaryDeep = Color(0xFF0B1B36); // كحلي أعمق — تدرجات/حالات مضغوطة
  static const primaryLight = Color(0xFF4A6FA5); // كحلي فاتح — ثانوي محايد
  static const accent = Color(0xFFF2560F); // برتقالي شمسي — CTA الشراء الحصري
  static const accentDeep = Color(0xFFC2410C); // برتقالي غامق — ضغوط التدريب
  static const cyan = Color(0xFF1789A6); // سماوي هادئ — حالات «جاهز»

  static const ink = Color(0xFF171D26); // نص أساسي (بدل الأسود الصافي)
  static const bg = Color(0xFFFAFAF7); // خلفية دافئة فاتحة
  static const surface = Color(0xFFFFFFFF); // أسطح البطاقات
  static const text = Color(0xFF171D26);
  static const muted = Color(0xFF5C6570);
  static const line = Color(0xFFE7E9EC);
  static const success = Color(0xFF1F9D55);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFD92D20);
  static const info = Color(0xFF0284C7);
  static const star = Color(0xFFF5A623);
  static const white = Colors.white;

  /* ── شبكة المسافات الثابتة (8pt — القيم الحصرية للنظام) ── */
  static const double s4 = 4, s8 = 8, s12 = 12, s16 = 16, s20 = 20;
  static const double s24 = 24, s32 = 32, s40 = 40, s48 = 48, s64 = 64, s96 = 96;

  /* ── الزوايا (Concentric على 8pt) ── */
  static const double r12 = 12; // شارات/حقول داخلية
  static const double r16 = 16; // بطاقات
  static const double r20 = 20; // بطاقات كبيرة/شيتات
  static const double pill = 999; // أزرار CTA قبعة

  /* ── تدرجات ممنوعة يومياً — للأحداث والإعلانات فقط ── */
  static const gradNavy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );
  static const gradSun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFF97316)],
  );
  static const gradSky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, Color(0xFF7FA3CC)],
  );

  /// بطاقة صلبة (بدل الزجاج) — الخلفية الثابتة المختارة: أبيض + حد + ظل ناعم
  static BoxDecoration card({
    double radius = r16,
    Color? color,
    bool raised = false,
    Color? border,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? line, width: 1),
      boxShadow: raised
          ? [
              BoxShadow(
                color: primary.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  /// زجاج خفيف مخصص للشيتات/الأعلى فقط — لا يُستخدم للبطاقات اليومية
  static BoxDecoration glass({double radius = 20, Color? tint, bool soft = false, bool dark = false}) {
    final t = tint ?? (soft ? bg : white);
    return BoxDecoration(
      color: t.withOpacity(0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: dark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.45), width: 1),
      boxShadow: soft
          ? []
          : [
              BoxShadow(
                color: primary.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  static BoxDecoration glassSolid({double radius = 20}) {
    return BoxDecoration(
      color: const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: line, width: 1),
    );
  }

  static TextStyle t(double s, {Color? c, FontWeight w = FontWeight.w700, double h = 1.25, TextDecoration? decoration}) =>
      TextStyle(fontSize: s, color: c ?? text, fontWeight: w, height: h, decoration: decoration);
}

/// زر دائري/مربع بأيقونة صلبة (بدل الزجاج) — هدف لمس ≥40
class IconGlass extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final double radius;
  const IconGlass({super.key, required this.icon, this.onTap, this.size = 40, this.color = A.text, this.radius = 12, this.iconColor});
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: A.card(radius: radius),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor ?? color, size: size * 0.45),
      ),
    );
  }
}

/// شريحة (chip) صلبة للفئات — نشطة: كحلي، غير نشطة: أبيض بحد
class ChipG extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final String? icon;
  const ChipG({super.key, required this.label, this.active = false, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? A.primary : A.surface,
          borderRadius: BorderRadius.circular(A.pill),
          border: Border.all(color: active ? A.primary : A.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 12)), const SizedBox(width: 6)],
            Text(
              label,
              style: A.t(13, c: active ? Colors.white : A.text, w: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط بحث صلب (ارتفاع 48 — ضمن القياس الثابت)
class SearchGlass extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;
  const SearchGlass({super.key, required this.onTap, required this.hint});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: A.card(radius: A.r16),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: A.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(hint, style: A.t(14, c: A.muted, w: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة حالة مصغرة (نقطة + نص)
class DotChip extends StatelessWidget {
  final String label;
  final Color color;
  const DotChip({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(A.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

/// شارة موثق
class VerifiedTag extends StatelessWidget {
  final bool verified;
  const VerifiedTag({super.key, this.verified = true});
  @override
  Widget build(BuildContext context) {
    if (!verified) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(color: A.success, borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 3),
        const Text('موثق', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: A.success)),
      ],
    );
  }
}

/// شارة نجم
class StarsTag extends StatelessWidget {
  final double rating;
  const StarsTag({super.key, this.rating = 0});
  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 13, color: A.star),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: A.muted)),
      ],
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: A.primary,
      primary: A.primary,
      surface: A.bg,
    ),
    scaffoldBackgroundColor: A.bg,
    fontFamily: 'Tajawal',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: A.ink),
      titleTextStyle: TextStyle(color: A.ink, fontWeight: FontWeight.w700, fontSize: 17),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: A.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(A.r16),
        borderSide: const BorderSide(color: A.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(A.r16),
        borderSide: const BorderSide(color: A.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(A.r16),
        borderSide: const BorderSide(color: A.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: A.primaryDeep,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(A.pill)),
        elevation: 0,
        shadowColor: A.primary.withOpacity(0.2),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: A.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: A.primaryDeep,
      side: const BorderSide(color: A.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(A.r12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: A.text),
    ),
    dividerColor: A.line,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: A.ink,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(A.r20))),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: A.primary,
      unselectedItemColor: A.muted,
      elevation: 8,
    ),
  );
  return base;
}

/// إيموجي حسب حالة الطلب
String orderIcon(String status) {
  switch (status) {
    case 'pending': return '🕐';
    case 'accepted': return '✅';
    case 'ready': return '🎒';
    case 'picked': return '🛵';
    case 'delivered': return '📦';
    case 'cancelled': return '🚫';
    case 'returned': return '↩️';
    default: return '🕐';
  }
}

/// تسمية عربية حسب الحالة
String statusAr(String status) {
  switch (status) {
    case 'new': return 'طلب جديد 🆕';
    case 'pending': return 'قيد الانتظار';
    case 'accepted': return 'مقبول';
    case 'preparing': return 'قيد التجهيز';
    case 'ready': return 'جاهز للاستلام';
    case 'picked': return 'بالتوصيل';
    case 'delivering': return 'بالتوصيل';
    case 'delivered': return 'تم التوصيل';
    case 'cancelled': return 'ملغي';
    case 'returned': return 'مرتجع';
    case 'online': return 'متصل';
    case 'offline': return 'غير متصل';
    default: return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'new': return A.warning;
    case 'pending': return A.warning;
    case 'accepted': return A.primary;
    case 'preparing': return A.primary;
    case 'ready': return A.cyan;
    case 'picked': return A.primaryLight;
    case 'delivering': return A.primaryLight;
    case 'delivered': return A.success;
    case 'cancelled': return A.danger;
    case 'returned': return A.muted;
    default: return A.muted;
  }
}

/// تنسيق المبالغ: 1,234 د.ع
String money(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf د.ع';
}

/// وقت نسبي بالعربي
String timeAgo(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
  return '${dt.day}/${dt.month}/${dt.year}';
}