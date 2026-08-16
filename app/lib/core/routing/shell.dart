import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/notifications/notif_push.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/features/shop/screens/customer_shell.dart';
import 'package:zaboon/features/vendor/screens/vendor_shell.dart';
import 'package:zaboon/features/delivery/screens/delivery_shell.dart';
import 'package:zaboon/features/admin/screens/admin_shell.dart';
import 'package:zaboon/features/auth/screens/login_screen.dart';

/// الغلاف الرئيسي — يعرض Splash (loading_splash loop) أثناء تحميل بيانات
/// المستخدم/الجلسة، ثم يوجّه لشاشة الدور المناسبة فور اكتمال التحميل.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _ready = false;
  bool _guestMode = false; // ضيف: تصفح بدون حساب — الدخول عند الطلب/الإشعارات
  String _role = 'customer';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Api.load() تحمّل في main() قبل runApp — هنا نكمل أي تحميل إضافي
    // مثل التحقق من صلاحية الجلسة
    try {
      if (Api.logged && Api.me == null) {
        // حاول تحميل بيانات المستخدم من الخادم
        final d = await Api.get('/api/auth/me');
        Api.me = d['user'] ?? d;
      }
    } catch (_) {
      // الجلسة انتهت أو لا اتصال — نعرض شاشة الدخول
      Api.me = null;
    } finally {
      if (mounted) {
        setState(() {
          _role = Api.me?['role'] as String? ?? 'customer';
          _ready = true;
        });
        // طلب الصلاحيات بعد ظهور الواجهة لضمان رؤيتها من قبل المستخدم
        NotifPusher.i.requestPermission();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();

    // بدون حساب: ضيف يتصفح (سلة محلية) أو شاشة الدخول
    if (!Api.logged) {
      return _guestMode
          ? CustomerShell(roles: const ['customer'])
          : LoginScreen(
              onGuest: () => setState(() => _guestMode = true),
            );
    }

    if (_role == 'vendor') return VendorShell(onExit: _logout);
    if (_role == 'delivery') return DeliveryShell(onExit: _logout);
    if (_role == 'admin') return AdminShell(onExit: _logout);
    return CustomerShell(roles: _rolesOf(Api.me));
  }

  Future<void> _logout() async {
    await Api.clear();
    if (mounted) {
      setState(() {
        _ready = false;
        _role = 'customer';
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  List<String> _rolesOf(dynamic me) {
    final r = <String>['customer'];
    final u = me as Map<String, dynamic>?;
    if (u != null) {
      if (u['role'] == 'vendor' || u['is_vendor'] == true) r.add('vendor');
      if (u['role'] == 'delivery') r.add('delivery');
      if (u['role'] == 'admin') r.add('admin');
    }
    return r;
  }
}

/// شاشة البداية — loading_splash loop حتى يكتمل تحميل بيانات الجلسة
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink, // خلفية كحلية تنسجم مع هوية زبون
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieBox(
              assetKey: 'loading_splash',
              loop: true, // مستمر حتى اكتمال التحميل
              width: 200,
              height: 200,
              fallback: const CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'زبون',
              style: AppType.style(
                32,
                color: Colors.white,
                weight: FontWeight.w700,
              ).copyWith(fontFamily: 'ElMessiri'),
            ),
            const SizedBox(height: 6),
            Text(
              'جاري التحميل...',
              style: AppType.style(
                13,
                color: Colors.white54,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
