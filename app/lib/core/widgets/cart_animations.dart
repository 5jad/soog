import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
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
/// تفاعل «انضاف للسلة» — انفجار Lottie كبير مركزي فوق كل شي
/// خلفية مغوشة (ضباب + تعتيم خفيف) تُبرز التفاعل بألوان الهوية
void addPop(BuildContext context) {
  toast(context, 'تمت الإضافة للسلة 🛍️');
  final overlay = Overlay.of(context);
  late final OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // تعتيم + ضباب خفيف خلف التفاعل (القاعدة: الخلفية تنزل تحت النص)
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: ColoredBox(
                color: AppColors.ink.withValues(alpha: 0.20),
              ),
            ),
          ),
          Center(
            child: LottieBox(
              assetKey: 'cart_confirm', // نبضة تأكيد الإضافة — once
              loop: false,
              width: 240,
              height: 240,
              fallback: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
  overlay.insert(e);
  Future.delayed(const Duration(milliseconds: 1600), () => e.remove());
}