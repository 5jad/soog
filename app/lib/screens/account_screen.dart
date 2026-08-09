import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../map_screen.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders_screen.dart';
import 'login_screen.dart';
import 'vendor_shell.dart';
import 'delivery_shell.dart';
import 'admin_shell.dart';
import 'shell.dart';
import 'points_screen.dart';

/// حسابي — معلوماتي، الدخول كتاجر/مندوب/أدمن، الإشعارات، خروج
class AccountScreen extends StatefulWidget {
  final List<String> roles;
  const AccountScreen({super.key, required this.roles});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  dynamic me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/auth/me');
      me = d['user'];
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
          actions: const [
            SizedBox(width: 8),
            NotifBell(),
            SizedBox(width: 10),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline_rounded, size: 80, color: A.muted),
                const SizedBox(height: 16),
                Text('سجل دخولك لتتمكن من الطلب ومتابعة إشعاراتك', textAlign: TextAlign.center, style: A.t(16, c: A.muted)),
                const SizedBox(height: 24),
                SolidBtn(
                  label: 'تسجيل الدخول / إنشاء حساب',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
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
        actions: const [
          SizedBox(width: 8),
          NotifBell(),
          SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          // البطاقة (بتصميم الديمو)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: A.gradNavy, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [A.primaryLight, A.cyan]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  (u['name'] ?? '؟').toString().characters.first,
                  style: A.t(22, c: Colors.white, w: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] ?? 'زبون', style: A.t(16, c: Colors.white, w: FontWeight.w900)),
                Text('${u['phone'] ?? ''} · ${roleAr(u['role'])}', style: A.t(11.5, c: Colors.white.withOpacity(0.85), w: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
                    child: const Text('عضو في زبون منذ 2026 ✨', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 18),
          Text('كل شيء بحسابك', style: A.t(13, c: A.muted, w: FontWeight.w800)),
          const SizedBox(height: 10),
          // قوائم
          Container(
            decoration: A.glass(radius: 22),
            child: Column(children: [
              _tile(Icons.receipt_long_rounded, 'طلباتي 📦', () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListScreen(role: 'customer')))),
              _div(),
              _tile(Icons.star_rounded, 'نقاطي وهداياي 🎁', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsScreen()))),
              _div(),
              _tile(Icons.location_on_rounded, 'عناويني 📍', () => _addresses()),
            ]),
          ),
          const SizedBox(height: 18),
          // تبديل الأدوار
          if (widget.roles.length > 1) ...[
            Text('التطبيقات المتاحة لك', style: A.t(13, c: A.muted, w: FontWeight.w800)),
            const SizedBox(height: 10),
            if (widget.roles.contains('vendor'))
              _roleCard('أنا تاجر', 'إدارة متجري وطلباتي ومحفظتي', Icons.storefront_rounded, A.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorShell(onExit: _load)))),
            const SizedBox(height: 10),
            if (widget.roles.contains('delivery'))
              _roleCard('أنا مندوب', 'أستلم الطلبات وأوصلها وأقبض الكاش', Icons.delivery_dining_rounded, A.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryShell(onExit: _load)))),
            const SizedBox(height: 10),
            if (widget.roles.contains('admin'))
              _roleCard('لوحة التحكم', 'إدارة المنصة بالكامل', Icons.admin_panel_settings_rounded, A.warning, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminShell(onExit: _load)))),
            const SizedBox(height: 18),
          ],
          SolidBtn(
            label: 'تسجيل الخروج',
            color: A.danger,
            onTap: () async {
              await Api.clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => Shell()), (_) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: A.primary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: A.primary, size: 19),
      ),
      title: Text(label, style: A.t(13.5)),
      trailing: const Icon(Icons.chevron_left_rounded, color: A.muted),
      onTap: onTap,
    );
  }

  Widget _div() => const Divider(height: 1, indent: 52);

  Widget _roleCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: A.t(14, w: FontWeight.w900)),
          Text(sub, style: A.t(11, c: A.muted)),
        ])),
        const Icon(Icons.chevron_left_rounded, color: A.muted),
      ]),
    );
  }

  Future<void> _addresses() async {
    try {
      final d = await Api.get('/api/customer/addresses');
      final addrs = (d['addresses'] ?? []) as List;
      final ctrl = TextEditingController();
      double? alat;
      double? alng;
      await showSheet(context, StatefulBuilder(
        builder: (context, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetTitle('عناويني 📍'),
          if (addrs.isNotEmpty)
            for (final a in addrs)
              ListTile(
                leading: const Icon(Icons.location_on_rounded, color: A.primary),
                title: Text(a['address'], style: A.t(13)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: A.danger, size: 19),
                  onPressed: () async {
                    await Api.del('/api/customer/addresses/${a['id']}');
                    setS(() {});
                    Navigator.pop(context);
                    _addresses();
                  },
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'عنوان جديد...'))),
                const SizedBox(width: 10),
                SolidBtn(label: 'أضف', onTap: () async {
                  if (ctrl.text.isEmpty) return;
                  await Api.post('/api/customer/addresses', {
                    'details': ctrl.text,
                    if (alat != null) 'lat': alat,
                    if (alng != null) 'lng': alng,
                  });
                  Navigator.pop(context);
                  _addresses();
                }),
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: A.primary, side: const BorderSide(color: A.primary, width: 1.2)),
                onPressed: () async {
                  final picked = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => PickMapScreen(lat: alat, lng: alng)));
                  if (picked != null && picked is LatLng) {
                    setS(() {
                      alat = picked.latitude;
                      alng = picked.longitude;
                    });
                  }
                },
                icon: const Icon(Icons.map_rounded),
                label: Text(
                  alat != null ? 'الموقع محدد ✓ (${alat!.toStringAsFixed(4)}, ${alng!.toStringAsFixed(4)})' : 'حدد موقعك على الخريطة 🗺',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ),
        ]),
      ));
    } catch (_) {}
  }
}

String roleAr(dynamic r) {
  switch (r) {
    case 'admin': return 'مدير المنصة';
    case 'vendor': return 'تاجر';
    case 'delivery': return 'مندوب';
    default: return 'زبون';
  }
}
