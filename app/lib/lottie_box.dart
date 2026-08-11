import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// سجل ملفات Lottie — يُسجّل هنا الاسم فقط بعد وضع ملف الـ JSON داخل
/// assets/lottie/ وإضافة المسار. ما دام الملف غير مسجّل تظهر الحركات
/// البديلة الثابتة (fallback) فلا ينكسر أي شيء.
class LottieAssets {
  LottieAssets._();

  /// key: اسم الحركة المستعمل في الواجهة — value: مسار الـ asset
  static const Map<String, String> paths = {
    'loading': 'assets/lottie/loading.json',
    'success': 'assets/lottie/success.json',
    'cart_empty': 'assets/lottie/cart_empty.json',
    'fav_empty': 'assets/lottie/fav_empty.json',
    'orders_empty': 'assets/lottie/orders_empty.json',
    'no_results': 'assets/lottie/no_results.json',
    'cart_ok': 'assets/lottie/cart_ok.json',
  };

  static String? path(String key) => paths[key];
}

/// غلاف موحد للحركات:
/// — إذا الجهاز بتقليل الحركة (Android reduced-motion / WCAG) → fallback.
/// — إذا الملف غير مسجّل بعد في [LottieAssets] → fallback.
/// — وإلا يلعب الـ Lottie (مرة واحدة للمؤكدات، loop للوادر).
class LottieBox extends StatelessWidget {
  final String assetKey;
  final double width;
  final double height;
  final bool loop;
  final Widget fallback;
  const LottieBox({
    super.key,
    required this.assetKey,
    required this.fallback,
    this.width = 140,
    this.height = 140,
    this.loop = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final path = LottieAssets.path(assetKey);
    if (reduce || path == null) return fallback;
    return Lottie.asset(path, width: width, height: height, repeat: loop, fit: BoxFit.contain);
  }
}
