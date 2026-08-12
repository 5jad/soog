import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/store_screen.dart';
import 'package:zaboon/features/shop/screens/outfit_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';

void pushProduct(BuildContext context, int storeId, int productId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductScreen(storeId: storeId, productId: productId),
    ),
  );
}

class ProductScreen extends StatefulWidget {
  final int storeId, productId;
  const ProductScreen({
    super.key,
    required this.storeId,
    required this.productId,
  });
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  dynamic p;
  dynamic store;
  bool loading = true;
  int qty = 1;
  String selColor = '';
  int selSize = -1;
  int imgIdx = 0;
  List reviews = [];
  List related = [];
  List same = [];
  bool isFav = false;
  Map<String, dynamic>? outfitPreview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/stores/${widget.storeId}');
      final products = d['products'] ?? [];
      p = products.firstWhere(
        (x) => x['id'] == widget.productId,
        orElse: () => null,
      );
      store = d['store'];
      reviews = (d['reviews'] ?? []).cast<Map>();
      same = products.where((x) => x['id'] != widget.productId).toList();
      // حالة المفضلة الحالية
      if (Api.logged) {
        try {
          final f = await Api.get('/api/customer/favorites');
          final ids = ((f['products'] ?? []) as List)
              .map((x) => (x is Map ? x['id'] : null))
              .toSet();
          isFav = ids.contains(widget.productId);
        } catch (_) {}
      }
      final catId = p?['category_id'];
      if (catId != null) {
        final rel = await Api.get('/api/products?category_id=$catId');
        related = (rel['products'] ?? [])
            .where((x) => x['id'] != widget.productId)
            .toList();
      }
      // معاينة الإطلالة المقترحة (خفيفة — تظهر لو القطعة من الأزياء)
      try {
        final of = await Api.get('/api/outfit/${widget.productId}');
        final o = of['outfit'];
        if ((o['slots'] ?? []).length > 1) {
          if (mounted)
            setState(() => outfitPreview = Map<String, dynamic>.from(of));
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addToCart([Offset? origin]) async {
    final variants = p['variants'] is List
        ? (p['variants'] as List).cast<Map>()
        : <Map>[];
    // المتغيرات على شكل تركيبات (لون + مقاس) — كل صف بمخزونه
    int? variantId;
    String? label;
    if (variants.isNotEmpty) {
      final colorList = _distinctColors(variants);
      if (colorList.length == 1 && colorList.first.isEmpty) {
        // بلا ألوان — اختيار المقاس فقط
        if (selSize < 0 || selSize >= variants.length)
          return toast(context, 'اختر المقاس أولاً 🙏');
        variantId = (variants[selSize]['id'] as num?)?.toInt();
        label = '${variants[selSize]['name'] ?? ''}';
      } else {
        if (selColor.isEmpty) return toast(context, 'اختر اللون أولاً 🙏');
        final rows = variants
            .where((v) => '${v['color'] ?? ''}' == selColor)
            .toList();
        if (selSize < 0 || selSize >= rows.length)
          return toast(context, 'اختر المقاس أولاً 🙏');
        variantId = (rows[selSize]['id'] as num?)?.toInt();
        label =
            '${rows[selSize]['color'] ?? ''} · ${rows[selSize]['name'] ?? ''}';
      }
    }
    if (!Api.logged) {
      final match = AppState.i.guestCart.indexWhere(
        (e) =>
            e['product_id'] == widget.productId &&
            e['variant'] == (label ?? null),
      );
      if (match >= 0) {
        AppState.i.guestCart[match]['qty'] += qty;
      } else {
        AppState.i.guestCart.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'store_id': widget.storeId,
          'store_name': store['name'],
          'logo': store['logo'],
          'product_id': widget.productId,
          'product_name': p['name'],
          'image': p['image'],
          'price': (p['has_offer'] == true || p['has_offer'] == 1)
              ? p['offer_price']
              : p['price'],
          'qty': qty,
          'variant': label,
        });
        AppState.i.setCart(AppState.i.guestCart.length);
      }
      addPop(context, '${p['name']}', img: p['image'], origin: origin);
      return;
    }
    try {
      await Api.post('/api/customer/cart', {
        'product_id': widget.productId,
        'qty': qty,
        if (variantId != null) 'variant_id': variantId,
        if (label != null) 'variant_label': label,
      });
      AppState.i.setCart(AppState.i.cartCount.value + 1);
      if (!mounted) return;
      addPop(context, '${p['name']}', img: p['image'], origin: origin);
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  String _attrLabel(String key) {
    const map = {
      'size': 'القياس',
      'color': 'اللون',
      'material': 'الخامة',
      'age': 'الفئة العمرية',
      'type': 'النوع',
      'expiry': 'تاريخ الانتهاء',
      'skin': 'مناسب لـ',
      'weight': 'الوزن / الحجم',
      'serve': 'تكفي لـ',
      'brand': 'الشركة المصنعة',
      'prescription': 'وصفة طبية',
      'warranty': 'مدة الضمان',
      'length': 'الطول',
      'width': 'العرض',
      'height': 'الارتفاع',
      'chest': 'محيط الصدر',
      'waist': 'محيط الخصر',
      'capacity': 'السعة',
      'origin': 'بلد الصنع',
      'flavor': 'النكهة',
    };
    return map[key] ?? key;
  }

  String _specEmoji(String key) {
    const map = {
      'material': '🧵',
      'age': '👶',
      'type': '🏷️',
      'expiry': '📅',
      'skin': '✨',
      'weight': '⚖️',
      'serve': '🍽️',
      'brand': '🏭',
      'prescription': '💊',
      'warranty': '🛡️',
      'length': '📏',
      'width': '↔️',
      'height': '↕️',
      'chest': '📐',
      'waist': '📐',
      'capacity': '🪣',
      'origin': '🌍',
      'flavor': '🍬',
    };
    return map[key] ?? '🔹';
  }

  Widget _specChip(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_specEmoji(key)} ', style: const TextStyle(fontSize: 12)),
          Text(
            '${_attrLabel(key)}: ',
            style: AppType.style(
              10.5,
              color: AppColors.muted,
              weight: FontWeight.w800,
            ),
          ),
          Text(value, style: AppType.style(11, weight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _serviceChip(String emoji, String title, String sub) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.style(
              10.5,
              color: AppColors.ink,
              weight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: AppType.style(
              9,
              color: AppColors.muted,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// ألوان المتغيرات بالترتيب — بلا تكرار ('' = بدون لون)
  List<String> _distinctColors(List<Map> variants) {
    final seen = <String>[];
    for (final v in variants) {
      final c = '${v['color'] ?? ''}';
      if (!seen.contains(c)) seen.add(c);
    }
    return seen;
  }

  /// هل اكتمل اختيار اللون والمقاس (إجباري قبل الإضافة للسلة)؟
  bool get _variantReady {
    final variants = p['variants'] is List
        ? (p['variants'] as List).cast<Map>()
        : <Map>[];
    if (variants.isEmpty) return true;
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty) {
      return selSize >= 0 && selSize < variants.length;
    }
    if (selColor.isEmpty) return false;
    final rows = variants
        .where((v) => '${v['color'] ?? ''}' == selColor)
        .toList();
    return selSize >= 0 && selSize < rows.length;
  }

  /// كمية مخزون التركيبة المختارة
  int get _selStock {
    final variants = p['variants'] is List
        ? (p['variants'] as List).cast<Map>()
        : <Map>[];
    if (variants.isEmpty) return 0;
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty) {
      return selSize >= 0 && selSize < variants.length
          ? ((variants[selSize]['stock'] as num?)?.toInt() ?? 0)
          : 0;
    }
    if (selColor.isEmpty) return 0;
    final rows = variants
        .where((v) => '${v['color'] ?? ''}' == selColor)
        .toList();
    return selSize >= 0 && selSize < rows.length
        ? ((rows[selSize]['stock'] as num?)?.toInt() ?? 0)
        : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Loader());
    if (p == null)
      return const Scaffold(
        body: EmptyState(icon: '🤷', title: 'المنتج غير موجود'),
      );
    final prod = Product.fromJson(Map<String, dynamic>.from(p));
    final variants = p['variants'] is List
        ? (p['variants'] as List).cast<Map>()
        : <Map>[];
    // المتغيرات على شكل تركيبات (لون + مقاس) — كل صف بمخزونه
    final colorList = _distinctColors(variants);
    final colorRows = selColor.isEmpty
        ? <Map>[]
        : variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
    final hasVariant = variants.isNotEmpty;
    final offPct = prod.hasOffer && prod.price > 0
        ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                // ═══ سلايدر الصور — مع شارات وأزرار علوية ═══
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: _imageList.length,
                        onPageChanged: (i) => setState(() => imgIdx = i),
                        itemBuilder: (_, i) =>
                            productImageBox(_imageList[i], base: Api.base),
                      ),
                      if (_imageList.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: _dots(),
                        ),
                    ],
                  ),
                ),
                // ═══ معلومات المنتج ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (store?['name'] != null)
                            Flexible(
                              child: Text(
                                '${store['name']}',
                                style: AppType.style(
                                  11,
                                  color: AppColors.primary,
                                  weight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if ((store?['rating'] ?? 0) as num > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.star,
                            ),
                            Text(
                              '${(store?['rating'] ?? 0) as num > 0 ? (store['rating'] as num).toStringAsFixed(1) : ''}',
                              style: AppType.style(
                                11,
                                color: AppColors.ink,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        prod.name,
                        style: AppType.style(
                          19.5,
                          weight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // السعر — صف منفصل: السعر الكبير + شارة الخصم الحمراء، وتحته السعر السابق والمخزون
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(prod.displayPrice),
                            style: AppType.style(
                              28,
                              color: AppColors.ink,
                              weight: FontWeight.w900,
                            ),
                          ),
                          if (prod.hasOffer) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger.withValues(
                                      alpha: .3,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                'خصم $offPct%',
                                style: AppType.style(
                                  11,
                                  color: Colors.white,
                                  weight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (prod.hasOffer) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              formatMoney(prod.price),
                              style: AppType.style(
                                13,
                                color: AppColors.muted,
                                decoration: TextDecoration.lineThrough,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'وفّرت ${formatMoney((prod.price - prod.displayPrice).clamp(0, double.infinity))} 🎉',
                              style: AppType.style(
                                11.5,
                                color: AppColors.success,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            if (!prod.outOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: .1,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '● متوفر الآن',
                                  style: AppType.style(
                                    11,
                                    color: AppColors.success,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '● نفد المخزون',
                                  style: AppType.style(
                                    11,
                                    color: AppColors.danger,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Spacer(),
                            if (!prod.outOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: .1,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '● متوفر الآن · المخزون ${prod.stock}',
                                  style: AppType.style(
                                    11,
                                    color: AppColors.success,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '● نفد المخزون',
                                  style: AppType.style(
                                    11,
                                    color: AppColors.danger,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      // ═══ زر التنسيق الذكي «نسّق لي» ═══
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OutfitScreen(
                                productId: widget.productId,
                                seedName: prod.name,
                                seedImage: prod.image,
                              ),
                            ),
                          ).then((added) {
                            if (added == true && mounted)
                              Navigator.pop(context, true);
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF12294E), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .3),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'نسّق لي هذه القطعة ✨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (outfitPreview != null) ...[
                        const SizedBox(height: 12),
                        _outfitPreview(),
                      ],
                      const SizedBox(height: 14),
                      // ═══ بوكس المتجر الناشر ═══
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: storeLogo(
                                store?['logo']?.toString() ?? '',
                                size: 46,
                                radius: 23,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${store['name'] ?? ''}',
                                          style: AppType.style(
                                            14,
                                            weight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (store['verified'] == true) ...[
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: AppColors.star,
                                      ),
                                      Text(
                                        '${(store['rating'] ?? 0) as num > 0 ? (store['rating'] as num).toStringAsFixed(1) : 'جديد'} · ${store['reviews_count'] ?? 0} تقييم',
                                        style: AppType.style(
                                          10.5,
                                          color: AppColors.muted,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      if (store['is_open'] == true) ...[
                                        const SizedBox(width: 6),
                                        const Text(
                                          '●',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: AppColors.success,
                                          ),
                                        ),
                                        const Text(
                                          'مفتوح الآن',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreScreen(storeId: widget.storeId),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradNavy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'المتجر',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ═══ اختيار اللون ثم المقاس — بوكس أنيق ═══
                      if (hasVariant) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.line,
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A0A1120),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (colorList.length > 1 ||
                                  (colorList.length == 1 &&
                                      colorList.first.isNotEmpty)) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.palette_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'اختر اللون',
                                      style: AppType.style(
                                        13,
                                        weight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (selColor.isNotEmpty)
                                      Text(
                                        selColor,
                                        style: AppType.style(
                                          11,
                                          color: AppColors.primary,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 9,
                                  runSpacing: 9,
                                  children: colorList.map((c) {
                                    final selected = selColor == c;
                                    return GestureDetector(
                                      onTap: () => setState(() {
                                        selColor = selected ? '' : c;
                                        selSize = -1;
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 17,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.bg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.line,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: selected
                                                      ? Colors.white
                                                      : AppColors.line,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              c.isEmpty ? 'قياسي' : c,
                                              style: AppType.style(
                                                11.5,
                                                color: selected
                                                    ? Colors.white
                                                    : AppColors.ink,
                                                weight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: AppColors.line),
                                const SizedBox(height: 12),
                              ],
                              // المقاسات
                              Row(
                                children: [
                                  const Icon(
                                    Icons.straighten_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'اختر المقاس',
                                    style: AppType.style(
                                      13,
                                      weight: FontWeight.w900,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () =>
                                        _sizeGuideSheet(prod, variants),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.table_chart_outlined,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'دليل المقاسات والقياسات 📐',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 9,
                                  runSpacing: 9,
                                  children:
                                      (selColor.isEmpty && colorList.length > 1)
                                      ? colorRows.isEmpty
                                            ? []
                                            : []
                                      : (selColor.isEmpty &&
                                            (colorList.isEmpty ||
                                                (colorList.length == 1 &&
                                                    colorList.first.isEmpty)))
                                      ? variants
                                            .asMap()
                                            .entries
                                            .map(
                                              (ve) =>
                                                  _sizeChip(ve.key, ve.value),
                                            )
                                            .toList()
                                      : colorRows
                                            .asMap()
                                            .entries
                                            .map(
                                              (ve) =>
                                                  _sizeChip(ve.key, ve.value),
                                            )
                                            .toList(),
                                ),
                              ),
                              // ═══ ملخص التركيبة المختارة ═══
                              if (_variantReady) ...[
                                const SizedBox(height: 6),
                                const Divider(height: 1, color: AppColors.line),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: .08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.success.withValues(
                                        alpha: .35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'التركيبة المختارة ✓',
                                            style: AppType.style(
                                              11.5,
                                              color: AppColors.success,
                                              weight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            [
                                                  if (selColor.isNotEmpty)
                                                    selColor,
                                                  if (selSize >= 0) _selLabel,
                                                ]
                                                .where((s) => s.isNotEmpty)
                                                .join(' · '),
                                            style: AppType.style(
                                              12,
                                              color: AppColors.ink,
                                              weight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        'متوفر: $_selStock',
                                        style: AppType.style(
                                          12.5,
                                          color: AppColors.success,
                                          weight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      // ═══ لماذا تشتري من هنا؟ (Trust Banner) ═══
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _serviceChip(
                              '🚚',
                              'توصيل\n30-60 دقيقة',
                              'داخل الكوت',
                            ),
                            _serviceChip(
                              '💵',
                              'كاش عند\nالاستلام',
                              'ادفع بعد المشاهدة',
                            ),
                            _serviceChip(
                              '🔄',
                              'استرجاع\nخلال ${store['warranty_days'] ?? 3} أيام',
                              'ضمان المتجر',
                            ),
                          ],
                        ),
                      ),
                      // ═══ التفاصيل والمواصفات — شبكة كاملة مع القياسات ═══
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 17,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'التفاصيل والمواصفات',
                            style: AppType.style(15.5, weight: FontWeight.w900),
                          ),
                          const Spacer(),
                          if (prod.attributes.entries
                              .where((e) => !['size', 'color'].contains(e.key))
                              .isNotEmpty)
                            Text(
                              '${prod.attributes.entries.where((e) => !['size', 'color'].contains(e.key)).length} مواصفة',
                              style: AppType.style(
                                10.5,
                                color: AppColors.muted,
                                weight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (prod.attributes.entries
                                .where(
                                  (e) => !['size', 'color'].contains(e.key),
                                )
                                .isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'وصف المتجر الكامل متوفر فوق — التفاصيل الإضافية قريباً',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: prod.attributes.entries
                                    .where(
                                      (e) => !['size', 'color'].contains(e.key),
                                    )
                                    .map((e) => _specChip(e.key, '${e.value}'))
                                    .toList(),
                              ),
                            const Divider(height: 18, color: AppColors.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الوصف:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      prod.description.isEmpty
                                          ? 'منتج من ${store['name'] ?? ''}'
                                          : prod.description,
                                      style: AppType.style(
                                        12.5,
                                        color: AppColors.ink,
                                        height: 1.7,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ═══ التقييمات والمراجعات ═══
                      const SizedBox(height: 22),
                      _reviewsBox(),
                      // ═══ منتجات ذات صلة ═══
                      const SizedBox(height: 22),
                      _productsRow('منتجات ذات صلة ⚡', related),
                      // ═══ منتجات من نفس المحل ═══
                      const SizedBox(height: 22),
                      _productsRow('منتجات من نفس المحل', same),
                    ],
                  ),
                ),
              ],
            ),
            // ═══ شريط علوي زجاجي فوق الصورة ═══
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  IconGlass(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconGlass(icon: Icons.share_rounded, onTap: _share),
                  const SizedBox(width: 6),
                  IconGlass(
                    icon: isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: isFav ? AppColors.danger : null,
                    onTap: _toggleFav,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: const Border(
            top: BorderSide(color: Color(0x140A1120), width: 1),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setState(() => qty--) : null,
                        icon: const Icon(Icons.remove, color: AppColors.muted),
                      ),
                      Text(
                        '$qty',
                        style: AppType.style(16, weight: FontWeight.w900),
                      ),
                      IconButton(
                        onPressed: qty < 20
                            ? () => setState(() => qty++)
                            : null,
                        icon: const Icon(Icons.add, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (btnCtx) => SolidBtn(
                      label: prod.outOfStock
                          ? 'غير متوفر'
                          : hasVariant && !_variantReady
                          ? 'اختر اللون والمقاس أولاً 👆'
                          : 'إضافة للسلة · ${formatMoney(prod.displayPrice * qty)}',
                      color: prod.outOfStock || (hasVariant && !_variantReady)
                          ? AppColors.primary
                          : AppColors.accent,
                      haptic: true,
                      disabled:
                          prod.outOfStock || (hasVariant && !_variantReady),
                      onTap: () {
                        final box = btnCtx.findRenderObject() as RenderBox?;
                        _addToCart(
                          box != null
                              ? box.localToGlobal(Offset.zero) +
                                    const Offset(0, 24)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _selLabel {
    final variants = p['variants'] is List
        ? (p['variants'] as List).cast<Map>()
        : <Map>[];
    if (selSize < 0 || selSize >= variants.length) return '';
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty)
      return '${variants[selSize]['name'] ?? ''}';
    final rows = variants
        .where((v) => '${v['color'] ?? ''}' == selColor)
        .toList();
    if (selSize < 0 || selSize >= rows.length) return '';
    return '${rows[selSize]['name'] ?? ''}';
  }

  Widget _sizeChip(int index, Map v) {
    final selected = selSize == index;
    final soldOut = ((v['stock'] as num?)?.toInt() ?? 0) == 0;
    return GestureDetector(
      onTap: soldOut
          ? null
          : () => setState(() => selSize = selected ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              '${v['name'] ?? ''}',
              style: AppType.style(
                13,
                color: selected ? Colors.white : AppColors.ink,
                weight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              soldOut ? 'نفد' : '${v['stock'] ?? 0} متوفر',
              style: AppType.style(
                9.5,
                color: selected
                    ? Colors.white.withValues(alpha: .85)
                    : (soldOut ? AppColors.danger : AppColors.muted),
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _imageList.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == imgIdx ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == imgIdx
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
      ],
    );
  }

  void _sizeGuideSheet(Product prod, List<Map> variants) {
    // قياسات تقريبية شائعة للملابس (سم) — تظهر إن كانت المقاسات حروفية
    const chart = {
      'S': ['88', '74', '66'],
      'M': ['96', '82', '70'],
      'L': ['104', '90', '74'],
      'XL': ['112', '98', '78'],
      'XXL': ['120', '106', '82'],
      'XS': ['80', '66', '62'],
    };
    final letterSizes = variants
        .map((v) => '${v['name'] ?? ''}'.toUpperCase())
        .where((s) => chart.containsKey(s))
        .toSet();
    showSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('دليل المقاسات والقياسات 📐'),
              const SizedBox(height: 12),
              if (letterSizes.isNotEmpty) ...[
                Text(
                  '💡 حسب القياسات التقريبية الشائعة (بشكل اعتمدها المتجر):',
                  style: AppType.style(
                    12,
                    color: AppColors.muted,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Table(
                    border: TableBorder.all(color: AppColors.line),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppColors.bg),
                        children: [
                          for (final h in [
                            'المقاس',
                            'الصدر (سم)',
                            'الخصر (سم)',
                            'الطول (سم)',
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Center(
                                child: Text(
                                  h,
                                  style: AppType.style(
                                    10.5,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final s in chart.entries.where(
                        (e) => letterSizes.contains(e.key),
                      ))
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Center(
                                child: Text(
                                  s.key,
                                  style: AppType.style(
                                    11,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            for (final m in s.value)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                child: Center(
                                  child: Text(
                                    m,
                                    style: AppType.style(
                                      11,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '* قيم تقريبية — قد تختلف بين المصنّعين، والمتجر يحدد المقاس المناسب عند الاستلام.',
                  style: AppType.style(
                    9.5,
                    color: AppColors.muted,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'مقاسات المتوفر حالياً وحالة المخزون:',
                style: AppType.style(
                  12,
                  color: AppColors.muted,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.bg),
                    children: [
                      for (final h in ['المقاس', 'المتوفر', 'الحالة'])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(
                            child: Text(
                              h,
                              style: AppType.style(
                                11.5,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final v in variants)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(
                            child: Text(
                              '${v['name'] ?? ''}',
                              style: AppType.style(
                                11.5,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(
                            child: Text(
                              '${v['stock'] ?? 0}',
                              style: AppType.style(
                                11.5,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ((v['stock'] as num?)?.toInt() ?? 0) > 0
                                    ? AppColors.success.withValues(alpha: .1)
                                    : AppColors.danger.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                ((v['stock'] as num?)?.toInt() ?? 0) > 0
                                    ? 'متوفر'
                                    : 'نفد',
                                style: AppType.style(
                                  10,
                                  color:
                                      ((v['stock'] as num?)?.toInt() ?? 0) > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                  weight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📏 كيف تقيس بشكل صحيح؟',
                      style: AppType.style(
                        12,
                        color: AppColors.primary,
                        weight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• الصدر: محيط أوسع نقطة تحت الإبط\n• الخصر: أنحف نقطة فوق السرة\n• الطول: من الكتف حتى نهاية الثوب — وقارنها بالجدول',
                      style: AppType.style(
                        11,
                        color: AppColors.ink,
                        height: 1.9,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'مقاس غير مناسب؟ اضغط أي مقاس بأعلى الصفحة وسيُحفظ اختيارك تلقائياً 👌',
                style: AppType.style(
                  11.5,
                  color: AppColors.muted,
                  weight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _share() {
    final nm = (p?['name'] as String?) ?? 'منتج';
    final pr = (p?['has_offer'] == true || p?['has_offer'] == 1)
        ? (p?['offer_price'] ?? 0)
        : (p?['price'] ?? 0);
    Share.share(
      'شوف هذا المنتج على زبون 🛍️\n$nm — ${formatMoney(pr)}\nhttps://zaboon.app/p/${widget.productId}',
    );
  }

  Future<void> _toggleFav() async {
    if (!Api.logged) {
      toast(context, 'سجل دخولك لحفظ المفضلة');
      return;
    }
    try {
      final d = await Api.post('/api/customer/favorites', {
        'product_id': widget.productId,
      });
      final nowFav = d['favorite'] == true;
      if (nowFav != isFav) {
        AppState.i.favsCount.value =
            (AppState.i.favsCount.value + (nowFav ? 1 : -1)).clamp(0, 9999);
      }
      setState(() => isFav = nowFav);
      toast(context, nowFav ? 'انضاف للمفضلة ❤️' : 'انحذف من المفضلة');
      AppState.i.favsReload.value++;
    } catch (e) {
      toast(context, '$e', error: true);
    }
  }

  /// صور المنتج: عمود images (من المعرض) وإن فاضي → الصورة الأساسية
  List<String> get _imageList {
    final raw = p?['images'];
    final imgs = raw is List
        ? raw
              .map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    if (imgs.isEmpty) {
      final one = p?['image']?.toString().trim() ?? '';
      return one.isEmpty ? [] : [one];
    }
    return imgs;
  }

  Widget _reviewsBox() {
    final total = (store['rating'] ?? 0) as num;
    final count = (store['reviews_count'] ?? reviews.length) as num;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'التقييمات والمراجعات',
              style: AppType.style(15.5, weight: FontWeight.w900),
            ),
            const Spacer(),
            if (total > 0)
              Text(
                '${total.toStringAsFixed(1)} ★',
                style: AppType.style(
                  14,
                  color: const Color(0xFFFBBF24),
                  weight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'لا توجد تقييمات بعد — كن أول من يقيّم 🖊️',
              style: AppType.style(
                12.5,
                color: AppColors.muted,
                weight: FontWeight.w700,
              ),
            ),
          )
        else ...[
          Text(
            'بناء على $count تقييم من العملاء',
            style: AppType.style(
              11,
              color: AppColors.muted,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final rev in reviews.take(9))
            _reviewCard(Map<String, dynamic>.from(rev)),
        ],
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> rev) {
    final rating = ((rev['rating'] ?? 0) as num).toInt().clamp(0, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${(rev['user_name'] ?? '👤').toString().trim()}'.isEmpty
                  ? '👤'
                  : '${rev['user_name'] ?? '👤'}'.substring(0, 1),
              style: AppType.style(
                12,
                color: AppColors.primary,
                weight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rev['user_name'] ?? 'عميل'}',
                        style: AppType.style(12.5, weight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${rev['created_at']?.toString().substring(0, 10) ?? ''}',
                      style: AppType.style(10, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '★' * rating + '☆' * (5 - rating),
                  style: AppType.style(13, color: const Color(0xFFFBBF24)),
                ),
                if ('${rev['comment'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${rev['comment']}',
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
    );
  }

  Widget _productsRow(String title, List list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.style(15.5, weight: FontWeight.w900)),
        const SizedBox(height: 10),
        SizedBox(
          height: 308,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final m = Map<String, dynamic>.from(list[i]);
              final sid = (m['store_id'] as num?)?.toInt() ?? widget.storeId;
              return SizedBox(
                width: 162,
                child: ProdCard(
                  product: m,
                  onOpen: () =>
                      pushProduct(context, sid, Product.fromJson(m).id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// معاينة مصغرة للإطلالة المقترحة أسفل زر التنسيق
  Widget _outfitPreview() {
    final o = outfitPreview?['outfit'];
    final slots = (o?['slots'] ?? []) as List;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OutfitScreen(
            productId: widget.productId,
            seedName: p?['name'] ?? '',
            seedImage: p?['image'] ?? '',
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${o?['title'] ?? 'إطلالة مقترحة'}',
                  style: AppType.style(
                    12.5,
                    color: AppColors.primary,
                    weight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if ((o?['fit'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'توافق ${o?['fit']}/100',
                      style: AppType.style(
                        9.5,
                        color: AppColors.success,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in slots)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        children: [
                          productImage(
                            '${s['image'] ?? ''}',
                            size: 42,
                            radius: 10,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            formatMoney((s['price'] ?? 0) as num),
                            style: AppType.style(
                              9,
                              color: AppColors.accent,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  formatMoney((o?['total'] ?? 0) as num),
                  style: AppType.style(
                    14,
                    color: AppColors.ink,
                    weight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  'اضغط لعرض البدائل وتعديلها',
                  style: AppType.style(
                    9.5,
                    color: AppColors.muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
