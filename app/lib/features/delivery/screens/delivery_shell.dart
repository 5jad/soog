import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/shop/screens/map_screen.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/chat/screens/chat_screen.dart';

/// رابط موقع المتجر: من رابط التاجر المخزن أو من الإحداثيات مباشرة
String? storeMapLink(Object? lat, Object? lng, String? url) {
  if (url != null && url.trim().isNotEmpty) return url.trim();
  if (lat != null && lng != null) {
    final l = lat.toString(), g = lng.toString();
    if (l.isNotEmpty && g.isNotEmpty)
      return 'https://www.google.com/maps/search/?api=1&query=$l,$g';
  }
  return null;
}

Future<void> openStoreMap(
  BuildContext ctx,
  Object? lat,
  Object? lng,
  String? url,
) async {
  final link = storeMapLink(lat, lng, url);
  if (link == null) return toast(ctx, 'ماكو موقع للمحل بعد');
  final uri = Uri.parse(link);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) toast(ctx, 'ما فتحت الخريطة');
  } catch (_) {
    toast(ctx, 'ما فتحت الخريطة');
  }
}

/// الوقت المنقضي منذ انطلاق الرحلة
String elapsedSince(Object? iso) {
  final t = DateTime.tryParse(iso?.toString() ?? '');
  if (t == null) return '';
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inSeconds < 60) return 'انطلقت للتو';
  if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
  return 'منذ ${d.inHours}س ${d.inMinutes % 60}د';
}

/// واجهة المندوب: متاح · رحلتي · المحفظة
class DeliveryShell extends StatefulWidget {
  final VoidCallback onExit;
  const DeliveryShell({super.key, required this.onExit});
  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int tab = 0;
  bool online = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/delivery/status');
      online = d['online'] == true;
    } catch (_) {}
  }

  Future<void> toggleOnline() async {
    try {
      await Api.post('/api/delivery/online', {'online': !online});
      setState(() => online = !online);
      toast(
        context,
        online ? 'صرت متصل — الطلبات توصلك الآن 🛵' : 'صرت متوقف عن الاستلام',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(Icons.delivery_dining_rounded, 'مندوب توصيل'),
        actions: [
          GestureDetector(
            onTap: toggleOnline,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: online ? AppColors.success : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: online ? AppColors.success : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: online ? AppColors.success : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online ? 'متصل' : 'غير متصل',
                    style: AppType.style(
                      11.5,
                      color: online ? AppColors.success : AppColors.muted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.muted),
            tooltip: 'المحادثات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatListScreen(role: 'delivery'),
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.muted),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          _AvailableOrders(
            online: online,
            refresh: _load,
            onAccepted: () => setState(() => tab = 1),
          ),
          _MyTrip(),
          _WalletTab(role: 'delivery'),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        index: tab,
        items: const [
          (Icons.radar_rounded, 'متاح'),
          (Icons.route_rounded, 'رحلتي'),
          (Icons.account_balance_wallet_rounded, 'المحفظة'),
        ],
        onTap: (i) => setState(() => tab = i),
      ),
    );
  }
}

/* ═══════════ الطلبات المتاحة ═══════════ */
class _AvailableOrders extends StatefulWidget {
  final bool online;
  final VoidCallback refresh;
  final VoidCallback? onAccepted;
  const _AvailableOrders({
    required this.online,
    required this.refresh,
    this.onAccepted,
  });
  @override
  State<_AvailableOrders> createState() => _AvailableOrdersState();
}

class _AvailableOrdersState extends State<_AvailableOrders> {
  List orders = [];
  bool loading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث تلقائي كل 8 ثواني — الطلبات الجديدة تنزل بدون ما تحدث يدوياً
    _t = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/delivery/available');
      orders = (d['orders'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    if (!widget.online) {
      return const EmptyState(
        icon: '😴',
        title: 'أنت غير متصل',
        sub: 'فعل زر "متصل" فوق عشان توصلك الطلبات',
      );
    }
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            EmptyState(
              icon: '📡',
              title: 'لا طلبات متاحة',
              sub: 'رح ينزلون هنا لحظة ما جاهزون',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final g = _groups[i];
          if (g.length > 1) return _groupCard(g);
          final o = Map<String, dynamic>.from(g.first);
          final order = Order.fromJson(o);
          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.code}',
                        style: AppType.style(14, weight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      'جاهز 🎒',
                      style: AppType.style(
                        11.5,
                        color: AppColors.cyan,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    storeLogo(order.storeLogo, size: 34, radius: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(order.storeName, style: AppType.style(12.5)),
                    ),
                    if (storeMapLink(
                          o['store_lat'],
                          o['store_lng'],
                          o['store_location_url'] as String?,
                        ) !=
                        null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.navigation_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'موقع المتجر على الخريطة',
                        onPressed: () => openStoreMap(
                          context,
                          o['store_lat'],
                          o['store_lng'],
                          o['store_location_url'] as String?,
                        ),
                      ),
                    Text(
                      formatMoney(order.total),
                      style: AppType.style(
                        14,
                        color: AppColors.accent,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'استلام من المتجر: ${o['store_address'] ?? ''}',
                        style: AppType.style(11.5, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        o['user_address_label'] ?? o['address_text'] ?? '',
                        style: AppType.style(11.5, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (o['store_lat'] != null && o['user_lat'] != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutePreviewScreen(
                          from: LatLng(
                            (o['store_lat'] as num).toDouble(),
                            (o['store_lng'] as num).toDouble(),
                          ),
                          to: LatLng(
                            (o['user_lat'] as num).toDouble(),
                            (o['user_lng'] as num).toDouble(),
                          ),
                          fromLabel: order.storeName,
                          toLabel:
                              o['user_address_label'] as String? ?? 'الزبون',
                        ),
                      ),
                    ),
                    child: const Text(
                      'شوف المسار والمسافة 🗺️',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                SolidBtn(
                  label: 'استلم الطلب 🛵',
                  onTap: () => _accept(context, order.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // تجميع طلبات المجموعة الواحدة (نفس group_id) — بطاقة واحدة وزر قبول واحد للرحلة كلها
  List<List<Map>> get _groups {
    final out = <List<Map>>[];
    final byGid = <String, List<Map>>{};
    for (final raw in orders) {
      final m = Map<String, dynamic>.from(raw as Map);
      final gid = m['group_id'];
      if (gid != null) {
        byGid.putIfAbsent('$gid', () => []).add(m);
      } else {
        out.add([m]);
      }
    }
    out.addAll(byGid.values);
    return out;
  }

  Future<void> _accept(BuildContext ctx, int orderId) async {
    try {
      await Api.post('/api/delivery/accept/$orderId', {});
      toast(ctx, 'انقبلت الرحلة! 🎉');
      widget.refresh();
      _load();
      widget.onAccepted?.call();
    } on ApiException catch (e) {
      toast(ctx, e.message, error: true);
    }
  }

  Widget _groupCard(List<Map> g) {
    final total = g.fold<int>(
      0,
      (s, o) => s + ((o['total'] ?? 0) as num).toInt(),
    );
    LatLng? home;
    final stops = <LatLng>[];
    for (final o in g) {
      if (o['user_lat'] != null && o['user_lng'] != null && home == null) {
        home = LatLng(
          (o['user_lat'] as num).toDouble(),
          (o['user_lng'] as num).toDouble(),
        );
      }
      if (o['store_lat'] != null && o['store_lng'] != null) {
        stops.add(
          LatLng(
            (o['store_lat'] as num).toDouble(),
            (o['store_lng'] as num).toDouble(),
          ),
        );
      }
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'طلب من ${g.length} محلات 🛍',
                  style: AppType.style(
                    14,
                    weight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                'جاهز 🎒',
                style: AppType.style(
                  11.5,
                  color: AppColors.cyan,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'رحلة واحدة تاخذ من كل المحلات',
            style: AppType.style(10.5, color: AppColors.muted),
          ),
          const Divider(height: 16),
          for (final o in g)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  storeLogo('', size: 32, radius: 9),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o['store_name'] ?? '',
                          style: AppType.style(12, weight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#${o['code']} · ${formatMoney(o['total'] ?? 0)}',
                          style: AppType.style(10.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (storeMapLink(
                        o['store_lat'],
                        o['store_lng'],
                        o['store_location_url'] as String?,
                      ) !=
                      null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      tooltip: 'موقع المحل على الخريطة',
                      onPressed: () => openStoreMap(
                        context,
                        o['store_lat'],
                        o['store_lng'],
                        o['store_location_url'] as String?,
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 14),
          Row(
            children: [
              Text(
                'المجموع ',
                style: AppType.style(12, color: AppColors.muted),
              ),
              Text(
                formatMoney(total),
                style: AppType.style(
                  14,
                  color: AppColors.accent,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (home != null && stops.isNotEmpty)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutePreviewScreen(
                    from: stops.length > 1 ? stops.first : null,
                    stops: stops.length > 1 ? stops.sublist(1) : const [],
                    to: home!,
                    fromLabel: g.first['store_name'] as String?,
                    toLabel:
                        g.first['user_address_label'] as String? ?? 'الزبون',
                  ),
                ),
              ),
              child: const Text(
                'شوف المسار والمسافة 🗺️',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          SolidBtn(
            label: 'استلم الرحلة كلها 🛵',
            onTap: () => _accept(context, (g.first['id'] as num).toInt()),
          ),
        ],
      ),
    );
  }
}

/* ═══════════ رحلتي ═══════════ */
class _MyTrip extends StatefulWidget {
  const _MyTrip();
  @override
  State<_MyTrip> createState() => _MyTripState();
}

class _MyTripState extends State<_MyTrip> {
  dynamic trip;
  bool loading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث تلقائي كل 5 ثواني — يعرض الرحلة فور قبولها ويختفي فور التسليم
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/delivery/trip');
      trip = d['trip'];
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    if (trip == null || trip == '') {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            EmptyState(
              icon: '🛵',
              title: 'ما عندك رحلة حالياً',
              sub: 'روح تبويب "متاح" واستلم طلب',
            ),
          ],
        ),
      );
    }
    final t = trip is Map ? Map<String, dynamic>.from(trip as Map) : null;
    if (t == null) return const EmptyState(icon: '🛵', title: 'لا رحلة');
    final code = t['code'] ?? '';
    final status = t['status'] ?? '';
    final total = (t['total'] ?? 0) as num;
    final storeName = t['store_name'] ?? '';
    final storeAddress = t['store_address'] ?? '';
    final userAddress = t['address_text'] ?? '';
    final userName = t['user_name'] ?? '';
    final userPhone = t['user_phone'] ?? '';
    final picked = t['picked_at'] != null;
    final elapsed = elapsedSince(t['accepted_at']);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: AppColors.gradNavy,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: Column(
              children: [
                Text(
                  '#$code',
                  style: AppType.style(
                    22,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel(status),
                  style: AppType.style(12.5, color: Colors.white70),
                ),
                if (elapsed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⏱ $elapsed',
                    style: AppType.style(12, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SolidBtn(
            label: 'خريطة التوصيل الحية 🗺️',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CourierMapScreen(trip: t)),
            ),
          ),
          const SizedBox(height: 14),
          if (((t['orders'] as List?) ?? []).length > 1) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'طلب من ${(t['orders'] as List).length} محلات 🛍',
                        style: AppType.style(
                          14,
                          weight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  for (final o in t['orders'] as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          storeLogo('', size: 34, radius: 9),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shortName(o['store_name'] as String?),
                                  style: AppType.style(
                                    12.5,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '#${o['code']} · ${formatMoney((o['total'] ?? 0) as num)}',
                                  style: AppType.style(
                                    10.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            tooltip: 'موقع المحل على الخريطة',
                            onPressed: () => openStoreMap(
                              context,
                              o['store_lat'],
                              o['store_lng'],
                              o['store_location_url'] as String?,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    storeLogo('', size: 40, radius: 10),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$storeName',
                          style: AppType.style(14, weight: FontWeight.w900),
                        ),
                        Text(
                          'المتجر — الاستلام من هنا',
                          style: AppType.style(10.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.navigation_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: 'موقع المتجر على الخريطة',
                      onPressed: () => openStoreMap(
                        context,
                        t['store_lat'],
                        t['store_lng'],
                        t['store_location_url'] as String?,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$storeAddress', style: AppType.style(12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$userName',
                        style: AppType.style(13.5, weight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '$userPhone',
                      style: AppType.style(11.5, color: AppColors.muted),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$userAddress', style: AppType.style(13)),
                    ),
                    if (storeMapLink(t['user_lat'], t['user_lng'], null) !=
                            null ||
                        userAddress.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: AppColors.danger,
                        ),
                        tooltip: 'موقع الزبون على الخريطة',
                        onPressed: () async {
                          if ((t['user_lat'] != null &&
                              t['user_lng'] != null)) {
                            openStoreMap(
                              context,
                              t['user_lat'],
                              t['user_lng'],
                              null,
                            );
                          } else {
                            toast(context, 'ماكو إحداثيات للعنوان');
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text('كاش عند التسليم: ', style: AppType.style(13)),
                    Text(
                      formatMoney(total),
                      style: AppType.style(
                        14,
                        color: AppColors.success,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (status == 'delivering' && !picked)
            SolidBtn(
              label: 'استلمت الطلب من المتجر 📦',
              onTap: () async {
                try {
                  await Api.post('/api/delivery/pickup', {'trip_id': t['id']});
                  toast(context, 'انطلقت بالتوصيل! 🛵');
                  _load();
                } on ApiException catch (e) {
                  toast(context, e.message, error: true);
                }
              },
            ),
          if (status == 'delivering' && picked)
            SolidBtn(
              label: 'تم التسليم + قبض الكاش 💵',
              onTap: () async {
                try {
                  await Api.post('/api/delivery/delivered', {
                    'trip_id': t['id'],
                  });
                  toast(context, 'تم التسليم! عاشت إيدك 🎉');
                  _load();
                } on ApiException catch (e) {
                  toast(context, e.message, error: true);
                }
              },
            ),
        ],
      ),
    );
  }
}

/* ═══════════ المحفظة (مندوب) ═══════════ */
class _WalletTab extends StatefulWidget {
  final String role;
  const _WalletTab({required this.role});
  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  dynamic w;
  List tx = [];
  bool loading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/delivery/wallet');
      w = d['wallet'];
      tx = (d['transactions'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    final balance = (w?['balance'] ?? 0) as num;
    final today = (w?['today'] ?? 0) as num;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppColors.gradNavy,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: Column(
              children: [
                const Text(
                  'أرباحي من التوصيل',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(balance),
                  style: AppType.style(
                    30,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'اليوم: ${formatMoney(today)} 💪',
                  style: const TextStyle(
                    color: Color(0xFFBBF7D0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SolidBtn(label: 'تقرير الكاش للأدمن 💵', onTap: _cashReport),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('الحركات', style: AppType.style(14, weight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (tx.isEmpty)
            const EmptyState(icon: '🧾', title: 'لا حركات بعد')
          else
            for (final t in tx) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (t['type'] == 'credit')
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        (t['type'] == 'credit')
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: (t['type'] == 'credit')
                            ? AppColors.success
                            : AppColors.danger,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['note'] ?? '', style: AppType.style(12.5)),
                          Text(
                            timeAgo(t['created_at'] ?? ''),
                            style: AppType.style(10, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${t['type'] == 'credit' ? '+' : '-'} ${formatMoney(t['amount'] ?? 0)}',
                      style: AppType.style(
                        13,
                        color: (t['type'] == 'credit')
                            ? AppColors.success
                            : AppColors.danger,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _cashReport() async {
    final amt = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const ScreenTitle(Icons.payments_rounded, 'تقرير الكاش اليومي'),
        content: TextField(
          controller: amt,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'المبلغ المجموع اليوم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('/api/delivery/cash-report', {
        'amount': double.tryParse(amt.text) ?? 0,
      });
      toast(context, 'انرسل التقرير للأدمن ✓');
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }
}
