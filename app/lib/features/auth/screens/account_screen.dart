import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/cart_checkout/screens/cart_screen.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/orders/screens/orders_screen.dart';
import 'package:zaboon/features/auth/screens/login_screen.dart';
import 'package:zaboon/features/vendor/screens/vendor_shell.dart';
import 'package:zaboon/features/delivery/screens/delivery_shell.dart';
import 'package:zaboon/features/admin/screens/admin_shell.dart';
import 'package:zaboon/core/routing/shell.dart';
import 'package:zaboon/features/points/screens/points_screen.dart';
import 'package:zaboon/features/notifications/screens/notifications_screen.dart';

/// حسابي — معلوماتي، الدخول كتاجر/مندوب/أدمن، الإشعارات، خروج
class AccountScreen extends StatefulWidget {
  final List<String> roles;
  const AccountScreen({super.key, required this.roles});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  dynamic me;
  int ordersCount = 0;
  int pointsCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/auth/me');
      me = d['user'];
      pointsCount = ((d['me']?['points'] ?? me?['points'] ?? 0) as num).toInt();
    } catch (_) {}
    try {
      final d = await Api.get('/api/customer/orders');
      ordersCount = (d['orders'] ?? []).length;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Api.logged) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 14,
          title: const TopBarPill(),
          actions: const [SizedBox(width: 8), NotifBell(), SizedBox(width: 10)],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 80,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  'سجل دخولك لتتمكن من الطلب ومتابعة إشعاراتك',
                  textAlign: TextAlign.center,
                  style: AppType.style(16, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                SolidBtn(
                  label: 'تسجيل الدخول / إنشاء حساب',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final u = (me ?? Api.me ?? {}) as Map<String, dynamic>;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 14,
        title: const TopBarPill(),
        actions: const [SizedBox(width: 8), NotifBell(), SizedBox(width: 10)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          // ═══ بطاقة البروفايل ═══
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: AppColors.gradNavy,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryLight, AppColors.cyan],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .55),
                          width: 2.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (u['name'] ?? '؟').toString().characters.first,
                        style: AppType.style(
                          24,
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['name'] ?? 'زبون',
                            style: AppType.style(
                              17,
                              color: Colors.white,
                              weight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${u['phone'] ?? ''} · ${roleAr(u['role'])}',
                            style: AppType.style(
                              12,
                              color: Colors.white.withValues(alpha: .85),
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'عضو في زبون منذ 2026 ✨',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFFFD54F),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'رصيدك من النقاط',
                        style: AppType.style(
                          12,
                          color: Colors.white.withValues(alpha: .85),
                          weight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pointsCount.toString()} نقطة',
                        style: AppType.style(
                          15,
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ═══ بطاقة طلباتي البارزة — Hero ═══
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderListScreen(role: 'customer'),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
              decoration: BoxDecoration(
                gradient: AppColors.gradNavy,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📦', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلباتي',
                          style: AppType.style(
                            15,
                            color: Colors.white,
                            weight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'اضغط لمتابعة طلباتك ومراحلها',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.style(
                            10.5,
                            color: Colors.white.withValues(alpha: .8),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$ordersCount',
                        style: AppType.style(
                          24,
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'طلب',
                        style: AppType.style(
                          10,
                          color: Colors.white.withValues(alpha: .8),
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ═══ إحصائيات ثانوية — نقاطي وعناويني ═══
          Row(
            children: [
              Expanded(
                child: _statCard(
                  Icons.star_rounded,
                  'نقاطي',
                  '$pointsCount',
                  '🎁',
                  AppColors.accent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PointsScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: AppState.i.cartCount,
                  builder: (_, count, __) => _statCard(
                    Icons.shopping_cart_rounded,
                    'السلة',
                    '$count',
                    '🛒',
                    AppColors.primary,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ═══ قائمة سريعة ═══
          Container(
            decoration: AppDecor.card(radius: AppRadius.xl),
            child: Column(
              children: [
                _tile(
                  Icons.notifications_rounded,
                  'الإشعارات 🔔',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                _div(),
                _tile(
                  Icons.favorite_rounded,
                  'المفضلة ❤️',
                  () => AppState.i.favsReload.value++,
                ),
                _div(),
                _tile(
                  Icons.help_outline_rounded,
                  'مساعدة ودعم 🎧',
                  () => toast(context, 'قريباً في التحديث الجاي'),
                ),
                _div(),
                ListTile(
                  leading: const Icon(
                    Icons.update_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text('نسخة التطبيق', style: AppType.style(13.5)),
                  trailing: Text(
                    'v$kAppVersion',
                    style: AppType.style(
                      12,
                      color: AppColors.muted,
                      weight: FontWeight.w800,
                    ),
                  ),
                  onTap: () async {
                    try {
                      final d = await Api.get('/api/app/version');
                      if (!context.mounted) return;
                      final latest = (d['version'] ?? '').toString();
                      final build = (d['build'] as num?)?.toInt() ?? 0;
                      if (build > kAppBuild) {
                        toast(context, 'توجد نسخة أحدث v$latest — جاري فتح التحميل...');
                        final u = Uri.parse(Api.base + (d['download_url'] ?? '/download'));
                        launchUrl(u, mode: LaunchMode.externalApplication);
                      } else {
                        toast(context, 'إصدارك v$kAppVersion — هو آخر إصدار ✓');
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      toast(context, 'إصدارك: v$kAppVersion');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ═══ تبديل الأدوار ═══
          if (widget.roles.length > 1) ...[
            Text(
              'التطبيقات المتاحة لك',
              style: AppType.style(
                13,
                color: AppColors.muted,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.roles.contains('vendor'))
              _roleCard(
                'أنا تاجر',
                'إدارة متجري وطلباتي ومحفظتي',
                Icons.storefront_rounded,
                AppColors.primary,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VendorShell(onExit: _load)),
                ),
              ),
            const SizedBox(height: 10),
            if (widget.roles.contains('delivery'))
              _roleCard(
                'أنا مندوب',
                'أستلم الطلبات وأوصلها وأقبض الكاش',
                Icons.delivery_dining_rounded,
                AppColors.cyan,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryShell(onExit: _load),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (widget.roles.contains('admin'))
              _roleCard(
                'لوحة التحكم',
                'إدارة المنصة بالكامل',
                Icons.admin_panel_settings_rounded,
                AppColors.warning,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminShell(onExit: _load)),
                ),
              ),
            const SizedBox(height: 18),
          ],
          SolidBtn(
            label: 'تسجيل الخروج',
            color: AppColors.danger,
            onTap: () async {
              await Api.clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => Shell()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    String label,
    String value,
    String emoji,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0A1120),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 8),
            Text(value, style: AppType.style(17, weight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppType.style(
                11,
                color: AppColors.muted,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 19),
      ),
      title: Text(label, style: AppType.style(13.5)),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _div() => const Divider(height: 1, indent: 52);

  Widget _roleCard(
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.style(14, weight: FontWeight.w900)),
                Text(sub, style: AppType.style(11, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

String roleAr(dynamic r) {
  switch (r) {
    case 'admin':
      return 'مدير المنصة';
    case 'vendor':
      return 'تاجر';
    case 'delivery':
      return 'مندوب';
    default:
      return 'زبون';
  }
}
