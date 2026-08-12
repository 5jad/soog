import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';
import 'package:zaboon/features/orders/screens/orders_screen.dart';

/// شاشة نجاح إرسال الطلبات — تظهر بعد إتمام الطلب
class OrderSuccessScreen extends StatelessWidget {
  final int done;
  const OrderSuccessScreen({super.key, required this.done});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FBF4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LottieBox(
                assetKey: 'order_success', // confetti — once عند فتح الشاشة
                width: 150,
                height: 150,
                loop: false,
                fallback: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 62,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'انطلق طلبك بنجاح 🎉',
                style: AppType.style(22, weight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'أرسلنا $done ${done == 1 ? 'طلب' : 'طلبات'} — مندوبنا براسلك',
                style: AppType.style(13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'السلة انصفّرت بعد الطلب — أرقام الطلبات وتتبّع التوصيل من «طلباتي»',
                style: AppType.style(11, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 34),
              SolidBtn(
                label: '📦 شوف طلباتي',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderListScreen(role: 'customer', initialCode: null),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'عودة للتسوق',
                  style: AppType.style(
                    13,
                    color: AppColors.primary,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
