import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../lottie_box.dart';
import 'orders_screen.dart';

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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            LottieBox(
              assetKey: 'success',
              width: 150,
              height: 150,
              fallback: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(color: A.success.withOpacity(0.14), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: A.success, size: 62),
              ),
            ),
            const SizedBox(height: 22),
            Text('انطلق طلبك بنجاح 🎉', style: A.t(22, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('أرسلنا $done ${done == 1 ? 'طلب' : 'طلبات'} — مندوبنا براسلك',
                style: A.t(13, c: A.muted), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('السلة انصفّرت بعد الطلب — أرقام الطلبات وتتبّع التوصيل من «طلباتي»',
                style: A.t(11, c: A.muted), textAlign: TextAlign.center),
            const SizedBox(height: 34),
            SolidBtn(
              label: '📦 شوف طلباتي',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => OrderListScreen(role: 'customer', initialCode: null)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('عودة للتسوق', style: A.t(13, c: A.primary, w: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}