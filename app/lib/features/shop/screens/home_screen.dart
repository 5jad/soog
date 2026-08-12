import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/outfit_screen.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onGoStore;
  const HomeScreen({super.key, required this.onGoStore});
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final scrollCtrl = ScrollController();
  List ads = [];
  List stores = [];
  List bestProducts = []; // ترند اليوم (الأعلى تقييماً)
  List recent = []; // جديدنا (الأحدث)
  List outfits = []; // إطلالات تلقائية من مشتريات الزبون
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// جلب جديد صامت — مستدعى من أيقونة الرئيسية (بدون إظهار الـ loading)
  void refresh() {
    _load();
  }

  @override
  void dispose() {
    scrollCtrl.dispose();
    super.dispose();
  }

  /// العودة لأعلى الرئيسية — تستدعى من الشيل عند الضغط على أيقونة الرئيسية
  void scrollTop() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.get('/api/products?best=true'),
        Api.get('/api/products'),
        Api.get('/api/ads'),
        Api.get('/api/stores'),
      ]);
      bestProducts = results[0]['products'] ?? [];
      recent = results[1]['products'] ?? [];
      ads = results[2]['ads'] ?? [];
      stores = results[3]['stores'] ?? [];
    } catch (_) {}
    // إطلالات مشترياتك — منفصلة حتى لا تعطّل الرئيسية لو فشلت (سيرفر قديم/توكن منتهي)
    if (Api.logged) {
      try {
        final d = await Api.get('/api/outfit/for-me');
        if (mounted) outfits = (d['outfits'] ?? []) as List;
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  /// عنوان قسم
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [Expanded(child: SectionTitle(title))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 14,
        title: const TopBarPill(),
        actions: const [SizedBox(width: 8), NotifBell(), SizedBox(width: 10)],
      ),
      body: loading
          ? const Loader()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await _load();
                  },
                  color: AppColors.primary,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // تنبيه النسخة الأحدث (من الموقع)
                      const UpdateBanner(),
                      // البانر الرئيسي — سلايدر تلقائي
                      _HeroCarousel(
                        ads: ads,
                        stores: stores,
                        onOpen: (a) {
                          final sid = a['store_id'];
                          if (sid != null) widget.onGoStore(sid);
                        },
                      ),
                      // محلات مميزة
                      if (stores.isNotEmpty) ...[
                        _sectionHeader('⭐ محلات مميزة'),
                        SizedBox(
                          height: 158,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: stores.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 11),
                            itemBuilder: (_, i) {
                              final s = stores[i];
                              const covers = [
                                Color(0xFF12294E),
                                Color(0xFFF2560F),
                                Color(0xFF1F9D55),
                                Color(0xFF1789A6),
                              ];
                              return _StoreMiniCard(
                                data: Map<String, dynamic>.from(s as Map),
                                cover: covers[i % covers.length],
                                onOpen: () =>
                                    widget.onGoStore((s['id'] as num).toInt()),
                              );
                            },
                          ),
                        ),
                      ],
                      // ═══ إطلالات تلقائية من مشترياتك ═══
                      if (outfits.isNotEmpty) ...[
                        _sectionHeader('👔 إطلالات من مشترياتك'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 128,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: outfits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 11),
                            itemBuilder: (_, i) {
                              final o = Map<String, dynamic>.from(
                                outfits[i] as Map,
                              );
                              final seed = (o['seed'] ?? {}) as Map;
                              final of = (o['outfit'] ?? {}) as Map;
                              final slots = (of['slots'] ?? []) as List;
                              final pid = (seed['id'] as num?)?.toInt() ?? 0;
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OutfitScreen(
                                      productId: pid,
                                      seedName: '${seed['name'] ?? ''}',
                                      seedImage: '${seed['image'] ?? ''}',
                                    ),
                                  ),
                                ),
                                child: Container(
                                  width: 224,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: Row(
                                    children: [
                                      productImage(
                                        '${seed['image'] ?? ''}',
                                        size: 62,
                                        radius: 14,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${seed['name'] ?? ''}',
                                              style: AppType.style(
                                                12,
                                                weight: FontWeight.w900,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                for (final s in slots.take(4))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 3,
                                                        ),
                                                    child: productImage(
                                                      '${s['image'] ?? ''}',
                                                      size: 24,
                                                      radius: 7,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '${slots.length} قطع · ${formatMoney((of['total'] ?? 0) as num)} · توافق ${of['fit']}/100',
                                              style: AppType.style(
                                                9.5,
                                                color: AppColors.muted,
                                                weight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_left_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      // ═══ ترند اليوم — كل المنتجات شبكة كاملة (بلا زر عرض الكل) ═══
                      if (bestProducts.isNotEmpty) ...[
                        _sectionHeader('🔥 ترند اليوم'),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 0,
                          childAspectRatio: 0.55,
                          children: bestProducts.map((bp) {
                            final m = Map<String, dynamic>.from(bp as Map);
                            return ProdCard(
                              product: m,
                              onOpen: () =>
                                  pushProduct(context, m['store_id'], m['id']),
                            );
                          }).toList(),
                        ),
                      ],
                      // ═══ جديدنا — شريط أفقي بصفين ═══
                      if (recent.isNotEmpty) ...[
                        _sectionHeader('✨ جديدنا'),
                        const SizedBox(height: 10),
                        prodStrip(context, recent),
                      ],
                      if (bestProducts.isEmpty && recent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'ماكو منتجات بعد',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// شريط تمرير أفقي للمنتجات — صفّان مرتبان صفاً ثم عموداً،
/// بنفس تصميم وحجم بوكس شبكة «عرض الكل» تماماً (مشترك: الرئيسية + البحث)
Widget prodStrip(BuildContext context, List products) {
  final w = MediaQuery.of(context).size.width / 2;
  final cellH = w / 0.55; // نفس نسبة شبكة عرض الكل بالضبط
  Widget cell(int idx) => idx < products.length
      ? SizedBox(
          width: w,
          height: cellH,
          child: Builder(
            builder: (_) {
              final m = Map<String, dynamic>.from(products[idx] as Map);
              return ProdCard(
                product: m,
                onOpen: () => pushProduct(
                  context,
                  (m['store_id'] as num?)?.toInt() ?? 0,
                  Product.fromJson(m).id,
                ),
              );
            },
          ),
        )
      : const SizedBox(width: 0);
  final twoRows = products.length >= 3;
  return SizedBox(
    height: twoRows ? cellH * 2 : cellH,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: (products.length + 3) ~/ 4,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, i) {
        final base = i * 4;
        final hasRow2 = base + 2 < products.length;
        return SizedBox(
          width: w * 2,
          height: hasRow2 ? cellH * 2 : cellH,
          child: Column(
            children: [
              Expanded(child: Row(children: [cell(base), cell(base + 1)])),
              if (hasRow2)
                Expanded(
                  child: Row(children: [cell(base + 2), cell(base + 3)]),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// سلايدر الإعلانات — يتحرك تلقائياً، مع نقاط مؤشر واسم المتجر تحت النص
class _HeroCarousel extends StatefulWidget {
  final List ads;
  final List stores;
  final void Function(Map<String, dynamic>) onOpen;
  const _HeroCarousel({
    required this.ads,
    required this.stores,
    required this.onOpen,
  });
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _pc = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.ads.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) {
          _pc.nextPage(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Widget _banner(Map<String, dynamic> m) {
    final img = (m['image'] ?? '').toString();
    final title = (m['title'] ?? '').toString();
    final subtitle = (m['subtitle'] ?? m['text'] ?? '').toString();
    final storeName = m['store_name']?.toString() ?? '';
    final hasImg =
        img.startsWith('http') ||
        img.startsWith('/') ||
        img.startsWith('data:') ||
        img.startsWith('/9j');
    return GestureDetector(
      onTap: () => widget.onOpen(m),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImg)
              productImageBox(img)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF12294E), Color(0xFF161F38)],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB30A1120)],
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 12,
              left: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: AppType.style(
                        17,
                        color: Colors.white,
                        weight: FontWeight.w900,
                      ),
                    ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppType.style(
                        11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  if (storeName.isNotEmpty)
                    Text(
                      storeName,
                      style: AppType.style(
                        10,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          if (ads.isEmpty)
            GestureDetector(
              onTap: () => widget.onOpen(const {}),
              child: _banner(const {
                'title': '🌙 تسوق في الشهر الفضيل',
                'subtitle': 'لرجالك ونسائك وأطفالك — خصومات على كل الطلبيات',
                'store_name': 'زبون · الكوت',
              }),
            )
          else
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pc,
                itemCount: ads.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) =>
                    _banner(Map<String, dynamic>.from(ads[i] as Map)),
              ),
            ),
          if (ads.length > 1) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < ads.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 17 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة المحل المصغرة (عرضية) — الغلاف يغطي البوكس كاملاً مع النص والتقييم فوقه
class _StoreMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cover;
  final VoidCallback onOpen;
  const _StoreMiniCard({
    required this.data,
    required this.cover,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final logo = (data['logo'] ?? '').toString();
    final coverUrl = (data['cover'] ?? '').toString();
    final hasCover = isUrlCover(coverUrl);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: 132,
        height: 122,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140A1120),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              productImageBox(coverUrl)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cover, AppColors.primaryLight],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB30A1120)],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 32,
                height: 32,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: storeLogo(logo, size: 28, radius: 8),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 9,
              right: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    style: AppType.style(
                      11.5,
                      color: Colors.white,
                      weight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppColors.star,
                      ),
                      Text(
                        '${((data['rating'] ?? 0) as num).toStringAsFixed(1)}',
                        style: AppType.style(
                          10.5,
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '• ${data['reviews_count'] ?? 0} تقييم',
                          style: AppType.style(
                            9.5,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

