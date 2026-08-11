import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../map_screen.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders_screen.dart';
import 'order_success_screen.dart';

/// السلة — مرتبة حسب المتجر، مع إنشاء الطلب (كاش فقط)
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List cart = [];
  bool loading = true;
  final couponCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String appliedCoupon = '';
  int appliedCouponDiscount = 0;
  bool usePoints = false;
  String? groupError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Api.logged) {
      if (mounted) setState(() { cart = List.from(AppState.i.guestCart); loading = false; });
      AppState.i.setCart(AppState.i.guestCart.length);
      print('CART_LOAD guest mode, guestCart=${AppState.i.guestCart.length}');
      return;
    }
    try {
      final d = await Api.get('/api/customer/cart');
      cart = d['cart'] ?? d['items'] ?? [];
      AppState.i.setCart(cart.length);
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
      AppState.i.setCart(AppState.i.guestCart.length);
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
        });
        done++;
      } catch (_) {}
    }
    if (!mounted) return;
    if (done > 0) {
      AppState.i.setCart(0);
      await _load();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(done: done)),
      );
    } else {
      toast(context, 'ما انطلق أي طلب — جرب مرة ثانية', error: true);
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
      final picked = await showSheet(context, StatefulBuilder(
        builder: (context, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetTitle('عنوان التوصيل 📍'),
            if (addresses.isNotEmpty) ...[
              const Text('اختر من العناوين المحفوظة',
                  style: TextStyle(color: A.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final a in addresses)
                GestureDetector(
                  onTap: () => setS(() {
                    selected = a['address'];
                    addrId = (a['id'] as num).toInt();
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: selected == a['address'] ? const Color(0xFFEEF4FB) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected == a['address'] ? A.primary : A.line, width: selected == a['address'] ? 1.6 : 1),
                    ),
                    child: Row(children: [
                      Icon(
                        selected == a['address'] ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: selected == a['address'] ? A.primary : const Color(0xFFC9CDD6),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a['address'],
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: selected == a['address'] ? A.primary : A.text)),
                      ),
                    ]),
                  ),
                ),
              const Divider(height: 26, color: A.line),
              const Text('أو حدد موقعك / أضف عنوان جديد',
                  style: TextStyle(color: A.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
            ] else
              const Padding(padding: EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('لا عناوين محفوظة — حدد موقعك من الخريطة', style: TextStyle(color: A.muted, fontSize: 12.5))),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: A.primary,
                side: const BorderSide(color: A.primary, width: 1.3),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final p = await Navigator.push<LatLng>(context,
                    MaterialPageRoute(builder: (_) => const PickMapScreen()));
                if (p == null || !context.mounted) return;
                addressCtrl.text = '📍 موقع محدد (${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)})';
                if (mounted) Navigator.pop(context, (addressCtrl.text, null));
              },
              icon: const Icon(Icons.location_on_outlined, size: 20),
              label: const Text('حدد موقعي على الخريطة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'أو اكتب عنواناً جديداً: حي، زقاق، علامة مميزة',
                hintStyle: TextStyle(color: A.muted.withValues(alpha: .7), fontSize: 12.5, fontWeight: FontWeight.w600),
                prefixIcon: const Icon(Icons.edit_location_alt_outlined, color: A.primary, size: 20),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: A.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: A.line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: A.primary, width: 1.6)),
              ),
              onChanged: (v) => setS(() {
                addr = v;
                if (v.isNotEmpty) addrId = null;
              }),
            ),
            const SizedBox(height: 16),
            SolidBtn(
              label: (addr != null && addr!.isNotEmpty) || selected != null ? 'إتمام الطلب ✓' : 'اختر عنوان التوصيل',
              color: A.accent,
              disabled: (addr == null || addr!.isEmpty) && selected == null,
              onTap: () => Navigator.pop(context, ((addr != null && addr!.isNotEmpty) ? addr : selected, addrId)),
            ),
          ]),
        ),
      ));
      if (picked is (String?, int?)?) {
        final p = picked as (String?, int?)?;
        if (p != null) return p;
      }
      return ((addr != null && addr!.isNotEmpty) ? addr : selected, addrId ?? selectedId);
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
    return (null, null);
  }

  Widget _itemRow(dynamic it) {
    final price = (it['price'] ?? 0);
    final qty = (it['qty'] ?? 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          productImage(it['image'], size: 58, radius: 14),
          const SizedBox(width: 11),
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
                ),
              const SizedBox(height: 8),
              Row(children: [
                Text('${money(price)}', style: A.t(13.5, c: A.accent, w: FontWeight.w900)),
                if (qty > 1) ...[
                  const SizedBox(width: 6),
                  Text('×$qty', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                ],
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
            const Spacer(),
            Row(children: [
              GestureDetector(
                onTap: () => setQty(it['id'], qty - 1).then((_) => (qty <= 1) ? removeItem(it['id']) : null),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: A.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: A.line)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 15, color: A.muted),
                ),
              ),
              Container(
                width: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(color: A.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                child: Text('$qty', textAlign: TextAlign.center, style: A.t(12.5, w: FontWeight.w900)),
              ),
              GestureDetector(
                onTap: () => setQty(it['id'], qty + 1),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          storeLogo(g['logo'] ?? '', size: 38, radius: 11),
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
        ]),
        const SizedBox(height: 11),
        for (final it in items) _itemRow(it),
        const Divider(height: 1, color: A.line),
        const SizedBox(height: 5),
        Row(children: [
          Text('مجموع المتجر', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
          const Spacer(),
          Text(money(subtotal.toInt()), style: A.t(13.5, c: A.primary, w: FontWeight.w900)),
        ]),
      ]),
    );
  }

  /// بطاقة خيار صغيرة في شريط السلة
  Widget _optTile({required IconData icon, required Color color, required String title, required String sub, VoidCallback? onTap, Widget? trailing}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: A.t(10.5, c: A.ink, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: A.t(9, c: A.muted, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      ),
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
    double total = 0;
    for (final it in cart) {
      total += (double.tryParse('${it['price'] ?? 0}') ?? 0.0) * (double.tryParse('${it['qty'] ?? 1}') ?? 1.0);
    }
    double deliveryTotal = 0;
    for (final g in groupList) {
      final items = (g['items'] as List);
      if (items.isNotEmpty) deliveryTotal += ((items.first['delivery_fee'] ?? 0) as num).toDouble();
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
                  ],
                ),
              );

    final bar = (loading || cart.isEmpty)
        ? null
        : Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.9), width: 1)),
              boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 22, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // الجدولة أزيلت — بقي خيار النقاط فقط
                  Row(children: [
                    if (Api.me != null && (Api.me?['points'] ?? 0) >= 100) ...[
                      Expanded(
                        child: _optTile(
                          icon: Icons.star_rounded,
                          color: A.warning,
                          title: 'نقاطي (${Api.me?['points']})',
                          sub: 'توفر ${money((((Api.me?['points'] ?? 0) ~/ 100) * 1000).toDouble())}',
                          trailing: Switch(
                            value: usePoints,
                            activeColor: A.warning,
                            activeTrackColor: A.warning.withOpacity(0.35),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) => setState(() => usePoints = v),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  // الكوبون
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: couponCtrl,
                        onSubmitted: (v) => v.isNotEmpty ? _applyCoupon(groupList.isEmpty ? 0 : (groupList.first['store_id'] as num).toInt(), total) : null,
                        decoration: InputDecoration(
                          hintText: appliedCoupon.isEmpty ? '🎟️ كود كوبون؟' : 'كوبون ${appliedCoupon} مطبق ✓',
                          hintStyle: A.t(11, c: appliedCoupon.isEmpty ? A.muted : A.success, w: FontWeight.w700),
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
                          width: 92,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [A.primaryDeep, A.primary]),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: Text(appliedCoupon.isEmpty ? 'تطبيق' : '✓',
                                style: A.t(14, c: Colors.white, w: FontWeight.w900)),
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
                        const Icon(Icons.check_circle_rounded, size: 14, color: A.success),
                        const SizedBox(width: 5),
                        Text('خصم ${money(appliedCouponDiscount)} من السلة', style: A.t(10, c: A.success, w: FontWeight.w800)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 9),
                  // الخلاصة النهائية
                  Container(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                    decoration: BoxDecoration(color: A.bg.withOpacity(0.75), borderRadius: BorderRadius.circular(14), border: Border.all(color: A.line)),
                    child: Column(children: [
                      Row(children: [
                        Text('المجموع الفرعي', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                        const Spacer(),
                        Text(money(total), style: A.t(11.5, c: A.ink, w: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('التوصيل (${groupList.length} متجر)', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                        const Spacer(),
                        Text(deliveryTotal <= 0 ? 'مجاني 🎉' : money(deliveryTotal),
                            style: A.t(11.5, c: deliveryTotal <= 0 ? A.success : A.ink, w: FontWeight.w800)),
                      ]),
                      if (appliedCoupon.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('الكوبون', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                          const Spacer(),
                          Text('-${money(appliedCouponDiscount)}', style: A.t(11.5, c: A.success, w: FontWeight.w800)),
                        ]),
                      ],
                      const Divider(height: 12, color: A.line),
                      Row(children: [
                        Text('الإجمالي', style: A.t(12.5, c: A.ink, w: FontWeight.w900)),
                        const Spacer(),
                        Text(money(total + deliveryTotal - appliedCouponDiscount), style: A.t(19, c: A.ink, w: FontWeight.w900)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('${cart.length} صنف · دفع كاش عند الاستلام 💵', style: A.t(9.5, c: A.success, w: FontWeight.w800)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 9),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => placeGroupOrder(groupList),
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          color: A.accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: A.accent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: const Center(
                          child: Text('إتمام الطلب ✓ — ادفع عند الاستلام',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 14,
        title: const Text('السلة 🛒', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: bodyWidget,
      bottomNavigationBar: bar,
    );
  }
}
