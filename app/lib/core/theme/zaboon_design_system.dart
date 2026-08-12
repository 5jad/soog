// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ZABOON DESIGN SYSTEM v4 — Single Source of Truth
//  التعريف:   كل قيمة في التطبيق تُعرَّف هنا مرة واحدة فقط.
//  القواعد:   Golden Ratio (φ=1.618) · 4pt Grid · WCAG AA · Apple HIG
//  الاستخدام: import 'package:zaboon/core/theme/zaboon_design_system.dart';
// ═══════════════════════════════════════════════════════════════════════════

// ─── الثوابت الرياضية ─────────────────────────────────────────────────────
const double _phi = 1.618033988749895; // Golden Ratio
const double _base = 4.0; // 4pt Grid

// ─────────────────────────────────────────────────────────────────────────────
// 1. COLORS — نظام الألوان
//    القاعدة: 60٪ Primary · 30٪ Neutral · 10٪ Accent
//    الضمان: WCAG AA على خلفية AppColors.bg
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Primary (60%) — الكحلي الداكن ──────────────────────────────────────
  static const Color primary      = Color(0xFF12294E); // الرئيسي
  static const Color primaryDeep  = Color(0xFF0B1B36); // أعمق (Headers)
  static const Color primaryLight = Color(0xFF4A6FA5); // فاتح (Links)

  // ── Accent / CTA (10%) — البرتقالي الحصري ─────────────────────────────
  static const Color accent     = Color(0xFFF2560F); // أزرار الشراء الرئيسية
  static const Color accentDeep = Color(0xFFC2410C); // للنص على خلفية فاتحة

  // ── Neutral (30%) ──────────────────────────────────────────────────────
  static const Color ink     = Color(0xFF171D26); // نص أساسي
  static const Color bg      = Color(0xFFFAFAF7); // خلفية دافئة
  static const Color surface = Color(0xFFFFFFFF); // بطاقات
  static const Color muted   = Color(0xFF5C6570); // نص ثانوي
  static const Color line    = Color(0xFFE7E9EC); // حدود

  // ── Semantic — ألوان الحالات ────────────────────────────────────────────
  static const Color success = Color(0xFF1F9D55); // ناجح / كاش عند الاستلام
  static const Color warning = Color(0xFFB45309); // تحذير
  static const Color danger  = Color(0xFFD92D20); // خطأ / حذف
  static const Color info    = Color(0xFF0284C7); // معلومات
  static const Color star    = Color(0xFFF5A623); // تقييم النجوم
  static const Color cyan    = Color(0xFF1789A6); // جاهز للتوصيل

  // ── Gradients — للعناوين والبانرات فقط ────────────────────────────────
  static const Gradient gradNavy = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );
  static const Gradient gradSun = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accent, Color(0xFFF97316)],
  );
  static const Gradient gradSky = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primaryLight, Color(0xFF7FA3CC)],
  );
  static const Gradient gradSuccess = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [success, Color(0xFF15803D)],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. METRICS — القياسات والمسافات (4pt Grid × Golden Ratio)
// ─────────────────────────────────────────────────────────────────────────────
class AppMetrics {
  AppMetrics._();

  // ── Spacing Scale ──────────────────────────────────────────────────────
  static const double xxs  = _base * 1;   // 4
  static const double xs   = _base * 2;   // 8
  static const double sm   = _base * 3;   // 12
  static const double md   = _base * 4;   // 16
  static const double lg   = _base * 7;   // 28 ≈ md × φ
  static const double xl   = _base * 11;  // 44 ≈ lg × φ
  static const double xxl  = _base * 18;  // 72 ≈ xl × φ
  static const double xxxl = _base * 29;  // 116 ≈ xxl × φ

  // ── Touch Targets (Apple HIG: min 44pt) ────────────────────────────────
  static const double hitMin      = 44;
  static const double buttonH     = 52; // CTA الرئيسي
  static const double buttonHSm   = 44; // زر ثانوي
  static const double inputH      = 48;

  // ── Layout ────────────────────────────────────────────────────────────
  static const double navBarH     = 64;
  static const double appBarH     = 56;
  static const double tabBarH     = 48;
  static const double fabSize     = 52;
  static const double pageH       = 16; // padding أفقي للصفحات
  static const double cardPad     = 14;

  // ── Aspect Ratios (Golden) ────────────────────────────────────────────
  static const double ratioSquare    = 1.0;
  static const double ratioPortrait  = 0.618; // 1:φ — بطاقة المنتج
  static const double ratioLandscape = 1.618; // φ:1 — بطاقة المتجر
  static const double ratioBanner    = 2.618; // φ²:1 — البانر الرئيسي
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. RADIUS — زوايا الحواف (تصاعدية ذهبية)
// ─────────────────────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double xs   = 4;
  static const double sm   = 6;   // أيقونات
  static const double md   = 10;  // Chips
  static const double lg   = 16;  // بطاقات عادية
  static const double xl   = 26;  // Bottom sheets
  static const double xxl  = 32;  // Modals
  static const double pill = 999; // أزرار CTA

  // ── Aliases ───────────────────────────────────────────────────────────
  static const double card  = 20;
  static const double sheet = xl;
  static const double chip  = md;
  static const double input = lg;
  static const double btn   = pill;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. TYPOGRAPHY — نظام الطباعة
//    الخطوط: IBM Plex Sans Arabic (واجهة) · El Messiri (هوية)
//    Line Height: 1.4 للعربية (WCAG: min 1.5 for body)
// ─────────────────────────────────────────────────────────────────────────────
class AppType {
  AppType._();

  static const String fontUI    = 'IBMPlexSansArabic';
  static const String fontBrand = 'ElMessiri';

  // ── Size Scale (Base 14pt × φ) ────────────────────────────────────────
  static const double micro  = 10.0;
  static const double small  = 12.0;
  static const double body   = 14.0;
  static const double h3     = 16.0;
  static const double h2     = 22.0;
  static const double h1     = 28.0;
  static const double hero   = 36.0;

  // ── الدالة الموحدة ────────────────────────────────────────────────────
  static TextStyle style(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
    String? fontFamily,
    TextDecoration? decoration,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        color: color ?? AppColors.ink,
        fontWeight: weight,
        height: height ?? (size >= h2 ? 1.4 : 1.3),
        fontFamily: fontFamily ?? fontUI,
        decoration: decoration,
        letterSpacing: letterSpacing,
      );

  // ── Presets ───────────────────────────────────────────────────────────
  static TextStyle get heroStyle =>
      style(hero, weight: FontWeight.w800, fontFamily: fontBrand);
  static TextStyle get h1Style  => style(h1,  weight: FontWeight.w800);
  static TextStyle get h2Style  => style(h2,  weight: FontWeight.w700);
  static TextStyle get h3Style  => style(h3,  weight: FontWeight.w700);
  static TextStyle get bodyStyle => style(body, weight: FontWeight.w500);
  static TextStyle get smallStyle =>
      style(small, weight: FontWeight.w500, color: AppColors.muted);
  static TextStyle get microStyle =>
      style(micro, weight: FontWeight.w600, color: AppColors.muted);

  // ── Price — السعر أكبر وأعرض دائماً ────────────────────────────────
  static TextStyle priceStyle({double size = h2, Color? color}) =>
      style(size, weight: FontWeight.w900, color: color ?? AppColors.ink);
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. ICONS — أحجام الأيقونات
// ─────────────────────────────────────────────────────────────────────────────
class AppIcons {
  AppIcons._();

  static const double xs  = 14;
  static const double sm  = 18;
  static const double md  = 22; // الأيقونة الأساسية
  static const double lg  = 26;
  static const double xl  = 32;
  static const double xxl = 48; // Empty States
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. SHADOWS — الظلال (3 مستويات)
// ─────────────────────────────────────────────────────────────────────────────
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get none => [];

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: const Color(0xFF0A1120).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: const Color(0xFF0A1120).withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: const Color(0xFF0A1120).withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: const Color(0xFF0A1120).withValues(alpha: 0.14),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> accent({double alpha = 0.30}) => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: alpha),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> primary({double alpha = 0.25}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: alpha),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. DURATIONS — مدد الحركة (100ms base × φ)
// ─────────────────────────────────────────────────────────────────────────────
class AppDurations {
  AppDurations._();

  static const Duration instant  = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 160);
  static const Duration normal   = Duration(milliseconds: 260);
  static const Duration slow     = Duration(milliseconds: 420);
  static const Duration emphasis = Duration(milliseconds: 680);
  static const Duration page     = Duration(milliseconds: 320);
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. CURVES — منحنيات الحركة
// ─────────────────────────────────────────────────────────────────────────────
class AppCurves {
  AppCurves._();

  static const Curve standard    = Curves.easeInOutCubic;
  static const Curve enter       = Curves.easeOutCubic;   // عناصر تدخل
  static const Curve exit        = Curves.easeInCubic;    // عناصر تخرج
  static const Curve spring      = Curves.elasticOut;     // نبضة خفيفة
  static const Curve decelerate  = Curves.decelerate;
  static const Curve fastOutSlow = Curves.fastOutSlowIn;
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. HAPTICS — الاهتزازات (Apple HIG)
// ─────────────────────────────────────────────────────────────────────────────
class AppHaptics {
  AppHaptics._();

  static void light()     => HapticFeedback.lightImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void heavy()     => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void error()     => HapticFeedback.vibrate();
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. GLASS — الزجاجية (مقيّدة بشريط التنقل فقط)
//     القاعدة: ممنوع على البطاقات والمحتوى القابل للقراءة
// ─────────────────────────────────────────────────────────────────────────────
class AppGlass {
  AppGlass._();

  static const double blurLight  = 10;
  static const double blurMedium = 20;
  static const double blurHeavy  = 30;

  static const Color fillNavLight = Color(0xCCFFFFFF); // شريط التنقل (فاتح)
  static const Color fillNavDark  = Color(0xCC12294E); // شريط التنقل (داكن)
  static const Color fillOverlay  = Color(0x1AFFFFFF); // طبقات خفيفة فقط
  static const Color fillLight    = Color(0x1AFFFFFF); // alias للتوافق

  // ── الحدود الزجاجية ─────────────────────────────────────────────────
  static Border get edgeLight =>
      Border.all(color: const Color(0x26FFFFFF), width: 1);
  static Border get edgePrimary =>
      Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2), width: 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. DECORATIONS — الديكورات الجاهزة
// ─────────────────────────────────────────────────────────────────────────────
class AppDecor {
  AppDecor._();

  /// بطاقة عادية
  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.card,
    bool raised = false,
    Color? border,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? AppColors.line),
        boxShadow: raised ? AppShadows.md : AppShadows.sm,
      );

  /// بطاقة مرفوعة
  static BoxDecoration cardElevated({
    Color? color,
    double radius = AppRadius.card,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.lg,
      );

  /// زر CTA
  static BoxDecoration cta({Color? color, bool disabled = false}) {
    final c = disabled ? const Color(0xFFB9C0CC) : (color ?? AppColors.accent);
    return BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(AppRadius.btn),
      boxShadow: disabled ? null : AppShadows.accent(),
    );
  }

  /// حقل إدخال
  static BoxDecoration input({bool focused = false}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: focused ? AppColors.primary : AppColors.line,
          width: focused ? 1.6 : 1.0,
        ),
      );

  /// شارة حالة
  static BoxDecoration statusChip(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      );

  /// بانر الثقة (الدفع عند الاستلام)
  static BoxDecoration trustBanner() => BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
      );

  /// حاوية الفصل (Section)
  static BoxDecoration section() => const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 12. BREAKPOINTS — نقاط التكيّف (Responsive)
// ─────────────────────────────────────────────────────────────────────────────
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile  = 480;
  static const double tablet  = 768;
  static const double desktop = 1024;

  static bool isMobile(BuildContext ctx)  => MediaQuery.sizeOf(ctx).width < tablet;
  static bool isTablet(BuildContext ctx)  =>
      MediaQuery.sizeOf(ctx).width >= tablet &&
      MediaQuery.sizeOf(ctx).width < desktop;
  static bool isDesktop(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= desktop;

  /// عدد أعمدة الشبكة
  static int gridColumns(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w >= desktop) return 4;
    if (w >= tablet)  return 3;
    return 2;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 13. THEME DATA — إعدادات Flutter الكاملة
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildZaboonTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: AppType.fontUI,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.ink, size: AppIcons.md),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: AppType.h3,
        fontFamily: AppType.fontUI,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppType.style(AppType.body, color: AppColors.muted, weight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.md,
        vertical: AppMetrics.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppMetrics.buttonH),
        padding: const EdgeInsets.symmetric(vertical: AppMetrics.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.btn),
        ),
        elevation: 0,
        textStyle: AppType.style(AppType.body, color: Colors.white, weight: FontWeight.w800),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppMetrics.buttonH),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.btn),
        ),
        textStyle: AppType.style(AppType.body, color: Colors.white, weight: FontWeight.w800),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppType.style(AppType.body, weight: FontWeight.w700),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      labelStyle: AppType.style(AppType.small),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppType.style(AppType.small, color: Colors.white, weight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppType.h2Style,
      contentTextStyle: AppType.bodyStyle,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.muted,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),

    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. HELPERS — دوال مساعدة
// ─────────────────────────────────────────────────────────────────────────────

/// تنسيق الأسعار: 1,234 د.ع
String formatMoney(num value) {
  final s = value.round().toString();
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
  if (diff.inMinutes < 1)  return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24)   return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7)     return 'قبل ${diff.inDays} يوم';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// لون حالة الطلب
Color statusColor(String status) => switch (status) {
      'new' || 'pending'                  => AppColors.warning,
      'accepted' || 'preparing'           => AppColors.primary,
      'ready'                             => AppColors.cyan,
      'picked' || 'delivering'            => AppColors.primaryLight,
      'delivered'                         => AppColors.success,
      'cancelled'                         => AppColors.danger,
      'returned'                          => AppColors.muted,
      _                                   => AppColors.muted,
    };

/// نص حالة الطلب بالعربي
String statusLabel(String status) => switch (status) {
      'new'        => 'طلب جديد 🆕',
      'pending'    => 'قيد الانتظار',
      'accepted'   => 'مقبول',
      'preparing'  => 'قيد التجهيز',
      'ready'      => 'جاهز للاستلام',
      'picked'     => 'بالتوصيل',
      'delivering' => 'بالتوصيل',
      'delivered'  => 'تم التوصيل ✅',
      'cancelled'  => 'ملغي',
      'returned'   => 'مرتجع',
      _            => status,
    };

/// إيموجي حالة الطلب
String statusEmoji(String status) => switch (status) {
      'pending'    => '🕐',
      'accepted'   => '✅',
      'preparing'  => '👨‍🍳',
      'ready'      => '🎒',
      'picked'     => '🛵',
      'delivering' => '🛵',
      'delivered'  => '📦',
      'cancelled'  => '🚫',
      'returned'   => '↩️',
      _            => '🕐',
    };
