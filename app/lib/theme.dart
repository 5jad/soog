import 'package:flutter/material.dart';

/// هوية «أفق» — الألوان الرسمية للمنصة (مطابقة لتصميم الـ demo)
class A {
  static const primary = Color(0xFF1D4ED8); // أزرق داكن (محيط)
  static const primaryDeep = Color(0xFF1E3A8A); // أزرق أعمق
  static const primaryLight = Color(0xFF38BDF8); // أزرق سماوي
  static const cyan = Color(0xFF06B6D4);
  static const accent = Color(0xFFF97316); // برتقالي شمسي
  static const accentDeep = Color(0xFFEA580C);
  static const ink = Color(0xFF0A1120);
  static const bg = Color(0xFFFAF9F6); // خلفية دافئة فاتحة
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF475467);
  static const line = Color(0xFFE4E7EC);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);
  static const star = Color(0xFFF5A623);
  static const white = Colors.white;

  static const gradNavy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );
  static const gradSun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFFB923C)],
  );
  static const gradSky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, cyan],
  );

  /// زجاج «المال صلب، الجمال زجاج» — روّق شفاف مثل الديمو
  static BoxDecoration glass({double radius = 20, Color? tint, bool soft = false, bool dark = false}) {
    final t = tint ?? (soft ? A.bg : A.white);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          t.withOpacity(soft ? 0.55 : 0.62),
          t.withOpacity(soft ? 0.4 : 0.74),
        ],
      ),
      border: Border.all(
        color: dark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.45),
        width: 1,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: soft
          ? []
          : [
              BoxShadow(
                color: A.primary.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  static BoxDecoration glassSolid({double radius = 20}) {
    return BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)]),
      border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.1),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static TextStyle t(double s, {Color? c, FontWeight w = FontWeight.w700, double h = 1.25, TextDecoration? decoration}) =>
      TextStyle(fontSize: s, color: c ?? text, fontWeight: w, height: h, decoration: decoration);
}

/// زر زجاجي دائري / مربع بأيقونة (icon-button مثل الديمو)
class IconGlass extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final double radius;
  const IconGlass({super.key, required this.icon, this.onTap, this.size = 40, this.color = A.text, this.radius = 14, this.iconColor});
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: A.glass(radius: radius, soft: true),
        child: Icon(icon, color: iconColor ?? color, size: size * 0.45),
      ),
    );
  }
}

/// شريحة (chip) زجاجية للفئات والأزرار المصغرة
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: active
            ? BoxDecoration(
                gradient: A.gradNavy,
                borderRadius: BorderRadius.circular(999),
              )
            : A.glass(radius: 999, soft: true),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 12)), const SizedBox(width: 4)],
            Text(
              label,
              style: A.t(12, c: active ? Colors.white : A.muted, w: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط بحث زجاجي (غير قابل للكتابة إلا عبر callback)
class SearchGlass extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;
  const SearchGlass({super.key, required this.onTap, required this.hint});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: A.glass(radius: 16, soft: false),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: A.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(hint, style: A.t(12.5, c: A.muted, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.85)]),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
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
          width: 13, height: 13,
          decoration: BoxDecoration(color: A.success, borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 2),
        const Text('موثق', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: A.success)),
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
        const Icon(Icons.star_rounded, size: 12, color: A.star),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: A.muted)),
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
    fontFamily: 'default',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: A.ink),
      titleTextStyle: TextStyle(color: A.ink, fontWeight: FontWeight.w900, fontSize: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: A.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: A.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: A.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: A.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: A.primaryDeep,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: A.primary.withOpacity(0.4),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: A.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: A.primaryDeep,
      side: const BorderSide(color: A.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: A.text),
    ),
    dividerColor: A.line,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: A.ink,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: A.primary,
      unselectedItemColor: A.muted,
      elevation: 14,
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