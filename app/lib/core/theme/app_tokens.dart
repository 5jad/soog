import 'package:flutter/material.dart';

class AppTokens {
  // Spacing (4/8pt grid)
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 24.0;
  static const double space6 = 32.0;
  static const double space8 = 48.0;

  // Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;

  // Icon sizes
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 28.0;

  // Typography (base 14, ratio 1.25, except textHero)
  static const double textXs = 11.0;
  static const double textSm = 12.0;
  static const double textBase = 14.0;
  static const double textMd = 16.0;
  static const double textLg = 18.0;
  static const double textXl = 22.0;
  static const double text2xl = 28.0;
  static const double textHero = 45.0;

  // Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // Shadow/Glassmorphism
  static const double blurSigma = 10.0;
  static const double shadowOpacity = 0.12;
}

/// ═══════════════════════════════════════════════════════════════
/// Liquid Glass Tokens — مستويات الزجاج الموحدة (نظام التصميم)
/// القاعدة: تُستخدم حصرياً على طبقة التنقل والتحكم (BottomSheet/
/// Modal، Header، عناصر عائمة) — ممنوعة على بطاقات المحتوى
/// (السعر/الوصف/الاسم تبقى على أسطح صلبة دائماً).
/// ═══════════════════════════════════════════════════════════════
class LiquidGlass {
  /// طبقة خفيفة: بطاقات مرفوعة قليلاً / عناصر فوق محتوى مباشرة
  static const double blurLayer1 = 10.0;

  /// طبقة متوسطة: BottomSheet / Modal
  static const double blurLayer2 = 20.0;

  /// طبقة قوية: تنقل عائم فوق محتوى كثيف (AppBar شفاف، قوائم منسدلة)
  static const double blurLayer3 = 30.0;

  /// حافة علوية فاتحة تحاكي انعكاس الضوء على الزجاج
  static const double edgeHighlightOpacity = 0.15;

  /// خلفية زجاجية فاتحة (opacity ~12%)
  static const Color glassFillLight = Color(0x1FFFFFFF);
}
