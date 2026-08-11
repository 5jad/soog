import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customer_shell.dart';
import 'cart_screen.dart';

/// صفحة المتجر: الحالة + التوصيل + كوبونات + عروض + منتجات + تقييمات + تواصل
class StoreScreen extends StatefulWidget {
  final int storeId;
  const StoreScreen({super.key, required this.storeId});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  dynamic store;
  List products = [];
  List variants = [];
  List reviews = [];
  List coupons = [];
  Map ratingBreakdown = {};
  bool loading = true;
  int catSel = -1;
  List cats = [];
  String q = '';
  bool followed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/stores/${widget.storeId}');
      store = d['store'];
      products = d['products'] ?? [];
      variants = d['variants'] ?? [];
      reviews = d['reviews'] ?? [];
      coupons = d['coupons'] ?? [];
      ratingBreakdown = d['rating_breakdown'] ?? {};
      cats = (products.map((p) => p['category_name']).whereType<String>().toSet().toList()).cast<String>();
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
    if (Api.logged) {
      try {
        final fav = await Api.get('/api/customer/store-favorites');
        final list = (fav['favorites'] ?? []) as List;
        if (mounted) setState(() => followed = list.any((e) => (e['store_id'] as num).toInt() == widget.storeId));
      } catch (_) {}
    }
  }

  List get shown {
    var list = products;
    if (catSel >= 0) list = list.where((p) => p['category_name'] == cats[catSel]).toList();
    if (q.trim().isNotEmpty) list = list.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(q.trim().toLowerCase())).toList();
    return list;
  }

  List get offerProducts => products.where((p) => p['has_offer'] == true || p['has_offer'] == 1).toList();

  Future<void> addToCart(int productId, int qty, [String? variant]) async {
    if (!Api.logged) {
      toast(context, 'سجل دخولك أول 🛒', error: true);
      return;
    }
    try {
      await Api.post('/api/customer/cart', {
        'product_id': productId,
        'qty': qty,
        if (variant != null) 'variant': variant,
      });
      AppState.i.setCart(AppState.i.cartCount.value + 1);
      if (!mounted) return;
      // زر «+» السريع: يفتح السلة مباشرة بعد الإضافة
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleFollow() async {
    if (!Api.logged) {
      toast(context, 'سجل دخولك لمتابعة المتجر', error: true);
      return;
    }
    try {
      final d = await Api.post('/api/customer/store-favorites', {'store_id': widget.storeId});
      setState(() => followed = (d['favorite'] ?? d['ok']) == true || d['favorite'] == 1);
    } catch (_) {}
  }

  String _couponLabel(Map c) {
    final code = c['code'] ?? '';
    if (c['percent'] != null) return '$code · خصم ${c['percent']}%';
    if (c['flat'] != null) return '$code · ${c['flat']} د.ع';
    return code;
  }

  bool _isUrlCover(String v) =>
      v.startsWith('http') || v.startsWith('/uploads') || v.startsWith('data:') || v.startsWith('/9j');

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Loader());
    if (store == null) return const Scaffold(body: EmptyState(icon: '🏪', title: 'المتجر غير موجود'));
    final s = store as Map;

    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: _load,
          color: A.primary,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ═══════ الهيدر ═══════
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 50, 16, 18),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(gradient: A.gradNavy),
                child: Stack(children: [
                  if (s['cover'] != null && _isUrlCover(s['cover'].toString()))
                    Positioned.fill(
                      child: productImageBox(s['cover'].toString()),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.15)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Column(children: [
                  Row(children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: storeLogo(s['logo'] ?? '', size: 66, radius: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Flexible(child: Text(s['name'] ?? '', style: A.t(19, c: Colors.white, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (s['verified'] == true || s['verified'] == 1) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.verified_rounded, size: 17, color: A.primaryLight)),
                        ]),
                        Text('${s['category_name'] ?? ''}', style: A.t(12, c: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 15),
                            Text(' ${(s['rating'] ?? 0).toStringAsFixed(1)} (${s['reviews_count'] ?? 0})', style: A.t(11.5, c: Colors.white, w: FontWeight.w800)),
                            Text('  ·  ${s['verified'] == true || s['verified'] == 1 ? 'متجر موثوق' : 'محل محلي'}', style: A.t(10.5, c: Colors.white.withOpacity(0.8))),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 48),
                  ]),
                  // الحالة + الكوبونات السريعة
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _statusChip(s),
                    const SizedBox(width: 8),
                    if (s['warranty_days'] != null) ...[
                      _chip(Icons.verified_user_rounded, 'ضمان ${s['warranty_days']} يوم', A.success),
                      const SizedBox(width: 8),
                    ],
                  ]),
                ]),
              ]),
              ),
            ),
            // ═══════ شريط التوصيل ═══════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: Row(children: [
                    _infoIcon(Icons.delivery_dining_rounded, 'توصيل', s['delivery_fee'] != null ? money((s['delivery_fee'] ?? 0).toDouble()) : '—', A.primary),
                    const _vdiv(),
                    _infoIcon(Icons.card_giftcard_rounded, 'مجاني فوق', s['free_delivery_min'] != null ? money((s['free_delivery_min'] ?? 0).toDouble()) : '—', A.accent),
                    const _vdiv(),
                    _infoIcon(Icons.storefront_rounded, 'العدوان', '${(s['open_time'] ?? '')} - ${(s['close_time'] ?? '')}', A.cyan),
                  ]),
                ),
              ),
            ),
            // ═══════ أزرار تواصل ═══════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  _actionBtn(Icons.map_rounded, 'الموقع', () => _launch(s['location_url'] ?? '')),
                  _actionBtn(followed ? Icons.favorite_rounded : Icons.favorite_border_rounded, followed ? 'متابع' : 'متابعة', _toggleFollow, highlighted: followed),
                ]),
              ),
            ),
            // ═══════ كوبونات المتجر ═══════
            if (coupons.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🎟 كوبونات المتجر', style: A.t(13, c: A.muted, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final c in coupons) ...[
                            GestureDetector(
                              onTap: () => _showCoupon(c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  gradient: A.gradSun,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.confirmation_number_rounded, size: 15, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(_couponLabel(c), style: A.t(11.5, c: Colors.white, w: FontWeight.w900)),
                                ]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            // ═══════ البحث جوة المتجر ═══════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث في المتجر...',
                    prefixIcon: const Icon(Icons.search_rounded, color: A.muted, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            // ═══════ عروض المتجر (أفقية) ═══════
            if (offerProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🔥 عروض المتجر', style: A.t(13, c: A.muted, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in offerProducts)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _offerCard(p),
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            // ═══════ التصنيفات ═══════
            if (cats.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                  child: SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(label: const Text('الكل'), selected: catSel < 0, onSelected: (_) => setState(() => catSel = -1)),
                        ),
                        ...cats.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(label: Text(e.value), selected: catSel == e.key, onSelected: (_) => setState(() => catSel = catSel == e.key ? -1 : e.key)),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            // ═══════ المنتجات ═══════
            if (shown.isEmpty)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 60), child: EmptyState(icon: '📦', title: 'لا منتجات بعد')))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: 0.55,
                  ),
delegate: SliverChildBuilderDelegate((_, i) {
                    final p = shown[i];
                    return GlassCard(
                      onTap: () => pushProduct(context, widget.storeId, (p['id'] as num).toInt()),
                      radius: 0,
                      padding: EdgeInsets.zero,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Stack(fit: StackFit.expand, children: [
                            productImageBox(p['image']),
                            if (p['has_offer'] == true || p['has_offer'] == 1)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(gradient: A.gradSun, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    'خصم ${_displayPrice(p) > 0 && (p['price'] ?? 0) > 0 ? (((p['price'] as num) - _displayPrice(p)) / (p['price'] as num) * 100).round() : 0}%',
                                    style: A.t(9.5, c: Colors.white, w: FontWeight.w900),
                                  ),
                                ),
                              ),
                            if ((p['stock'] ?? 0) <= 0)
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xDD0A1120), borderRadius: BorderRadius.circular(8)),
                                  child: Text('نفد', style: A.t(9.5, c: Colors.white, w: FontWeight.w900)),
                                ),
                              ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['name'] ?? '', style: A.t(11, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if ((p['has_offer'] == true || p['has_offer'] == 1)) ...[
                              const SizedBox(height: 2),
                              Text(money(p['price']), style: A.t(9.5, c: A.muted, decoration: TextDecoration.lineThrough), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 2),
                            Row(children: [
                              Expanded(child: Text(money(_displayPrice(p)), style: A.t(13.5, c: A.accent, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              GestureDetector(
                                onTap: (p['stock'] ?? 0) <= 0
                                    ? null
                                    : () {
                                        final hasVariant = variants.any((v) => (v['product_id'] as num? ?? 0).toInt() == (p['id'] as num).toInt());
                                        if (hasVariant) {
                                          pushProduct(context, widget.storeId, (p['id'] as num).toInt());
                                        } else {
                                          addToCart((p['id'] as num).toInt(), 1);
                                        }
                                      },
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: A.primary, borderRadius: BorderRadius.circular(9)),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    );
                  }, childCount: shown.length),
                ),
              ),
            // ═══════ التقييمات ═══════
            if (reviews.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('⭐ التقييمات (${reviews.length})', style: A.t(13, c: A.muted, w: FontWeight.w800)),
                      const Spacer(),
                      Text((s['rating'] ?? 0).toStringAsFixed(1), style: A.t(14, c: A.ink, w: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 8),
                    // توزيع النجوم
                    if (ratingBreakdown.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          for (var r = 5; r >= 1; r--)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Text('$r ★', style: A.t(11, c: A.muted, w: FontWeight.w800)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: reviews.isEmpty ? 0 : (ratingBreakdown['$r'] ?? 0) / reviews.length,
                                      minHeight: 6,
                                      backgroundColor: A.bg,
                                      color: const Color(0xFFFBBF24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${ratingBreakdown['$r'] ?? 0}', style: A.t(10.5, c: A.muted)),
                              ]),
                            ),
                        ]),
                      ),
                    for (final rev in reviews.take(4))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(radius: 11, backgroundColor: A.primaryLight.withOpacity(0.2),
                                child: Text((rev['user_name'] ?? '؟').toString().characters.first, style: A.t(11, w: FontWeight.w900))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rev['user_name'] ?? 'زبون', style: A.t(12, w: FontWeight.w800))),
                            Text(_stars(rev['rating'] ?? 0), style: A.t(11, c: const Color(0xFFFBBF24))),
                          ]),
                          if ((rev['comment'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(rev['comment'], style: A.t(12, c: A.muted, h: 1.5)),
                          ],
                        ]),
                      ),
                  ]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
      ]),
    );
  }

  // ── مساعدات UI ──
  Widget _statusChip(Map s) {
    if (s['on_vacation'] == true) return _chip(Icons.beach_access_rounded, 'ويا إجازة', A.warning);
    final open = s['is_open'] == true || s['is_open'] == 1;
    return _chip(open ? Icons.check_circle_rounded : Icons.cancel_rounded, open ? 'مفتوح' : 'مغلق', open ? A.success : A.danger);
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(label, style: A.t(10.5, c: color, w: FontWeight.w800)),
      ]),
    );
  }

  Widget _infoIcon(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: A.t(12, w: FontWeight.w900)),
        Text(label, style: A.t(9.5, c: A.muted)),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {bool highlighted = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: highlighted ? A.primary.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: highlighted ? A.primary : A.primary, size: 20),
                const SizedBox(height: 4),
                Text(label, style: A.t(10, w: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offerCard(Map p) {
    return GestureDetector(
      onTap: () => pushProduct(context, widget.storeId, (p['id'] as num).toInt()),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: productImage(p['image'], size: 56, radius: 10)),
          const SizedBox(height: 6),
          Text(p['name'] ?? '', style: A.t(11), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(money(_displayPrice(p)), style: A.t(12, c: A.accent, w: FontWeight.w900)),
          if ((p['price'] ?? 0) > _displayPrice(p))
            Text(money((p['price'] ?? 0).toDouble()), style: A.t(9.5, c: A.muted, decoration: TextDecoration.lineThrough)),
          GestureDetector(
            onTap: () => addToCart((p['id'] as num).toInt(), 1),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: A.primary, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add_shopping_cart_rounded, size: 13, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  String _stars(dynamic rating) => '★' * ((rating as num?)?.toInt() ?? 0).clamp(0, 5);

  double _displayPrice(Map p) {
    final off = p['offer_price'];
    // Swift conversions: p['price'] can be num
    if (off != null) return (off as num).toDouble();
    return ((p['price'] ?? 0) as num).toDouble();
  }

  Future<void> _launch(String url) async {
    if (url.isEmpty) {
      toast(context, 'لا رابط متاح', error: true);
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      toast(context, 'تعذر الفتح', error: true);
    }
  }

  void _showCoupon(Map c) {
    Clipboard.setData(ClipboardData(text: (c['code'] ?? '').toString()));
    showSheet(context, Column(mainAxisSize: MainAxisSize.min, children: [
      const SheetTitle('🎟 كوبون المتجر'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 26),
        child: Column(children: [
          Text((c['code'] ?? '').toString(), style: A.t(22, c: A.accent, w: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_couponLabel(c), style: A.t(13, c: A.muted)),
          const SizedBox(height: 12),
          Text('نسخناه — استخدمه عند الدفع بالسلة 🛒', style: A.t(11, c: A.muted)),
        ]),
      ),
    ]));
  }
}

class _vdiv extends StatelessWidget {
  const _vdiv();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, color: A.line);
}