import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/shop/screens/map_screen.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/chat/screens/chat_screen.dart';

/// قائمة الطلبات — تدعم أدوار متعددة
/// customer: طلباتي | vendor: طلبات المتجر | delivery: طلبات متاحة/رحلة
class OrderListScreen extends StatefulWidget {
  final String role;
  final String? initialCode;
  final bool embedded;
  const OrderListScreen({
    super.key,
    this.role = 'customer',
    this.initialCode,
    this.embedded = false,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  List orders = [];
  bool loading = true;
  String filter = 'all';
  Timer? _t;

  /// مجموعات الحالة الفعلية في الباك — كل مجموعة تحوي قيم `status` الحقيقية
  static const groups = [
    ('الكل 📋', <String>[]),
    ('قيد التجهيز ⏳', ['new', 'pending', 'accepted', 'preparing']),
    ('بالتوصيل 🛵', ['ready', 'picked', 'delivering']),
    ('مكتملة ✅', ['delivered']),
    ('ملغية/مرتجعة ↩️', ['cancelled', 'returned']),
  ];

  /// عدّاد كل فئة — يظهر بجانب اسمها
  int _count(List<String> ss) => ss.isEmpty
      ? orders.length
      : orders.where((o) => ss.contains(o['status'])).length;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث تلقائي كل 10 ثواني — الحالة تتغير بدون ما تحدث يدوياً
    _t = Timer.periodic(const Duration(seconds: 10), (_) {
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
      if (widget.role == 'delivery') {
        final tripD = await Api.get('/api/delivery/trip');
        final availD = await Api.get('/api/delivery/available');
        final seen = <int>{};
        final merged = <Map>[];
        final trip = tripD['trip'];
        if (trip != null) {
          final t = Map<String, dynamic>.from(trip as Map);
          final oid = t['order_id'];
          if (oid != null) seen.add((oid as num).toInt());
          merged.add(t);
        }
        for (final x in (availD['orders'] ?? []) as List) {
          final a = Map<String, dynamic>.from(x as Map);
          if (seen.add((a['id'] as num).toInt())) merged.add(a);
        }
        orders = merged;
      } else {
        final ep = widget.role == 'customer'
            ? '/api/customer/orders'
            : '/api/vendor/orders';
        final d = await Api.get(ep);
        orders = (d['orders'] ?? []) as List;
      }
      if (widget.initialCode != null && mounted) {
        final o = orders.where((x) => x['code'] == widget.initialCode).toList();
        if (o.isNotEmpty) _open(o.first);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _open(dynamic o) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: (o['order_id'] ?? o['id']) as int,
          role: widget.role,
          onChanged: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selGroup = groups.firstWhere(
      (g) => g.$1 == filter,
      orElse: () => groups.first,
    );
    late List list = selGroup.$2.isEmpty
        ? orders
        : orders.where((o) => selGroup.$2.contains(o['status'])).toList();

    Widget body;
    if (loading) {
      body = const Loader();
    } else if (list.isEmpty) {
      body = EmptyState(
        icon: widget.role == 'vendor' ? '🗃' : '🧾',
        title: widget.role == 'vendor' ? 'لا طلبات على متجرك' : 'ماكو طلبات',
        sub: selGroup.$2.isEmpty
            ? 'رح تظهر الطلبات هنا'
            : 'هذي الفئة مافيها طلبات — جرب فئة ثانية أو «الكل»',
        lottie: widget.role == 'vendor' ? null : 'empty_state',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _orderCard(Map<String, dynamic>.from(list[i] as Map)),
        ),
      );
    }

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي 📦')),
      body: Column(
        children: [
          if (widget.role == 'customer') _filterBar(),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// بطاقة طلب واحدة — تصميم عالي: شريط حالة، صور الأصناف، السعر
  Widget _orderCard(Map<String, dynamic> o) {
    final order = Order.fromJson(o);
    final items = (o['items'] ?? []) as List;
    return GestureDetector(
      onTap: () => _open(o),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0A1120),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (order.storeName.isNotEmpty)
                  storeLogo(order.storeLogo, size: 34, radius: 10),
                if (order.storeName.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.storeName.isEmpty
                        ? '#${order.code}'
                        : order.storeName,
                    style: AppType.style(13, weight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${order.code}',
                  style: AppType.style(
                    10.5,
                    color: AppColors.muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final it in items.take(3)) ...[
                  productImage(it['image'], size: 30, radius: 9),
                  const SizedBox(width: 6),
                ],
                if (items.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${items.length - 3} صنف',
                      style: AppType.style(
                        10,
                        color: AppColors.muted,
                        weight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (items.isNotEmpty)
                  Text(
                    '${items.length} صنف',
                    style: AppType.style(
                      10,
                      color: AppColors.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                const Spacer(),
                Text(
                  timeAgo(order.createdAt),
                  style: AppType.style(10, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  formatMoney(order.total),
                  style: AppType.style(
                    16,
                    color: AppColors.accent,
                    weight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                StatusChip(order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// شريط الفئات — مع عدّاد لكل فئة، واختيار «الكل» يلغي أي تحديد
  Widget _filterBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() => filter = g.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filter == g.$1 ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: filter == g.$1
                          ? AppColors.primary
                          : AppColors.line,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        g.$1,
                        style: AppType.style(
                          11.5,
                          color: filter == g.$1 ? Colors.white : AppColors.ink,
                          weight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: filter == g.$1
                              ? Colors.white24
                              : AppColors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_count(g.$2)}',
                          style: AppType.style(
                            10,
                            color: filter == g.$1
                                ? Colors.white
                                : AppColors.primary,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// تفاصيل الطلب مع خطوات الحالة وإجراءات حسب الدور
class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String role;
  final VoidCallback? onChanged;
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.role,
    this.onChanged,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  dynamic o;
  Map<String, dynamic>? _trip;
  bool loading = true;

  static const steps = ['new', 'preparing', 'ready', 'delivering', 'delivered'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ep = widget.role == 'customer'
          ? '/api/customer/orders/${widget.orderId}'
          : widget.role == 'vendor'
          ? '/api/vendor/orders/${widget.orderId}'
          : '/api/delivery/orders/${widget.orderId}/trip';
      final d = await Api.get(ep);
      o = widget.role == 'delivery' ? d['trip'] : d['order'];
      if (widget.role == 'delivery') _loadTrip();
    } catch (_) {
      // يحاول نقطة أخرى
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // رحلة المندوب لهذا الطلب (قد تضم طلبات من محلات أخرى)
  Future<void> _loadTrip() async {
    try {
      final d = await Api.get('/api/delivery/orders/${widget.orderId}/trip');
      final t = d['trip'];
      if (mounted && t != null)
        setState(() => _trip = Map<String, dynamic>.from(t as Map));
    } catch (_) {}
  }

  Future<void> _act(String ep, Map<String, dynamic> body, String msg) async {
    try {
      await Api.post(ep, body);
      toast(context, msg);
      widget.onChanged?.call();
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  Future<void> _chatCourier(Order o) async {
    if (o.courierId <= 0) return;
    try {
      final d = await Api.post('/api/customer/conversations', {
        'courier_id': o.courierId,
      });
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            role: 'customer',
            conversation: {
              'id': (d['conversation'] as Map)['id'],
              'courier_name': o.courierName,
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    } catch (_) {
      toast(context, 'تعذر فتح المحادثة', error: true);
    }
  }

  Future<void> _callCourier(Order o) async {
    final phone = o.courierPhone.trim();
    if (phone.isEmpty) {
      toast(context, 'ماكو رقم لمندوب التوصيل', error: true);
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
  }

  int get stepIdx {
    final s = (o?['status'] ?? 'pending') as String;
    final i = steps.indexOf(s);
    return i < 0 ? -1 : i;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Loader());
    if (o == null)
      return const Scaffold(
        body: EmptyState(icon: '🧾', title: 'الطلب غير موجود'),
      );
    final order = Order.fromJson(Map<String, dynamic>.from(o as Map));
    final status = order.status;
    final items = (o['items'] ?? []) as List;
    final idx = stepIdx;
    final cancelled = status == 'cancelled' || status == 'returned';
    final trip = _trip == null ? null : Map<String, dynamic>.from(_trip!);

    return Scaffold(
      appBar: AppBar(title: Text('#${order.code}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          // خط الحالة
          if (!cancelled)
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      final done = i <= idx;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: done ? AppColors.primary : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: done
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                              ),
                              child: Icon(
                                done
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined,
                                size: 13,
                                color: done ? Colors.white : AppColors.muted,
                              ),
                            ),
                            Text(
                              steps[i] == 'new'
                                  ? 'جديد'
                                  : steps[i] == 'preparing'
                                  ? 'تجهيز'
                                  : steps[i] == 'ready'
                                  ? 'جاهز'
                                  : steps[i] == 'delivering'
                                  ? 'استلام'
                                  : 'تسليم',
                              style: AppType.style(
                                9,
                                color: done
                                    ? AppColors.primary
                                    : AppColors.muted,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusLabel(status),
                    style: AppType.style(
                      14,
                      color: statusColor(status),
                      weight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${timeAgo(order.createdAt)} · ${order.itemsCount} صنف',
                    style: AppType.style(11, color: AppColors.muted),
                  ),
                ],
              ),
            )
          else
            GlassCard(
              child: Center(
                child: Text(
                  'الطلب ${statusLabel(status)}',
                  style: AppType.style(
                    15,
                    color: statusColor(status),
                    weight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          // المنتجات
          GlassCard(
            child: Column(
              children: [
                for (final it in items) ...[
                  Row(
                    children: [
                      productImage(it['image'], size: 42, radius: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it['product_name'] ?? '',
                              style: AppType.style(13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${it['qty']} × ${formatMoney(it['price'] ?? 0)}${it['variant'] != null ? ' · ${it['variant']}' : ''}',
                              style: AppType.style(
                                10.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatMoney(
                          ((it['price'] ?? 0) * (it['qty'] ?? 1)) as num,
                        ),
                        style: AppType.style(12.5, weight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                ],
                Row(
                  children: [
                    const Text(
                      'المجموع',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(order.total),
                      style: AppType.style(
                        17,
                        color: AppColors.accent,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Text(
                      'الدفع: كاش عند الاستلام 💵',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // العنوان
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.address.isEmpty
                        ? 'الشارع العام — الكوت'
                        : order.address,
                    style: AppType.style(12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (order.courierName.isNotEmpty)
            GlassCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.delivery_dining_rounded,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المندوب: ${order.courierName}',
                      style: AppType.style(12.5),
                    ),
                  ),
                  if (status == 'delivering') ...[
                    IconButton(
                      onPressed: () => _chatCourier(order),
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'محادثة المندوب',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: () => _callCourier(order),
                      icon: const Icon(
                        Icons.call_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'اتصال بالمندوب',
                      visualDensity: VisualDensity.compact,
                    ),
                  ] else
                    const Icon(
                      Icons.phone_rounded,
                      size: 17,
                      color: AppColors.muted,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // إجراءات الزبون
          if (widget.role == 'customer') ...[
            // الخريطة الحية تظهر أوتوماتيك: من قبول المندوب إلى التسليم
            if (status == 'delivering' ||
                status == 'picked' ||
                status == 'delivered')
              LiveTrackCard(orderId: widget.orderId),
            const SizedBox(height: 14),
            if (status == 'delivering' || status == 'picked')
              SolidBtn(
                label: 'شاهد المندوب على الخريطة 🗺',
                color: const Color(0xFF22C55E),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTrackMapScreen(orderId: widget.orderId),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (status == 'pending' || status == 'accepted')
              SolidBtn(
                label: 'إلغاء الطلب',
                color: AppColors.danger,
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('إلغاء الطلب؟'),
                      content: const Text('متأكد؟ بيمشي للتاجر مباشرة'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('لا'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('نعم، ألغِ'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true)
                    _act(
                      '/api/customer/orders/${widget.orderId}/cancel',
                      {},
                      'انلغى الطلب',
                    );
                },
              ),
            const SizedBox(height: 10),
            if (status == 'delivered') ...[
              if (o['refund'] != null)
                _RefundChip(
                  refund: Map<String, dynamic>.from(o['refund'] as Map),
                ),
              if (o['refund'] == null && o['withdrawn'] == true)
                GlassCard(
                  child: Center(
                    child: Text(
                      'انتهت مهلة الاسترجاع/الاستبدال ⏳',
                      style: AppType.style(
                        11.5,
                        color: AppColors.muted,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (o['refund'] == null && o['withdrawn'] != true)
                SolidBtn(
                  label: 'طلب إرجاع أو استبدال ↩️🔁',
                  color: AppColors.danger,
                  onTap: () => _requestReturn(),
                ),
              const SizedBox(height: 10),
              SolidBtn(
                label: 'ممتاز؟ قيّم المتجر ⭐',
                color: AppColors.primaryLight,
                onTap: () => _rate(),
              ),
              if (o['refund'] == null &&
                  o['withdrawn'] != true &&
                  o['deadline'] != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '⏳ آخر مهلة: ${_fmtDeadline(o['deadline'])}',
                    style: AppType.style(
                      11,
                      color: AppColors.warning,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ],
          // إجراءات التاجر
          if (widget.role == 'vendor') ...[
            if (status == 'new')
              Row(
                children: [
                  Expanded(
                    child: SolidBtn(
                      label: 'تجهيز الطلب ✅',
                      onTap: () => _act(
                        '/api/vendor/orders/${widget.orderId}/status',
                        {'status': 'accept'},
                        'الطلب قيد التجهيز',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SolidBtn(
                      label: 'رفض',
                      color: AppColors.danger,
                      onTap: () => _act(
                        '/api/vendor/orders/${widget.orderId}/status',
                        {'status': 'reject'},
                        'انرفض الطلب',
                      ),
                    ),
                  ),
                ],
              ),
            if (status == 'preparing')
              SolidBtn(
                label: 'جاهز للتسليم 🎒',
                onTap: () => _act(
                  '/api/vendor/orders/${widget.orderId}/status',
                  {'status': 'ready'},
                  'في انتظار المندوب',
                ),
              ),
          ],
          // إجراءات المندوب — تخص الرحلة كلها (لو الطلب من أكثر من محل: الأزرار مرة واحدة للرحلة)
          if (widget.role == 'delivery') ...[
            if (trip == null)
              SolidBtn(
                label: 'الطلبات تأخذها من تبويب "متاح" 🛵',
                onTap: () => _loadTrip(),
              ),
            if (trip != null) ...[
              if ((trip['orders'] as List).length > 1) ...[
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذه الرحلة تضم ${(trip['orders'] as List).length} طلبات من ${(trip['orders'] as List).length} محلات — الزر يسري على الرحلة كلها 🛍',
                          style: AppType.style(11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (trip['picked_at'] == null)
                SolidBtn(
                  label: 'استلمت الطلب من المتجر 📦',
                  onTap: () async {
                    await _act('/api/delivery/pickup', {
                      'trip_id': (trip['id'] as num).toInt(),
                    }, 'انطلقت بالتوصيل');
                    _loadTrip();
                  },
                ),
              if (trip['picked_at'] != null && status != 'delivered')
                SolidBtn(
                  label: 'تم التسليم + قبض الكاش 💵',
                  onTap: () async {
                    await _act('/api/delivery/delivered', {
                      'trip_id': (trip['id'] as num).toInt(),
                    }, 'تم التسليم! عاشت إيدك 🎉');
                    _loadTrip();
                  },
                ),
              const SizedBox(height: 10),
              SolidBtn(
                label: 'خريطة التوصيل الحية 🗺️',
                color: AppColors.primaryLight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourierMapScreen(trip: trip),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _rate() async {
    int stars = 5;
    String? comment;
    await showSheet(
      context,
      StatefulBuilder(
        builder: (context, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetTitle('تقييم المتجر ⭐'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final s = i < stars;
                return IconButton(
                  onPressed: () => setS(() => stars = i + 1),
                  icon: Icon(
                    s ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 34,
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'شلون كانت تجربتك؟ (اختياري)',
                    ),
                    onChanged: (v) => comment = v,
                  ),
                  const SizedBox(height: 12),
                  SolidBtn(
                    label: 'إرسال التقييم',
                    onTap: () {
                      Navigator.pop(context);
                      _act(
                        '/api/customer/orders/${widget.orderId}/rate',
                        {
                          'rating': stars,
                          if (comment != null && comment!.isNotEmpty)
                            'comment': comment,
                        },
                        'شكراً لتقييمك ⭐',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestReturn() async {
    String type = 'return';
    String reason = '';
    int? exVariantId;
    String exLabel = '';
    final items = (o?['items'] ?? []) as List;
    // كل البدائل المتوفرة (بمخزون) من منتجات الطلب
    final alt = <Map>[];
    for (final it in items) {
      for (final v in (it['variants'] ?? <Map>[]).cast<Map>()) {
        if (((v['stock'] as num?)?.toInt() ?? 0) > 0) {
          alt.add({
            'variant_id': (v['id'] as num).toInt(),
            'label':
                '${v['color'] ?? ''}${(v['color'] ?? '').isNotEmpty ? ' · ' : ''}${v['name']}',
            'product': it['product_name'] ?? '',
          });
        }
      }
    }
    await showSheet(
      context,
      StatefulBuilder(
        builder: (context, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('إرجاع أو استبدال 🔁'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _typeBtn(
                      setS,
                      'return',
                      type,
                      () => type = 'return',
                      '↩️ إرجاع',
                      'أعيد القطعة للمحل',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeBtn(
                      setS,
                      'exchange',
                      type,
                      () => type = 'exchange',
                      '🔁 استبدال',
                      'أستبدلها بمقاس/لون آخر',
                    ),
                  ),
                ],
              ),
            ),
            if (type == 'exchange')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختار البديل المتوفر بالمخزون:',
                      style: AppType.style(12, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    for (final v in alt)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => setS(() {
                            exVariantId = v['variant_id'] as int;
                            exLabel = '${v['product']} — ${v['label']}';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: exVariantId == v['variant_id']
                                  ? AppColors.primary.withOpacity(0.12)
                                  : AppColors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: exVariantId == v['variant_id']
                                    ? AppColors.primary
                                    : AppColors.line,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 17,
                                  color: exVariantId == v['variant_id']
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${v['product']} — ${v['label']}',
                                    style: AppType.style(
                                      11.5,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (alt.isEmpty)
                      Text(
                        'ماكو بديل متوفر بالمخزون حالياً — جرب الإرجاع',
                        style: AppType.style(11, color: AppColors.danger),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'السبب (اختياري)...',
                    ),
                    onChanged: (v) => reason = v,
                  ),
                  const SizedBox(height: 12),
                  SolidBtn(
                    label: 'إرسال الطلب',
                    onTap: () {
                      if (type == 'exchange') {
                        if (exVariantId == null)
                          return toast(context, 'اختار البديل أولاً');
                      }
                      Navigator.pop(context);
                      _act(
                        '/api/customer/orders/${widget.orderId}/return',
                        {
                          'type': type,
                          'reason': reason,
                          if (type == 'exchange') 'variant_id': exVariantId,
                          if (type == 'exchange') 'desired': exLabel,
                        },
                        type == 'exchange'
                            ? 'انرسل طلب الاستبدال للتاجر 🔁'
                            : 'انرسل طلب الإرجاع للتاجر ↩️',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(
    StateSetter setS,
    String val,
    String cur,
    VoidCallback setter,
    String icon,
    String title,
  ) {
    return GestureDetector(
      onTap: () => setS(setter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cur == val ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cur == val ? AppColors.primary : AppColors.line,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppType.style(
                12,
                color: cur == val ? Colors.white : AppColors.ink,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDeadline(dynamic iso) {
    try {
      final d = DateTime.parse('$iso').toLocal();
      final now = DateTime.now();
      final rem = d.difference(now);
      if (rem.isNegative) return 'انتهت';
      if (rem.inHours < 24)
        return 'بعد ${rem.inHours} ساعة و ${rem.inMinutes % 60} دقيقة';
      return 'بعد ${rem.inDays} يوم (${d.day}/${d.month})';
    } catch (_) {
      return '';
    }
  }
}

/// حبة حالة طلب الإرجاع/الاستبدال
class _RefundChip extends StatelessWidget {
  final Map<String, dynamic> refund;
  const _RefundChip({required this.refund});

  @override
  Widget build(BuildContext context) {
    final st = '${refund['status'] ?? 'pending'}';
    final isEx = refund['type'] == 'exchange';
    final (color, label) = switch (st) {
      'accepted' => (
        AppColors.success,
        '${isEx ? 'الاستبدال' : 'الإرجاع'} مقبول ✓',
      ),
      'rejected' => (
        AppColors.danger,
        '${isEx ? 'الاستبدال' : 'الإرجاع'} مرفوض',
      ),
      _ => (
        AppColors.warning,
        '${isEx ? 'الاستبدال' : 'الإرجاع'} قيد المراجعة ⏳',
      ),
    };
    final desired = refund['desired'] ?? '';
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEx ? Icons.swap_horiz_rounded : Icons.replay_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppType.style(
                  12.5,
                  color: color,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (desired != null && desired.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'البديل المطلوب: $desired',
                style: AppType.style(
                  11.5,
                  color: AppColors.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
