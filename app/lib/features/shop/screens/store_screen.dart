import 'package:flutter/material.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/auth/screens/login_screen.dart';
import 'package:zaboon/features/cart_checkout/screens/cart_screen.dart';

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
      cats =
          (products
                  .map((p) => p['category_name'])
                  .whereType<String>()
                  .toSet()
                  .toList())
              .cast<String>();
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (Api.logged) {
      try {
        final fav = await Api.get('/api/customer/store-favorites');
        final list = (fav['favorites'] ?? []) as List;
        if (mounted)
          setState(
            () => followed = list.any(
              (e) => (e['store_id'] as num).toInt() == widget.storeId,
            ),
          );
      } catch (_) {}
    }
  }

  List get shown {
    var list = products;
    if (catSel >= 0)
      list = list.where((p) => p['category_name'] == cats[catSel]).toList();
    if (q.trim().isNotEmpty)
      list = list
          .where(
            (p) => (p['name'] ?? '').toString().toLowerCase().contains(
              q.trim().toLowerCase(),
            ),
          )
          .toList();
    return list;
  }

  List get offerProducts => products
      .where((p) => p['has_offer'] == true || p['has_offer'] == 1)
      .toList();

  Future<void> addToCart(int productId, int qty, [String? variant]) async {
    if (!Api.logged) {
      // الضيف يضيف للسلة المحلية — الطلب فقط يتطلب تسجيل
      final existing = AppState.i.guestCart.indexWhere(
        (e) => e['product_id'] == productId,
      );
      if (existing >= 0) {
        AppState.i.guestCart[existing]['qty'] += qty;
      } else {
        Map p = {};
        for (final pr in products) {
          if ((pr['id'] as num).toInt() == productId) {
            p = Map<String, dynamic>.from(pr as Map);
            break;
          }
        }
        AppState.i.guestCart.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'store_id': widget.storeId,
          'store_name': store?['name'] ?? 'متجر',
          'logo': store?['logo'] ?? '',
          'product_id': productId,
          'product_name': p['name'],
          'image': p['image'],
          'price': (p['has_offer'] == true || p['has_offer'] == 1)
              ? p['offer_price']
              : p['price'],
          'qty': qty,
          'variant': variant,
        });
      }
      AppState.i.setCart(cartTotalQty(AppState.i.guestCart));
      addPop(context);
      return;
    }
    try {
      await Api.post('/api/customer/cart', {
        'product_id': productId,
        'qty': qty,
        if (variant != null) 'variant': variant,
      });
      AppState.i.setCart(AppState.i.cartCount.value + qty);
      if (!mounted) return;
      // زر «+» السريع: يفتح السلة مباشرة بعد الإضافة
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleFollow() async {
    if (!Api.logged) {
      toast(context, 'سجّل دخولك لمتابعة المتجر', error: true);
      openLoginScreen(context);
      return;
    }
    try {
      final d = await Api.post('/api/customer/store-favorites', {
        'store_id': widget.storeId,
      });
      setState(
        () =>
            followed = (d['favorite'] ?? d['ok']) == true || d['favorite'] == 1,
      );
    } catch (_) {}
  }

  String _couponLabel(Map c) {
    final code = c['code'] ?? '';
    if (c['percent'] != null) return '$code · خصم ${c['percent']}%';
    if (c['flat'] != null) return '$code · ${c['flat']} د.ع';
    return code;
  }

  bool _isUrlCover(String v) =>
      v.startsWith('http') ||
      v.startsWith('/uploads') ||
      v.startsWith('data:') ||
      v.startsWith('/9j');

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Loader());
    if (store == null)
      return const Scaffold(
        body: EmptyState(icon: '🏪', title: 'المتجر غير موجود'),
      );
    final s = store as Map;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ═══════ الهيدر ═══════
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 18),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      gradient: AppColors.gradNavy,
                    ),
                    child: Stack(
                      children: [
                        if (s['cover'] != null &&
                            _isUrlCover(s['cover'].toString()))
                          Positioned.fill(
                            child: productImageBox(s['cover'].toString()),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.55),
                                  Colors.black.withOpacity(0.15),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: storeLogo(
                                          s['logo'] ?? '',
                                          size: 66,
                                          radius: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              s['name'] ?? '',
                                              style: AppType.style(
                                                19,
                                                color: Colors.white,
                                                weight: FontWeight.w900,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (s['verified'] == true ||
                                              s['verified'] == 1)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 5,
                                              ),
                                              child: Icon(
                                                Icons.verified_rounded,
                                                size: 17,
                                                color: AppColors.primaryLight,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        '${s['category_name'] ?? ''}',
                                        style: AppType.style(
                                          12,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFFBBF24),
                                              size: 15,
                                            ),
                                            Text(
                                              ' ${(s['rating'] ?? 0).toStringAsFixed(1)} (${s['reviews_count'] ?? 0})',
                                              style: AppType.style(
                                                11.5,
                                                color: Colors.white,
                                                weight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '  ·  ${s['verified'] == true || s['verified'] == 1 ? 'متجر موثوق' : 'محل محلي'}',
                                              style: AppType.style(
                                                10.5,
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            // الحالة + الكوبونات السريعة
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _statusChip(s),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // ═══════ شريط دوام المحل ═══════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      child: Row(
                        children: [
                          _infoIcon(
                            Icons.storefront_rounded,
                            'الدوام',
                            _hoursLabel(s),
                            AppColors.cyan,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ═══════ أزرار تواصل ═══════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _actionBtn(
                          Icons.map_rounded,
                          'الموقع',
                          () => _launch(s['location_url'] ?? ''),
                        ),
                        _actionBtn(
                          followed
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          followed ? 'متابع' : 'متابعة',
                          _toggleFollow,
                          highlighted: followed,
                        ),
                      ],
                    ),
                  ),
                ),
                // ═══════ كوبونات المتجر ═══════
                if (coupons.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎟 كوبونات المتجر',
                            style: AppType.style(
                              13,
                              color: AppColors.muted,
                              weight: FontWeight.w800,
                            ),
                          ),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.gradSun,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.confirmation_number_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _couponLabel(c),
                                            style: AppType.style(
                                              11.5,
                                              color: Colors.white,
                                              weight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                // ═══════ عروض المتجر (أفقية) ═══════
                if (offerProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔥 عروض المتجر',
                            style: AppType.style(
                              13,
                              color: AppColors.muted,
                              weight: FontWeight.w800,
                            ),
                          ),
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
                        ],
                      ),
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
                              child: ChoiceChip(
                                label: const Text('الكل'),
                                selected: catSel < 0,
                                onSelected: (_) => setState(() => catSel = -1),
                              ),
                            ),
                            ...cats.asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  label: Text(e.value),
                                  selected: catSel == e.key,
                                  onSelected: (_) => setState(
                                    () => catSel = catSel == e.key ? -1 : e.key,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // ═══════ المنتجات مقسمة حسب الفئات ═══════
                ..._buildCategorySections(),
                // ═══════ التقييمات ═══════
                if (reviews.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '⭐ التقييمات (${reviews.length})',
                                style: AppType.style(
                                  13,
                                  color: AppColors.muted,
                                  weight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                (s['rating'] ?? 0).toStringAsFixed(1),
                                style: AppType.style(
                                  14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // توزيع النجوم
                          if (ratingBreakdown.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  for (var r = 5; r >= 1; r--)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '$r ★',
                                            style: AppType.style(
                                              11,
                                              color: AppColors.muted,
                                              weight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: reviews.isEmpty
                                                    ? 0
                                                    : (ratingBreakdown['$r'] ??
                                                              0) /
                                                          reviews.length,
                                                minHeight: 6,
                                                backgroundColor: AppColors.bg,
                                                color: const Color(0xFFFBBF24),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${ratingBreakdown['$r'] ?? 0}',
                                            style: AppType.style(
                                              10.5,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          for (final rev in reviews.take(4))
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 11,
                                        backgroundColor: AppColors.primaryLight
                                            .withOpacity(0.2),
                                        child: Text(
                                          (rev['user_name'] ?? '؟')
                                              .toString()
                                              .characters
                                              .first,
                                          style: AppType.style(
                                            11,
                                            weight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          rev['user_name'] ?? 'زبون',
                                          style: AppType.style(
                                            12,
                                            weight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _stars(rev['rating'] ?? 0),
                                        style: AppType.style(
                                          11,
                                          color: const Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((rev['comment'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      rev['comment'],
                                      style: AppType.style(
                                        12,
                                        color: AppColors.muted,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── مساعدات UI ──
  /// نص ساعات الدوام: يفضل الدوام التلقائي (HH:MM - HH:MM) على النص القديم
  String _hoursLabel(Map s) {
    final wh = (s['work_hours'] as Map?) ?? {};
    if (wh['enabled'] == true && wh['open'] != null && wh['close'] != null)
      return '${wh['open']} - ${wh['close']}';
    return '${(s['open_time'] ?? '')} - ${(s['close_time'] ?? '')}';
  }

  Widget _statusChip(Map s) {
    if (s['on_vacation'] == true)
      return _chip(Icons.beach_access_rounded, 'ويا إجازة', AppColors.warning);
    final open = s['is_open'] == true || s['is_open'] == 1;
    return _chip(
      open ? Icons.check_circle_rounded : Icons.cancel_rounded,
      open ? 'مفتوح' : 'مغلق',
      open ? AppColors.success : AppColors.danger,
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.style(10.5, color: color, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppType.style(12, weight: FontWeight.w900)),
          Text(label, style: AppType.style(9.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool highlighted = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: highlighted
              ? AppColors.primary.withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: highlighted ? AppColors.primary : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppType.style(10, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offerCard(Map p) {
    return GestureDetector(
      onTap: () =>
          pushProduct(context, widget.storeId, (p['id'] as num).toInt()),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: productImage(p['image'], size: 56, radius: 10)),
            const SizedBox(height: 6),
            Text(
              p['name'] ?? '',
              style: AppType.style(11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              formatMoney(_displayPrice(p)),
              style: AppType.style(
                12,
                color: AppColors.accent,
                weight: FontWeight.w900,
              ),
            ),
            if ((p['price'] ?? 0) > _displayPrice(p))
              Text(
                formatMoney((p['price'] ?? 0).toDouble()),
                style: AppType.style(
                  9.5,
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            GestureDetector(
              onTap: () => addToCart((p['id'] as num).toInt(), 1),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stars(dynamic rating) =>
      '★' * ((rating as num?)?.toInt() ?? 0).clamp(0, 5);

  Iterable<Widget> _buildCategorySections() sync* {
    if (shown.isEmpty) {
      yield const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: EmptyState(icon: '📦', title: 'لا منتجات بعد'),
        ),
      );
      return;
    }

    final categoriesToDisplay = catSel < 0 ? cats : [cats[catSel]];

    for (final cat in categoriesToDisplay) {
      final catProducts = shown.where((p) => p['category_name'] == cat).toList();
      if (catProducts.isEmpty) continue;

      yield SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                cat,
                style: AppType.style(16, weight: FontWeight.w900, color: AppColors.ink),
              ),
            ],
          ),
        ),
      );

      yield SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.55,
          ),
          delegate: SliverChildBuilderDelegate((_, i) {
            return _buildProductCard(catProducts[i]);
          }, childCount: catProducts.length),
        ),
      );
    }
  }

  Widget _buildProductCard(dynamic p) {
    return ProdCard(
      product: Map<String, dynamic>.from(p as Map),
      onOpen: () => pushProduct(
        context,
        widget.storeId,
        (p['id'] as num).toInt(),
      ),
      opts: ProdCardOptions.glass,
      addEnabled: (p['stock'] ?? 0) > 0,
      onAdd: () {
        final hasVariant = variants.any(
          (v) =>
              (v['product_id'] as num? ?? 0).toInt() == (p['id'] as num).toInt(),
        );
        if (hasVariant) {
          pushProduct(
            context,
            widget.storeId,
            (p['id'] as num).toInt(),
          );
        } else {
          addToCart((p['id'] as num).toInt(), 1);
        }
      },
    );
  }

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
    showSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetTitle('🎟 كوبون المتجر'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 26),
            child: Column(
              children: [
                Text(
                  (c['code'] ?? '').toString(),
                  style: AppType.style(
                    22,
                    color: AppColors.accent,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _couponLabel(c),
                  style: AppType.style(13, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  'نسخناه — استخدمه عند الدفع بالسلة 🛒',
                  style: AppType.style(11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
   }
}
