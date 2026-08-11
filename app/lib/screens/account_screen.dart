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
import 'notifications_screen.dart';

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
          // ═══ بطاقة البروفايل ═══
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: A.gradNavy,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: A.primary.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [A.primaryLight, A.cyan]),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .55), width: 2.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (u['name'] ?? '؟').toString().characters.first,
                    style: A.t(24, c: Colors.white, w: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['name'] ?? 'زبون', style: A.t(17, c: Colors.white, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${u['phone'] ?? ''} · ${roleAr(u['role'])}', style: A.t(12, c: Colors.white.withValues(alpha: .85), w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                        child: const Text('عضو في زبون منذ 2026 ✨', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 8),
                  Text('رصيدك من النقاط', style: A.t(12, c: Colors.white.withValues(alpha: .85), w: FontWeight.w800)),
                  const Spacer(),
                  Text('${pointsCount.toString()} نقطة', style: A.t(15, c: Colors.white, w: FontWeight.w900)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // ═══ بطاقة طلباتي البارزة — Hero ═══
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListScreen(role: 'customer'))),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
              decoration: BoxDecoration(
                gradient: A.gradNavy,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: A.primary.withValues(alpha: .3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: const Text('📦', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('طلباتي', style: A.t(15, c: Colors.white, w: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('اضغط لمتابعة طلباتك ومراحلها',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: A.t(10.5, c: Colors.white.withValues(alpha: .8), w: FontWeight.w700)),
                  ]),
                ),
                Column(children: [
                  Text('$ordersCount', style: A.t(24, c: Colors.white, w: FontWeight.w900)),
                  Text('طلب', style: A.t(10, c: Colors.white.withValues(alpha: .8), w: FontWeight.w700)),
                ]),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_left_rounded, color: Colors.white70),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // ═══ إحصائيات ثانوية — نقاطي وعناويني ═══
          Row(children: [
            Expanded(
              child: _statCard(
                Icons.star_rounded,
                'نقاطي',
                '$pointsCount',
                '🎁',
                A.accent,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                Icons.location_on_rounded,
                'عناويني',
                '${_addrCount}',
                '📍',
                A.cyan,
                () => _addresses(),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          // ═══ قائمة سريعة ═══
          Container(
            decoration: A.card(radius: A.r20),
            child: Column(children: [
              _tile(Icons.notifications_rounded, 'الإشعارات 🔔', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              _div(),
              _tile(Icons.favorite_rounded, 'المفضلة ❤️', () => AppState.i.favsReload.value++),
              _div(),
              _tile(Icons.help_outline_rounded, 'مساعدة ودعم 🎧', () => toast(context, 'قريباً في التحديث الجاي')),
              _div(),
              ListTile(
                leading: const Icon(Icons.update_rounded, color: A.primary),
                title: Text('نسخة التطبيق', style: A.t(13.5)),
                trailing: Text('v$kAppVersion', style: A.t(12, c: A.muted, w: FontWeight.w800)),
                onTap: () async {
                  try {
                    final d = await Api.get('/api/app/version');
                    final v = d['version'] ?? kAppVersion;
                    toast(context, 'أحدث نسخة على الموقع: v$v');
                  } catch (_) {
                    toast(context, 'أحدث نسخة على الموقع: v$kAppVersion');
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 18),
          // ═══ تبديل الأدوار ═══
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

  Future<void> _addresses() async {
    try {
      final d = await Api.get('/api/customer/addresses');
      final addrs = (d['addresses'] ?? []) as List;
      _addrCount = addrs.length;
      if (mounted) setState(() {});
      final ctrl = TextEditingController();
      double? alat;
      double? alng;
      await showSheet(context, StatefulBuilder(
        builder: (context, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetTitle('عناويني 📍'),
            if (addrs.isNotEmpty) ...[
              for (final a in addrs)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14), border: Border.all(color: A.line)),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded, color: A.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${a['address']}', style: A.t(13, w: FontWeight.w700))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: A.danger, size: 19),
                      onPressed: () async {
                        await Api.del('/api/customer/addresses/${a['id']}');
                        setS(() {});
                        Navigator.pop(context);
                        _addresses();
                      },
                    ),
                  ]),
                ),
              const Divider(height: 22, color: A.line),
            ] else
              const Padding(padding: EdgeInsets.only(bottom: 8),
                  child: Text('لا عناوين محفوظة — أضف أول عنوان', style: TextStyle(color: A.muted, fontSize: 12.5))),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'عنوان جديد...',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: A.line)),
                  ),
                ),
              ),
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
            const SizedBox(height: 12),
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
      ));
    } catch (_) {}
  }

  int _addrCount = 0;

  Widget _statCard(IconData icon, String label, String value, String emoji, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: A.line),
          boxShadow: const [BoxShadow(color: Color(0x0A0A1120), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(value, style: A.t(17, w: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: A.t(11, c: A.muted, w: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: A.primary.withValues(alpha: .09),
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
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
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
}

String roleAr(dynamic r) {
  switch (r) {
    case 'admin': return 'مدير المنصة';
    case 'vendor': return 'تاجر';
    case 'delivery': return 'مندوب';
    default: return 'زبون';
  }
}