import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders_screen.dart';
import 'login_screen.dart';

/// السلة — مرتبة حسب المتجر، مع إنشاء الطلب (كاش فقط)
class CartScreen extends StatefulWidget {
  final bool embedded;
  const CartScreen({super.key, this.embedded = false});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List cart = [];
  bool loading = true;
  final couponCtrl = TextEditingController();
  String appliedCoupon = '';
  int appliedCouponDiscount = 0;
  bool usePoints = false;
  DateTime? scheduled;
  String? groupError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('CART_LOAD start logged=${Api.logged}');
    if (!Api.logged) {
      if (mounted) setState(() { cart = List.from(AppState.i.guestCart); loading = false; });
      print('CART_LOAD guest mode, guestCart=${AppState.i.guestCart.length}');
      return;
    }
    try {
      final d = await Api.get('/api/customer/cart');
      cart = d['cart'] ?? d['items'] ?? [];
      print('CART_LOAD ok items=${cart.length} first=${(cart.isEmpty ? null : cart[0])}');
    } catch (e) {
      print('CART_LOAD ERROR: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _applyCoupon(int storeId, double subtotal) async {
    try {
      final d = await Api.post('/api/customer/cart/apply-coupon', {'store_id': storeId, 'code': couponCtrl.text, 'subtotal': subtotal.toInt()});
      setState(() {
        appliedCoupon = d['code'];
        appliedCouponDiscount = d['discount'];
      });
      toast(context, 'خلصان الكوبون ✓ خصم ${money(appliedCouponDiscount)}');
    } on ApiException catch (e) {
      setState(() => appliedCoupon = '');
      toast(context, e.message, error: true);
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 14)));
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: now.hour.clamp(8, 22), minute: 0));
    if (t == null) return;
    setState(() => scheduled = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> setQty(int id, int qty) async {
    if (!Api.logged) {
      final i = AppState.i.guestCart.indexWhere((e) => e['id'] == id);
      if (i >= 0) AppState.i.guestCart[i]['qty'] = qty;
      await _load();
      return;
    }
    try {
      await Api.patch('/api/customer/cart', {'item_id': id, 'qty': qty});
      await _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  Future<void> removeItem(int id) async {
    if (!Api.logged) {
      AppState.i.guestCart.removeWhere((e) => e['id'] == id);
      AppState.i.cartCount.value = AppState.i.guestCart.length;
      await _load();
      return;
    }
    try {
      await Api.del('/api/customer/cart/$id');
      await _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  // ── سلة موحدة: اطلب من كل المتاجر دفعة واحدة (group_id مشترك) ──
  Future<void> placeGroupOrder(List<Map> groups) async {
    if (!Api.logged) {
      toast(context, 'سجل دخولك أول', error: true);
      return;
    }
    final picked = await _pickAddress();
    if (picked.$1 == null && picked.$2 == null) return;
    if (!mounted) return;
    final gid = DateTime.now().millisecondsSinceEpoch.toString();
    var done = 0;
    for (final g in groups) {
      try {
        await Api.post('/api/customer/orders', {
          'store_id': g['store_id'],
          'address': picked.$1,
          if (picked.$2 != null) 'address_id': picked.$2,
          'group_id': gid,
          'scheduled_at': scheduled?.toUtc().toIso8601String(),
        });
        done++;
      } catch (_) {}
    }
    if (!mounted) return;
    toast(context, done > 0 ? 'انطلقت طلباتك ($done) بموعد واحد 🎉' : 'ما انطلق أي طلب', error: done == 0);
    if (done > 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListScreen(role: 'customer', initialCode: null)));
      _load();
    }
  }

  Future<(String?, int?)> _pickAddress() async {
    String? addr;
    int? addrId;
    try {
      final d = await Api.get('/api/customer/addresses');
      final addresses = (d['addresses'] ?? []) as List;
      String? selected = addresses.isEmpty ? null : addresses.first['address'];
      int? selectedId = addresses.isEmpty ? null : (addresses.first['id'] as num).toInt();
      await showSheet(context, StatefulBuilder(
        builder: (context, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetTitle('عنوان التوصيل 📍'),
          if (addresses.isNotEmpty)
            for (final a in addresses)
              RadioListTile<String>(
                value: a['address'],
                groupValue: selected,
                activeColor: A.primary,
                title: Text(a['address'], style: A.t(13.5)),
                onChanged: (v) => setS(() {
                  selected = v;
                  addrId = (a['id'] as num).toInt();
                }),
              )
          else
            const Padding(padding: EdgeInsets.all(16), child: Text('لا عناوين — أضف عنوانك', style: TextStyle(color: A.muted))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                decoration: const InputDecoration(hintText: 'أو أضف عنوان جديد: حي، زقاق، علامة مميزة'),
                onChanged: (v) => setS(() {
                  addr = v;
                  if (v.isNotEmpty) addrId = null;
                }),
              ),
              const SizedBox(height: 12),
              SolidBtn(
                label: 'تأكيد',
                onTap: () => Navigator.pop(context, ((addr != null && addr!.isNotEmpty) ? addr : selected, addrId)),
              ),
            ]),
          ),
        ]),
      ));
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
    return (null, null);
  }

  Widget _itemRow(dynamic it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: A.glass(radius: 15, soft: true),
        child: Row(children: [
          productImage(it['image'], size: 50, radius: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it['product_name'] ?? it['name'] ?? '',
                  style: A.t(12.5, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (it['variant'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text(it['variant'].toString(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: A.primary)),
                )
              else
                const SizedBox(height: 3),
              Row(children: [
                Text('${money((it['price'] ?? 0))}', style: A.t(12.5, c: A.accent, w: FontWeight.w900)),
                const SizedBox(width: 7),
                Text('الكمية ×${it['qty'] ?? 1}', style: A.t(10, c: A.muted, w: FontWeight.w700)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            GestureDetector(
              onTap: () => removeItem(it['id']),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: A.danger.withOpacity(0.09), borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded, size: 15, color: A.danger),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () => setQty(it['id'], (it['qty'] ?? 1) - 1).then((_) => ((it['qty'] ?? 1) <= 1) ? removeItem(it['id']) : null),
                child: Container(
                  width: 26, height: 26,
                  decoration: A.glass(radius: 9, soft: true),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 15, color: A.muted),
                ),
              ),
              SizedBox(
                width: 30,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(color: A.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                    child: Text('${it['qty']}', textAlign: TextAlign.center, style: A.t(12.5, w: FontWeight.w900)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setQty(it['id'], (it['qty'] ?? 1) + 1),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(gradient: A.gradNavy, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _storeGroup(Map g) {
    final items = (g['items'] as List);
    final subtotal = items.fold<double>(0.0, (sum, it) => sum + ((it['price'] ?? 0) * (it['qty'] ?? 1)).toDouble());
    final fee = (items.first['delivery_fee'] ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: A.glass(radius: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          storeLogo(g['logo'] ?? '', size: 36, radius: 11),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['store_name'] ?? '', style: A.t(13, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                const VerifiedTag(),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: A.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delivery_dining_rounded, size: 12, color: A.cyan),
                    const SizedBox(width: 4),
                    Text('توصيل ${money(fee)}', style: A.t(9.5, c: A.cyan, w: FontWeight.w800)),
                  ]),
                ),
              ]),
            ]),
          ),
          Text(money(subtotal.toInt()), style: A.t(13, c: A.primary, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 11),
        for (final it in items) _itemRow(it),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تجميع حسب المتجر
    final groups = <int, Map>{};
    for (final it in cart) {
      final sid = (it['store_id'] as num?)?.toInt() ?? 0;
      groups.putIfAbsent(sid, () => {'store_id': sid, 'store_name': it['store_name'], 'logo': it['logo'], 'items': <dynamic>[]});
      groups[sid]!['items'].add(it);
    }
    final groupList = groups.values.toList();
    debugPrint('CART_BUILD cart=${cart.length} groups=${groupList.length}');
    double total = 0;
    for (final it in cart) {
      total += (double.tryParse('${it['price'] ?? 0}') ?? 0.0) * (double.tryParse('${it['qty'] ?? 1}') ?? 1.0);
    }

    final bodyWidget = loading
        ? const Loader()
        : cart.isEmpty
            ? const EmptyState(icon: '🛒', title: 'سلتك فاضية', sub: 'روح للمتاجر وضيف شي تحبه')
            : RefreshIndicator(
                onRefresh: _load,
                color: A.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    for (final g in groupList) _storeGroup(g),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        onTap: _pickSchedule,
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: A.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
                            child: const Icon(Icons.schedule_rounded, color: A.cyan, size: 20),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('جدولة التوصيل 🕐', style: A.t(13, w: FontWeight.w900)),
                              Text(scheduled == null
                                  ? 'الآن (عاجل) — أو اضغط للجدولة'
                                  : '${scheduled!.day}/${(scheduled!.month).toString().padLeft(2, '0')} ${scheduled!.hour.toString().padLeft(2, '0')}:${scheduled!.minute.toString().padLeft(2, '0')}',
                                  style: A.t(11, c: A.muted)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );

    final bar = (loading || cart.isEmpty)
        ? null
        : Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.9), width: 1)),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: couponCtrl,
                        onSubmitted: (v) => v.isNotEmpty ? _applyCoupon(groupList.isEmpty ? 0 : (groupList.first['store_id'] as num).toInt(), total) : null,
                        decoration: InputDecoration(
                          hintText: appliedCoupon.isEmpty ? '🎟️ عندك كود كوبون للسلة كلها؟' : 'كوبون ${appliedCoupon} مطبق ✓',
                          hintStyle: A.t(10.5, c: appliedCoupon.isEmpty ? A.muted : A.success, w: FontWeight.w700),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.8),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => couponCtrl.text.isNotEmpty ? _applyCoupon(groupList.isEmpty ? 0 : (groupList.first['store_id'] as num).toInt(), total) : null,
                        child: Ink(
                          width: 100,
                          height: 47,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [A.primaryDeep, A.primary]),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [BoxShadow(color: A.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: Text(appliedCoupon.isEmpty ? 'تطبيق' : '✓',
                                style: A.t(14.5, c: Colors.white, w: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  if (appliedCoupon.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: A.success),
                        const SizedBox(width: 5),
                        Text('خصم ${money(appliedCouponDiscount)} من إجمالي السلة', style: A.t(10, c: A.success, w: FontWeight.w800)),
                      ]),
                    ),
                  ],
                  if (Api.me != null && (Api.me?['points'] ?? 0) >= 100) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 15, color: A.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('استخدم نقاطي (${Api.me?['points']}) — يوفر ${money((((Api.me?['points'] ?? 0) ~/ 100) * 1000).toDouble())}',
                            style: A.t(10, c: A.muted, w: FontWeight.w700)),
                      ),
                      Switch(
                        value: usePoints,
                        activeColor: A.warning,
                        activeTrackColor: A.warning.withOpacity(0.35),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => setState(() => usePoints = v),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('الإجمالي', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                        Row(children: [
                          Text(money(total), style: A.t(19, c: A.ink, w: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: A.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text('${cart.length} صنف', style: A.t(10, c: A.warning, w: FontWeight.w800)),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text('دفع كاش عند الاستلام 💵', style: A.t(10, c: A.success, w: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => placeGroupOrder(groupList),
                        child: Ink(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [A.primary, Color(0xFF3B82F6)]),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: A.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Center(
                              child: Text('إتمام الطلب ✓',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          const SizedBox(height: 132),
          Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 56,
                child: Row(children: [
                  Text('السلة 🛒', style: A.t(18, w: FontWeight.w900)),
                  const Spacer(),
                  if (!loading && cart.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: A.glass(radius: 999, soft: true),
                      child: Text('${cart.length} صنف', style: A.t(11.5, c: A.primary, w: FontWeight.w900)),
                    ),
                ]),
              ),
            ),
          ),
          Expanded(child: bodyWidget),
          if (bar != null) bar,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('السلة 🛒')),
      body: bodyWidget,
      bottomNavigationBar: bar,
    );
  }
}
