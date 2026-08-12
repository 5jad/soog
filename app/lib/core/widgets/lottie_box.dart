import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// سجل ملفات Lottie الستة الرسميين لتطبيق زبون.
/// القاعدة: infinite loop → loading_splash + main_loader فقط.
/// once → cart_confirm + order_success + empty_state + no_results.
class LottieAssets {
  LottieAssets._();

  static const Map<String, String> paths = {
    // ═══ الستة الجديدة الرسمية ═══
    'loading_splash': 'assets/lottie/loading_splash.json', // splash — loop
    'main_loader': 'assets/lottie/main_loader.json', // loader عام — loop
    'order_success': 'assets/lottie/order_success.json', // confetti — once
    'cart_confirm': 'assets/lottie/cart_confirm.json', // confirm سلة — once
    'empty_state': 'assets/lottie/empty_state.json', // فارغ — once
    'no_results': 'assets/lottie/no_results.json', // لا نتائج — once
    // ═══ مفاتيح تراثية (alias) — للتوافق مع الكود القديم ═══
    'loading': 'assets/lottie/main_loader.json',
    'success': 'assets/lottie/order_success.json',
    'cart_ok': 'assets/lottie/cart_confirm.json',
    'cart_empty': 'assets/lottie/empty_state.json',
    'fav_empty': 'assets/lottie/empty_state.json',
    'orders_empty': 'assets/lottie/empty_state.json',
  };

  static String? path(String key) => paths[key];

  /// هل هذا المفتاح مسموح له بالـ loop؟
  /// فقط loading_splash و main_loader (وأسماؤهما التراثية).
  static bool allowLoop(String key) =>
      key == 'loading_splash' ||
      key == 'main_loader' ||
      key == 'loading'; // alias
}

/// غلاف موحد للحركات.
///
/// قواعد:
/// - إذا [MediaQuery.disableAnimations] (تقليل الحركة) → يعرض [fallback].
/// - إذا الملف غير مسجّل → يعرض [fallback].
/// - إذا [loop] = true لكن المفتاح ليس loop مسموحاً → تلقائياً once.
/// - وإلا يلعب Lottie بإعدادات التكرار الصحيحة.
class LottieBox extends StatelessWidget {
  final String assetKey;
  final double width;
  final double height;

  /// true = loop مستمر، false = مرة واحدة.
  /// لو [assetKey] لا يسمح بالـ loop، تُجاهل هذه القيمة وتصبح false.
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

    // loop مسموح فقط لـ loading_splash و main_loader
    final effectiveLoop = loop && LottieAssets.allowLoop(assetKey);

    return Lottie.asset(
      path,
      width: width,
      height: height,
      repeat: effectiveLoop,
      fit: BoxFit.contain,
    );
  }
}
