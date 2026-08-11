import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'stores_screen.dart';
import 'store_screen.dart';
import 'favorites_screen.dart';
import 'cart_screen.dart';
import 'account_screen.dart';

/// واجهة الزبون — 4 تبويبات: الرئيسية، المتاجر، الطلبات، حسابي
class CustomerShell extends StatefulWidget {
  final List<String> roles;
  const CustomerShell({super.key, required this.roles});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int tab = 0;
  int cartReload = 0;
  final GlobalKey<HomeScreenState> homeKey = GlobalKey();

  /// عند الضغط على أيقونة «الرئيسية»: جلب جديد صامت + رجوع لأعلى الصفحة
  void _goHome() {
    final h = homeKey.currentState;
    h?.refresh(); // بيانات جديدة من السيرفر (بدون إظهار الـ loading)
    h?.scrollTop();
  }

  @override
  void initState() {
    super.initState();
    // العداد يظهر فوراً من الذاكرة ثم يتزامن من السيرفر للمسجل
    AppState.i.loadCart();
    if (Api.logged) {
      Api.get('/api/customer/cart').then((d) {
        final items = d['cart'] ?? d['items'] ?? [];
        AppState.i.setCart((items as List).length);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: homeKey, onGoStore: (id) => pushStore(context, id)),
      StoresScreen(onOpen: (s) => pushStore(context, s.id)),
      CartScreen(key: ValueKey('cart$cartReload')),
      const FavoritesScreen(),
      AccountScreen(roles: widget.roles),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: AppState.i.cartCount,
        builder: (_, count, __) => ValueListenableBuilder<int>(
          valueListenable: AppState.i.favsCount,
          builder: (_, favs, __) => GlassBottomNav(
            index: tab,
            badgeIndex: 2,
            badgeCount: count,
            extraBadges: {3: favs},
            items: const [
              (Icons.home_rounded, 'الرئيسية'),
              (Icons.storefront_rounded, 'المتاجر'),
              (Icons.shopping_cart_rounded, 'السلة'),
              (Icons.favorite_rounded, 'المفضلة'),
              (Icons.person_rounded, 'حسابي'),
            ],
            onTap: (i) {
              if (i == 0) {
                // الضغط على الرئيسية: ننتقل إليها + رفريش + رجوع للأعلى دائماً
                if (tab != 0) setState(() => tab = 0);
                _goHome();
                return;
              }
              setState(() {
                tab = i;
                if (i == 2) cartReload++;
                if (i == 3) AppState.i.favsReload.value++;
              });
            },
          ),
        ),
      ),
    );
  }
}

void pushStore(BuildContext context, int id) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(storeId: id)));
}

/* ═══════════ الرئيسية ═══════════ */
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
  List offers = [];
  List bestProducts = [];
  List categories = [];
  Map<int, List> catProducts = {}; // منتجات كل فئة (لأشرطة التمرير)
  Map? expandedCat; // الفئة الموسّعة بـ «عرض الكل» في مكانها
  bool expandedBest = false; // الأكثر مبيعاً موسّع
  bool loading = true;
  final qCtrl = TextEditingController();
  String q = '';

  // ═══ حالة الفئة والفلترة — مثل شي إن: تبقى بصفحة الرئيسية ═══
  Map selCat = {};
  List gridProducts = [];
  bool gridLoading = false;
  String sort = 'newest';
  final minC = TextEditingController();
  final maxC = TextEditingController();
  final List<String> selColors = [];
  final List<String> selSizes = [];
  bool offerOnly = false;
  List metaColors = [];
  List metaSizes = [];

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
    qCtrl.dispose();
    minC.dispose();
    maxC.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  /// العودة لأعلى الرئيسية — تستدعى من الشيل عند الضغط على أيقونة الرئيسية
  void scrollTop() {
    if (!mounted) return;
    if (gridMode) {
      // نلغي كل الفلترة: الفئة، البحث، السعر، الألوان، المقاسات، العروض
      setState(() {
        selCat = {};
        q = '';
        qCtrl.clear();
        minC.clear();
        maxC.clear();
        selColors.clear();
        selSizes.clear();
        offerOnly = false;
        expandedCat = null;
        expandedBest = false;
      });
      _loadGrid(); // نعاود جلب الشبكة بعد التصفير — رئيسية محدثة بالكامل
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scrollCtrl.hasClients) {
          scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });
      return;
    }
    if (scrollCtrl.hasClients) {
      scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.get('/api/stores'),
        Api.get('/api/ads'),
        Api.get('/api/offers'),
        Api.get('/api/categories'),
        Api.get('/api/products?best=true'),
      ]);
      stores = results[0]['stores'] ?? [];
      AppState.i.storesCount.value = stores.length;
      ads = results[1]['ads'] ?? [];
      offers = results[2]['offers'] ?? [];
      categories = results[3]['categories'] ?? [];
      bestProducts = results[4]['products'] ?? [];
      // منتجات كل فئة — لأشرطة التمرير بالرئيسية
      final catReqs = categories.map((c) => Api.get('/api/products?category_id=${c['id']}')).toList();
      final catRes = await Future.wait(catReqs);
      catProducts = {
        for (var i = 0; i < categories.length; i++) (categories[i]['id'] as int): (catRes[i]['products'] ?? []) as List,
      };
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

/// شريط تمرير أفقي للمنتجات — صفّان مرتبان صفاً ثم عموداً (لو فئة فيها 2 منتج يكونن بنفس الصف)،
  /// بنفس تصميم وحجم بوكس شبكة «عرض الكل» تماماً
  Widget _prodStrip(List products) {
    final w = MediaQuery.of(context).size.width / 2;
    final cellH = w / 0.55; // نفس نسبة شبكة عرض الكل بالضبط
    Widget cell(int idx) => idx < products.length
        ? SizedBox(
            width: w,
            height: cellH,
            child: Builder(builder: (_) {
              final m = Map<String, dynamic>.from(products[idx] as Map);
              return _ProdCard(product: m, onOpen: () => pushProduct(context, (m['store_id'] as num?)?.toInt() ?? 0, Product.fromJson(m).id));
            }),
          )
        : const SizedBox(width: 0);
    // فئة فيها منتجان فقط: صف واحد بارتفاع واحد — بلا فراغ سفلي قبل الفئة التالية
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
            child: Column(children: [
              Expanded(child: Row(children: [cell(base), cell(base + 1)])),
              if (hasRow2) Expanded(child: Row(children: [cell(base + 2), cell(base + 3)])),
            ]),
          );
        },
      ),
    );
  }

  /// عنوان قسم + زر «عرض الكل/عرض أقل»
  Widget _stripHeader(String title, {bool expanded = false, VoidCallback? onExpand}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        Expanded(child: SectionTitle(title)),
        if (onExpand != null)
          GestureDetector(
            onTap: onExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: expanded ? A.primaryDeep : A.primary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: expanded ? A.primaryDeep : A.primary.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(expanded ? 'عرض أقل' : 'عرض الكل', style: A.t(10.5, c: expanded ? Colors.white : A.primary, w: FontWeight.w900)),
                const SizedBox(width: 3),
                Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 15, color: expanded ? Colors.white : A.primary),
              ]),
            ),
          ),
      ]),
    );
  }

  /// توسيع فئة في مكانها — بدل صفحة جديدة
  void _toggleCat(Map cat) {
    setState(() {
      if (expandedCat?['id'] == cat['id']) {
        expandedCat = null;
      } else {
        expandedCat = cat;
      }
    });
  }

  bool get hasFilters =>
      sort != 'newest' ||
      minC.text.trim().isNotEmpty ||
      maxC.text.trim().isNotEmpty ||
      selColors.isNotEmpty ||
      selSizes.isNotEmpty ||
      offerOnly;

  bool get gridMode => selCat.isNotEmpty || q.isNotEmpty || hasFilters;

  Future<void> _loadGrid() async {
    setState(() => gridLoading = true);
    final qs = <String>[];
    if (selCat.isNotEmpty) {
      qs.add('category_id=${selCat['id']}');
      if (metaColors.isEmpty || metaSizes.isEmpty) await _loadMeta();
    } else {
      metaColors = [];
      metaSizes = [];
    }
    if (q.isNotEmpty) qs.add('q=$q');
    if (sort != 'newest') qs.add('sort=$sort');
    if (minC.text.trim().isNotEmpty) qs.add('min_price=${minC.text.trim()}');
    if (maxC.text.trim().isNotEmpty) qs.add('max_price=${maxC.text.trim()}');
    if (selColors.isNotEmpty) qs.add('colors=${selColors.join(',')}');
    if (selSizes.isNotEmpty) qs.add('sizes=${selSizes.join(',')}');
    if (offerOnly) qs.add('offer=true');
    try {
      final d = await Api.get('/api/products?${qs.join('&')}');
      gridProducts = d['products'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => gridLoading = false);
    }
  }

  Future<void> _loadMeta() async {
    try {
      final d = await Api.get('/api/products/meta?category_id=${selCat['id']}');
      metaColors = d['colors'] ?? [];
      metaSizes = d['sizes'] ?? [];
    } catch (_) {}
  }

  void _pickCat(Map c) {
    setState(() {
      if (selCat['id'] == c['id']) {
        selCat = {};
      } else {
        selCat = c;
      }
      _resetFilters();
    });
    _loadGrid();
  }

  void _resetFilters() {
    sort = 'newest';
    minC.clear();
    maxC.clear();
    selColors.clear();
    selSizes.clear();
    offerOnly = false;
    metaColors = [];
    metaSizes = [];
  }

  void _clearFilters() {
    setState(_resetFilters);
    _loadGrid();
  }

  Future<void> _openFilters() async {
    final applied = await _openFilterSheet();
    if (applied == true) _loadGrid();
  }

  Future<bool?> _openFilterSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: A.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('الفلترة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton(onPressed: () { _clearFilters(); setS(() {}); }, child: const Text('مسح الكل', style: TextStyle(fontWeight: FontWeight.w800, color: A.danger))),
                  IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close_rounded)),
                ]),
                Text('الترتيب', style: A.t(12.5, w: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chipFilter('newest', 'الأحدث', sort, (v) => setS(() => sort = v as String)),
                  _chipFilter('best', 'الأفضل تقييماً', sort, (v) => setS(() => sort = v as String)),
                  _chipFilter('discount', 'الأكثر خصماً', sort, (v) => setS(() => sort = v as String)),
                  _chipFilter('price_asc', 'السعر: من الأقل', sort, (v) => setS(() => sort = v as String)),
                  _chipFilter('price_desc', 'السعر: من الأعلى', sort, (v) => setS(() => sort = v as String)),
                ]),
                const SizedBox(height: 16),
                Text('السعر (د.ع)', style: A.t(12.5, w: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _priceField('من', minC)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: TextStyle(fontSize: 14, color: A.muted))),
                  Expanded(child: _priceField('إلى', maxC)),
                ]),
                const SizedBox(height: 16),
                if (metaColors.isNotEmpty) ...[
                  Text('اللون', style: A.t(12.5, w: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in metaColors) ...[
                      GestureDetector(
                        onTap: () => setS(() {
                          selColors.contains(c) ? selColors.remove(c) : selColors.add('$c');
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: selColors.contains(c) ? A.primary : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: selColors.contains(c) ? A.primary : A.line, width: 1.2),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 11, height: 11,
                              decoration: BoxDecoration(color: _dot('$c'), shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                            ),
                            const SizedBox(width: 6),
                            Text('$c', style: A.t(11.5, c: selColors.contains(c) ? Colors.white : A.ink, w: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 16),
                ],
                if (metaSizes.isNotEmpty) ...[
                  Text('المقاس', style: A.t(12.5, w: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in metaSizes) ...[
                      GestureDetector(
                        onTap: () => setS(() {
                          selSizes.contains(s) ? selSizes.remove(s) : selSizes.add('$s');
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            color: selSizes.contains(s) ? A.primary : Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: selSizes.contains(s) ? A.primary : A.line, width: 1.2),
                          ),
                          child: Text('$s', style: A.t(11.5, c: selSizes.contains(s) ? Colors.white : A.ink, w: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded, color: A.accent, size: 19),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('العروض والخصومات فقط', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
                  Switch(value: offerOnly, activeColor: A.accent, onChanged: (v) => setS(() => offerOnly = v)),
                ]),
                const SizedBox(height: 10),
                SolidBtn(label: 'عرض النتائج', onTap: () => Navigator.pop(ctx, true)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipFilter(String val, String label, String cur, ValueChanged onTap) {
    final active = cur == val;
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? A.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? A.primary : A.line, width: 1.2),
        ),
        child: Text(label, style: A.t(11.5, c: active ? Colors.white : A.ink, w: FontWeight.w800)),
      ),
    );
  }

  Widget _priceField(String hint, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: hint, isDense: true, filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: A.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: A.primary, width: 1.4))),
    );
  }

  Color _dot(String name) {
    final n = '$name'.toLowerCase().trim();
    const map = {
      'أحمر': Color(0xFFE7352B), 'احمر': Color(0xFFE7352B), 'red': Color(0xFFE7352B),
      'أزرق': Color(0xFF2453CB), 'ازرق': Color(0xFF2453CB), 'blue': Color(0xFF2453CB),
      'أسود': Color(0xFF202126), 'اسود': Color(0xFF202126), 'black': Color(0xFF202126),
      'أبيض': Color(0xFFF5F5F5), 'ابيض': Color(0xFFF5F5F5), 'white': Color(0xFFF5F5F5),
      'أخضر': Color(0xFF1E8A4C), 'اخضر': Color(0xFF1E8A4C), 'green': Color(0xFF1E8A4C),
      'أصفر': Color(0xFFF2C513), 'اصفر': Color(0xFFF2C513), 'yellow': Color(0xFFF2C513),
      'بنفسجي': Color(0xFF7C3AED), 'purple': Color(0xFF7C3AED),
      'وردي': Color(0xFFF472B6), 'pink': Color(0xFFF472B6),
      'رمادي': Color(0xFF9CA3AF), 'grey': Color(0xFF9CA3AF),
      'بني': Color(0xFF7C4A23), 'brown': Color(0xFF7C4A23),
      'برتقالي': Color(0xFFF97316), 'orange': Color(0xFFF97316),
      'بيج': Color(0xFFE5CBB0), 'ذهبي': Color(0xFFD4AF37),
    };
    return map.entries.firstWhere((e) => n.contains(e.key), orElse: () => const MapEntry('', Color(0xFFD9DEE7))).value;
  }

  String _sortLabel(String s) => switch (s) {
        'best' => 'الأفضل تقييماً',
        'discount' => 'الأكثر خصماً',
        'price_asc' => 'السعر: من الأقل',
        'price_desc' => 'السعر: من الأعلى',
        _ => 'الأحدث',
      };

  @override
  Widget build(BuildContext context) {
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
      body: loading
          ? const Loader()
          : Stack(children: [
              RefreshIndicator(
                onRefresh: () async { await _load(); if (gridMode) _loadGrid(); },
                color: A.primary,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // تنبيه النسخة الأحدث (من الموقع)
                    const UpdateBanner(),
                    // البحث + زر الفلتر في نفس الصف (الفلتر على اليسار)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: qCtrl,
                            onChanged: (v) => setState(() => q = v.trim()),
                            onSubmitted: (_) => _loadGrid(),
                            style: A.t(13, w: FontWeight.w700),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'ابحث عن قميص، فستان، شنطة، مكياج... 🔍',
                              hintStyle: A.t(12.5, c: A.muted, w: FontWeight.w600),
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.search_rounded, color: A.primary),
                                onPressed: _loadGrid,
                              ),
                              suffixIcon: q.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 19, color: A.muted),
                                      onPressed: () {
                                        qCtrl.clear();
                                        setState(() => q = '');
                                        _loadGrid();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.85),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.55), width: 1.1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: A.primaryLight, width: 1.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _openFilters,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: hasFilters ? A.primary : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: hasFilters ? A.primary : A.line, width: 1.2),
                              boxShadow: hasFilters ? [BoxShadow(color: A.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
                            ),
                            alignment: Alignment.center,
                            child: Stack(clipBehavior: Clip.none, children: [
                              Icon(Icons.tune_rounded, size: 22, color: hasFilters ? Colors.white : A.ink),
                              if (hasFilters)
                                Positioned(
                                  left: -6,
                                  top: -8,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                                    child: Text(
                                      '${[sort != 'newest' ? 1 : 0, minC.text.trim().isNotEmpty || maxC.text.trim().isNotEmpty ? 1 : 0, selColors.length > 0 ? 1 : 0, selSizes.length > 0 ? 1 : 0, offerOnly ? 1 : 0].reduce((a, b) => a + b)}',
                                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    // الأقسام — شيبز مثل الديمو (بلا زر «الكل»)
                    if (categories.isNotEmpty) ...[
                      SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          children: [
                            for (final c in categories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChipG(
                                  icon: c['icon'] ?? '🛍',
                                  label: c['name'] ?? '',
                                  active: selCat['id'] == c['id'],
                                  onTap: () => _pickCat(Map<String, dynamic>.from(c as Map)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    // البانر الرئيسي — سلايدر تلقائي
                    _HeroCarousel(
                      ads: ads,
                      stores: stores,
                      onOpen: (a) {
                        final sid = a['store_id'];
                        if (sid != null) widget.onGoStore(sid);
                        else pushStores(context);
                      },
                    ),
                    // العروض
                    if (offers.isNotEmpty && !gridMode) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: SectionTitle('⚡ عروض اليوم'),
                      ),
                      SizedBox(
                        height: 196,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: offers.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 11),
                          itemBuilder: (_, i) {
                            final of = Map<String, dynamic>.from(offers[i] as Map);
                            final prod = Product.fromJson(Map<String, dynamic>.from(of['product'] as Map));
                            return _ProdMiniCard(
                              productJson: Map<String, dynamic>.from(of['product'] as Map),
                              storeName: of['store_name'] ?? '',
                              storeId: (of['product']['store_id'] as num?)?.toInt() ?? 0,
                              onOpen: () => pushProduct(context, of['product']['store_id'], prod.id),
                            );
                          },
                        ),
                      ),
                    ],
                    // محلات مميزة
                    if (stores.isNotEmpty && !gridMode) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: SectionTitle('محلات مميزة'),
                      ),
                      SizedBox(
                        height: 158,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: stores.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 11),
                          itemBuilder: (_, i) {
                            final s = stores[i];
                            const covers = [Color(0xFF12294E), Color(0xFFF2560F), Color(0xFF1F9D55), Color(0xFF1789A6)];
                            return _StoreMiniCard(
                              data: Map<String, dynamic>.from(s as Map),
                              cover: covers[i % covers.length],
                              onOpen: () => widget.onGoStore(s['id']),
                            );
                          },
                        ),
                      ),
                    ],
                    // ═══ قسم المنتجات — عنوان ديناميكي (للشبكة فقط) ═══
                    if (gridMode)
                      Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(children: [
                        Expanded(
                          child: SectionTitle(
                            q.isNotEmpty
                                ? 'نتائج البحث عن «$q»'
                                : selCat.isNotEmpty
                                    ? '${selCat['icon'] ?? ''} ${selCat['name']}'
                                    : 'المنتجات',
                          ),
                        ),
                      ]),
                    ),
                    // شرائح الفلاتر النشطة (مثل شي إن)
                    if (hasFilters)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          children: [
                            if (sort != 'newest')
                              _activeChip(_sortLabel(sort), () => setState(() { sort = 'newest'; _loadGrid(); })),
                            if (minC.text.trim().isNotEmpty || maxC.text.trim().isNotEmpty)
                              _activeChip('سعر: ${minC.text.trim().isEmpty ? '0' : minC.text.trim()}-${maxC.text.trim().isEmpty ? '∞' : maxC.text.trim()}', () => setState(() { minC.clear(); maxC.clear(); _loadGrid(); })),
                            for (final c in List.of(selColors))
                              _activeChip('لون: $c', () => setState(() { selColors.remove(c); _loadGrid(); })),
                            for (final s in List.of(selSizes))
                              _activeChip('مقاس: $s', () => setState(() { selSizes.remove(s); _loadGrid(); })),
                            if (offerOnly)
                              _activeChip('عروض فقط', () => setState(() { offerOnly = false; _loadGrid(); })),
                            _activeChip('مسح الكل', _clearFilters, danger: true),
                          ],
                        ),
                      ),
                    // الشبكة
                    if (gridMode)
                      gridLoading
                          ? const Padding(padding: EdgeInsets.all(30), child: Loader())
                          : gridProducts.isEmpty
                              ? const Padding(padding: EdgeInsets.fromLTRB(16, 30, 16, 0), child: EmptyState(icon: '📦', title: 'ماكو منتجات مطابقة', sub: 'جرب كلمة أو فلترة أخرى'))
                              : GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 0,
                                  crossAxisSpacing: 0,
                                  childAspectRatio: 0.55,
                                  children: gridProducts.map((bp) {
                                    final m = Map<String, dynamic>.from(bp as Map);
                                    return _ProdCard(product: m, onOpen: () => pushProduct(context, m['store_id'], m['id']));
                                  }).toList(),
                                )
                    else ...[
                      // شريط الأكثر مبيعاً + زر عرض الكل
                      if (bestProducts.isNotEmpty) ...[
                        _stripHeader('🔥 الأكثر مبيعاً',
                            expanded: expandedBest, onExpand: () => setState(() => expandedBest = !expandedBest)),
                        const SizedBox(height: 10),
                        if (expandedBest)
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 0,
                            crossAxisSpacing: 0,
                            childAspectRatio: 0.55,
                            children: bestProducts.map((bp) {
                              final m = Map<String, dynamic>.from(bp as Map);
                              return _ProdCard(product: m, onOpen: () => pushProduct(context, m['store_id'], m['id']));
                            }).toList(),
                          )
                        else
                          _prodStrip(bestProducts),
                      ],
                      // شريط لكل فئة + زر عرض الكل (يتوسع في مكانه)
                      for (final c in categories)
                        if ((catProducts[c['id']] ?? []).isNotEmpty) ...[
                          _stripHeader('${c['icon'] ?? '🛍'} ${c['name']}',
                              expanded: expandedCat?['id'] == c['id'],
                              onExpand: () => _toggleCat(Map<String, dynamic>.from(c as Map))),
                          const SizedBox(height: 10),
                          if (expandedCat?['id'] == c['id'])
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 0,
                              crossAxisSpacing: 0,
                              childAspectRatio: 0.55,
                              children: catProducts[c['id']]!.map((bp) {
                                final m = Map<String, dynamic>.from(bp as Map);
                                return _ProdCard(product: m, onOpen: () => pushProduct(context, m['store_id'], m['id']));
                              }).toList(),
                            )
                          else
                            _prodStrip(catProducts[c['id']]!),
                        ],
                      if (bestProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('ماكو منتجات بعد', style: TextStyle(fontSize: 12.5, color: A.muted)),
                        ),
                    ],
                  ],
                ),
              ),
            ]),
    );
  }

  Widget _activeChip(String label, VoidCallback onDelete, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InputChip(
        label: Text(label, style: A.t(10.5, c: danger ? A.danger : A.ink, w: FontWeight.w800)),
        backgroundColor: danger ? A.danger.withOpacity(0.08) : A.primary.withOpacity(0.08),
        side: BorderSide(color: danger ? A.danger : A.primary, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        onDeleted: onDelete,
        deleteIcon: Icon(Icons.close_rounded, size: 14, color: danger ? A.danger : A.primary),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

void pushStores(BuildContext context) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => StoresScreen(onOpen: (s) => pushStore(context, s.id))));
}

/// سلايدر الإعلانات — يتحرك تلقائياً إذا كانت أكثر من إعلان، مع نقاط مؤشر
class _HeroCarousel extends StatefulWidget {
  final List ads;
  final List stores;
  final void Function(Map<String, dynamic>) onOpen;
  const _HeroCarousel({required this.ads, required this.stores, required this.onOpen});
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _pc = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ads.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_pc.hasClients) return;
        _pc.animateToPage((_page + 1) % widget.ads.length,
            duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Widget _banner(Map a) {
    final sun = a['theme'] == 'sun';
    // صورة الإعلان إن وجدت، وإلا غلاف المتجر، وإلا التدرج
    final fromStore = (a['store_cover'] ?? '').toString().isNotEmpty ? a['store_cover'].toString() : '';
    final coverOfStore = fromStore.isNotEmpty
        ? fromStore
        : (widget.stores.firstWhere((s) => s['id'] == a['store_id'], orElse: () => null)?['cover']?.toString() ?? '');
    final bgImage = (a['image'] ?? '').toString().isNotEmpty ? a['image'].toString() : coverOfStore;
    return GestureDetector(
      onTap: () => widget.onOpen(Map<String, dynamic>.from(a)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(fit: StackFit.expand, children: [
          // الخلفية: صورة الإعلان / غلاف المتجر / التدرج
          if (bgImage.isNotEmpty)
            productImageBox(bgImage, base: Api.base)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: sun
                    ? const LinearGradient(colors: [A.accentDeep, A.accent])
                    : const LinearGradient(colors: [A.primaryDeep, A.primary, A.cyan]),
              ),
            ),
          // تغميق سفلي لقراءة النص
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB30A1120)],
              ),
            ),
          ),
          if (bgImage.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a['theme'] == 'sun' ? '🛍️' : '💎', style: A.t(58)),
            ),
          // النص والصور
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Row(children: [
                // صورة غلاف المتجر المصغرة + الاسم
                if (coverOfStore.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 26, height: 26, child: productImageBox(coverOfStore, base: Api.base)),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sun ? const Color(0xFFFFF3C4) : Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Text('${a['store_name'] ?? 'عرض مميز'}', style: A.t(10.5, c: sun ? A.ink : Colors.white, w: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['title'] ?? 'عرض اليوم', style: A.t(20, c: Colors.white, w: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if ((a['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(a['description'].toString(), style: A.t(11, c: Colors.white.withOpacity(0.92), w: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                // زر تسوق الآن — واضح في الطرف المقابل
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('تسوق الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: A.primary)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_back_rounded, size: 14, color: A.primary),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: ads.isEmpty
            ? SizedBox(height: 180, child: _banner({
                'title': 'كل ما تتمناه بمكان واحد',
                'theme': 'navy',
                'store_name': 'مول الأزياء',
                'description': 'لرجالك ونسائك وأطفالك — خصومات على كل الطلبيات',
              }))
            : SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pc,
                  itemCount: ads.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _banner(Map<String, dynamic>.from(ads[i] as Map)),
                ),
              ),
      ),
      if (ads.length > 1) ...[
        const SizedBox(height: 9),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < ads.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 17 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page ? A.primary : A.primary.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ]),
      ],
    ]);
  }
}

/// بطاقة المحل المصغرة (عرضية) — الغلاف يغطي البوكس كاملاً مع النص والتقييم فوقه
class _StoreMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cover;
  final VoidCallback onOpen;
  const _StoreMiniCard({required this.data, required this.cover, required this.onOpen});
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
          boxShadow: const [BoxShadow(color: Color(0x140A1120), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Stack(fit: StackFit.expand, children: [
          // الغلاف يملأ البوكس كاملاً
          if (hasCover)
            productImageBox(coverUrl)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cover, A.primaryLight]),
              ),
            ),
          // تغميق سفلي لقراءة النص
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB30A1120)],
              ),
            ),
          ),
          // الشعار
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 32, height: 32,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: storeLogo(logo, size: 28, radius: 8),
            ),
          ),
          // الاسم والتقييم على مستوى الغلاف
          Positioned(
            bottom: 8,
            left: 9,
            right: 9,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] ?? '', style: A.t(11.5, c: Colors.white, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: A.star),
                Text('${((data['rating'] ?? 0) as num).toStringAsFixed(1)}', style: A.t(10.5, c: Colors.white, w: FontWeight.w900)),
                const SizedBox(width: 4),
                Expanded(child: Text('• ${data['reviews_count'] ?? 0} تقييم', style: A.t(9.5, c: Colors.white.withOpacity(0.85)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// بطاقة المنتج المصغرة (قائمة عرضية)
class _ProdMiniCard extends StatelessWidget {
  final Map<String, dynamic> productJson;
  final String storeName;
  final int storeId;
  final VoidCallback onOpen;
  const _ProdMiniCard({required this.productJson, required this.storeName, required this.storeId, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final prod = Product.fromJson(productJson);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(10),
        decoration: A.card(radius: A.r20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          productImage(prod.image, size: 92, radius: 15),
          const SizedBox(height: 8),
          Text(prod.name, style: A.t(12.5, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(storeName, style: A.t(9.5, c: A.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            IconButton.filled(
              onPressed: () => quickAdd(context, productJson),
              icon: const Icon(Icons.add_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: A.primaryDeep,
                foregroundColor: Colors.white,
                minimumSize: const Size(24, 24),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            Text(money(prod.displayPrice), style: A.t(13, c: A.accent, w: FontWeight.w900)),
          ]),
        ]),
      ),
    );
  }
}

/// بطاقة المنتج لشبكة 2×2 — تصميم Shein: صورة 3:4 + اسم + نقاط ألوان + نسبة خصم + سعر بارز + زر سريع
class _ProdCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onOpen;
  const _ProdCard({required this.product, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final prod = Product.fromJson(product);
    final offPct = prod.hasOffer && prod.price > 0
        ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
        : 0;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(color: A.surface),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(fit: StackFit.expand, children: [
              productImageBox(prod.image),
              if (prod.hasOffer) Positioned(top: 8, right: 8, child: BadgeWow('خصم $offPct%')),
              if (prod.outOfStock) Positioned(top: 8, left: 8, child: BadgeWow('نفد', dark: true)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prod.name, style: A.t(10.5, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                // نقاط ألوان المتغيرات (مثل شي إن) — لون كل تركيبة بلا تكرار
                if (prod.variants.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Builder(builder: (ctx) {
                    final dots = <Color>[];
                    for (final v in prod.variants) {
                      final c = _dotsColor('${(v is Map ? (v['color'] ?? (v['name'] ?? '')) : v)}');
                      if (!dots.contains(c)) dots.add(c);
                    }
                    return Row(children: [
                      for (final c in dots.take(4))
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12, width: 0.7),
                            ),
                          ),
                        ),
                      if (dots.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text('+${dots.length - 4}', style: A.t(8, c: A.muted, w: FontWeight.w800)),
                        ),
                    ]);
                  }),
                ],
                if (prod.hasOffer) ...[
                  const SizedBox(height: 3),
                  Text(money(prod.price), style: A.t(8.5, c: A.muted, decoration: TextDecoration.lineThrough)),
                ],
                // السعر + زر الإضافة — مثبتان أسفل كل بوكس مهما تغيرت التفاصيل
                const Spacer(),
                Row(children: [
                  Expanded(child: Text(money(prod.displayPrice), style: A.t(12.5, c: A.accent, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  GestureDetector(
                    onTap: () => quickAdd(context, product),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(gradient: A.gradSun, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

// لون تقريبي لأسماء الألوان العربية الشائعة (تغريبي بسيط)
  Color _dotsColor(dynamic name) {
    final n = '$name'.toLowerCase().trim();
    const map = {
      'أحمر': Color(0xFFE7352B), 'احمر': Color(0xFFE7352B), 'red': Color(0xFFE7352B),
      'أزرق': Color(0xFF2453CB), 'ازرق': Color(0xFF2453CB), 'blue': Color(0xFF2453CB),
      'أسود': Color(0xFF202126), 'اسود': Color(0xFF202126), 'black': Color(0xFF202126),
      'أبيض': Color(0xFFF5F5F5), 'ابيض': Color(0xFFF5F5F5), 'white': Color(0xFFF5F5F5),
      'أخضر': Color(0xFF1E8A4C), 'اخضر': Color(0xFF1E8A4C), 'green': Color(0xFF1E8A4C),
      'أصفر': Color(0xFFF2C513), 'اصفر': Color(0xFFF2C513), 'yellow': Color(0xFFF2C513),
      'بنفسجي': Color(0xFF7C3AED), 'بنفسجية': Color(0xFF7C3AED), 'purple': Color(0xFF7C3AED),
      'وردي': Color(0xFFF472B6), 'وردية': Color(0xFFF472B6), 'pink': Color(0xFFF472B6),
      'رمادي': Color(0xFF9CA3AF), 'رمادية': Color(0xFF9CA3AF), 'grey': Color(0xFF9CA3AF),
      'بني': Color(0xFF7C4A23), 'بنية': Color(0xFF7C4A23), 'brown': Color(0xFF7C4A23),
      'برتقالي': Color(0xFFF97316), 'برتقالية': Color(0xFFF97316), 'orange': Color(0xFFF97316),
    };
    return map.entries.firstWhere((e) => n.contains(e.key), orElse: () => const MapEntry('', Color(0xFFD9DEE7))).value;
  }
}

/// إضافة سريعة للسلة — مثل زر + في الديمو
void quickAdd(BuildContext context, Map<String, dynamic> prod, {int qty = 1}) {
  final variants = prod['variants'];
  if (variants is List && variants.isNotEmpty) {
    // منتج بمتغيرات — فتح الصفحة ليختار اللون/القياس
    final storeId = (prod['store_id'] as num?)?.toInt() ?? 0;
    final pid = (prod['id'] as num?)?.toInt() ?? 0;
    if (storeId > 0 && pid > 0) return pushProduct(context, storeId, pid);
  }
  final pid = (prod['id'] as num?)?.toInt() ?? 0;
  if (!Api.logged) {
    final existing = AppState.i.guestCart.indexWhere((e) => e['product_id'] == pid);
    if (existing >= 0) {
      AppState.i.guestCart[existing]['qty'] += 1;
    } else {
      AppState.i.guestCart.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'store_id': prod['store_id'] ?? 0,
        'store_name': prod['store_name'] ?? 'متجر',
        'logo': prod['logo'] ?? '',
        'product_id': pid,
        'product_name': prod['name'],
        'image': prod['image'],
        'price': prod['has_offer'] == true || prod['has_offer'] == 1 ? prod['offer_price'] : prod['price'],
        'qty': qty,
        'variant': null,
      });
    }
    AppState.i.setCart(AppState.i.guestCart.length);
    toast(context, 'انضاف للسلة (مؤقتاً) 🛒');
    return;
  }
  Api.post('/api/customer/cart', {'product_id': pid, 'qty': qty}).then((_) {
    AppState.i.setCart(AppState.i.cartCount.value + 1);
    toast(context, 'انضاف للسلة 🛒');
  }).catchError((e) {
    toast(context, '${e is ApiException ? e.message : e}', error: true);
  });
}

class BadgeWow extends StatelessWidget {
  final String label;
  final bool dark;
  const BadgeWow(this.label, {super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFF0A1120) : A.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(label, style: A.t(11, c: Colors.white, w: FontWeight.w900)),
    );
  }
}

void pushProduct(BuildContext context, int storeId, int productId) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(storeId: storeId, productId: productId)));
}

class ProductScreen extends StatefulWidget {
  final int storeId, productId;
  const ProductScreen({super.key, required this.storeId, required this.productId});
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/stores/${widget.storeId}');
      final products = d['products'] ?? [];
      p = products.firstWhere((x) => x['id'] == widget.productId, orElse: () => null);
      store = d['store'];
      reviews = (d['reviews'] ?? []).cast<Map>();
      same = products.where((x) => x['id'] != widget.productId).toList();
      // حالة المفضلة الحالية
      if (Api.logged) {
        try {
          final f = await Api.get('/api/customer/favorites');
          final ids = ((f['products'] ?? []) as List).map((x) => (x is Map ? x['id'] : null)).toSet();
          isFav = ids.contains(widget.productId);
        } catch (_) {}
      }
      final catId = p?['category_id'];
      if (catId != null) {
        final rel = await Api.get('/api/products?category_id=$catId');
        related = (rel['products'] ?? []).where((x) => x['id'] != widget.productId).toList();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addToCart() async {
    final variants = p['variants'] is List ? (p['variants'] as List).cast<Map>() : <Map>[];
    // المتغيرات على شكل تركيبات (لون + مقاس) — كل صف بمخزونه
    int? variantId;
    String? label;
    if (variants.isNotEmpty) {
      final colorList = _distinctColors(variants);
      if (colorList.length == 1 && colorList.first.isEmpty) {
        // بلا ألوان — اختيار المقاس فقط
        if (selSize < 0 || selSize >= variants.length) return toast(context, 'اختر المقاس أولاً 🙏');
        variantId = (variants[selSize]['id'] as num?)?.toInt();
        label = '${variants[selSize]['name'] ?? ''}';
      } else {
        if (selColor.isEmpty) return toast(context, 'اختر اللون أولاً 🙏');
        final rows = variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
        if (selSize < 0 || selSize >= rows.length) return toast(context, 'اختر المقاس أولاً 🙏');
        variantId = (rows[selSize]['id'] as num?)?.toInt();
        label = '${rows[selSize]['color'] ?? ''} · ${rows[selSize]['name'] ?? ''}';
      }
    }
    if (!Api.logged) {
      final match = AppState.i.guestCart.indexWhere((e) =>
          e['product_id'] == widget.productId && e['variant'] == (label ?? null));
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
          'price': (p['has_offer'] == true || p['has_offer'] == 1) ? p['offer_price'] : p['price'],
          'qty': qty,
          'variant': label,
        });
        AppState.i.setCart(AppState.i.guestCart.length);
      }
      toast(context, 'انضاف للسلة (مؤقتاً) 🛒');
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
      toast(context, 'انضاف للسلة 🛒');
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  String _attrLabel(String key) {
    const map = {
      'size': 'القياس', 'color': 'اللون', 'material': 'الخامة', 'age': 'الفئة العمرية',
      'type': 'النوع', 'expiry': 'تاريخ الانتهاء', 'skin': 'مناسب لـ', 'weight': 'الوزن / الحجم',
      'serve': 'تكفي لـ', 'brand': 'الشركة المصنعة', 'prescription': 'وصفة طبية', 'warranty': 'مدة الضمان',
      'length': 'الطول', 'width': 'العرض', 'height': 'الارتفاع', 'chest': 'محيط الصدر',
      'waist': 'محيط الخصر', 'capacity': 'السعة', 'origin': 'بلد الصنع', 'flavor': 'النكهة',
    };
    return map[key] ?? key;
  }

  String _specEmoji(String key) {
    const map = {
      'material': '🧵', 'age': '👶', 'type': '🏷️', 'expiry': '📅', 'skin': '✨', 'weight': '⚖️',
      'serve': '🍽️', 'brand': '🏭', 'prescription': '💊', 'warranty': '🛡️', 'length': '📏',
      'width': '↔️', 'height': '↕️', 'chest': '📐', 'waist': '📐', 'capacity': '🪣', 'origin': '🌍',
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
        border: Border.all(color: A.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${_specEmoji(key)} ', style: const TextStyle(fontSize: 12)),
        Text('${_attrLabel(key)}: ', style: A.t(10.5, c: A.muted, w: FontWeight.w800)),
        Text(value, style: A.t(11, w: FontWeight.w900)),
      ]),
    );
  }

  Widget _serviceChip(String emoji, String title, String sub) {
    return Expanded(
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 4),
        Text(title, textAlign: TextAlign.center, style: A.t(10.5, c: A.ink, w: FontWeight.w900, h: 1.3)),
        const SizedBox(height: 2),
        Text(sub, textAlign: TextAlign.center, style: A.t(9, c: A.muted, w: FontWeight.w700)),
      ]),
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
    final variants = p['variants'] is List ? (p['variants'] as List).cast<Map>() : <Map>[];
    if (variants.isEmpty) return true;
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty) {
      return selSize >= 0 && selSize < variants.length;
    }
    if (selColor.isEmpty) return false;
    final rows = variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
    return selSize >= 0 && selSize < rows.length;
  }

  /// كمية مخزون التركيبة المختارة
  int get _selStock {
    final variants = p['variants'] is List ? (p['variants'] as List).cast<Map>() : <Map>[];
    if (variants.isEmpty) return 0;
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty) {
      return selSize >= 0 && selSize < variants.length ? ((variants[selSize]['stock'] as num?)?.toInt() ?? 0) : 0;
    }
    if (selColor.isEmpty) return 0;
    final rows = variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
    return selSize >= 0 && selSize < rows.length ? ((rows[selSize]['stock'] as num?)?.toInt() ?? 0) : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Loader());
    if (p == null) return const Scaffold(body: EmptyState(icon: '🤷', title: 'المنتج غير موجود'));
    final prod = Product.fromJson(Map<String, dynamic>.from(p));
    final variants = p['variants'] is List ? (p['variants'] as List).cast<Map>() : <Map>[];
    // المتغيرات على شكل تركيبات (لون + مقاس) — كل صف بمخزونه
    final colorList = _distinctColors(variants);
    final colorRows = selColor.isEmpty ? <Map>[] : variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
    final hasVariant = variants.isNotEmpty;
    final offPct = prod.hasOffer && prod.price > 0
        ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(children: [
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
                    itemBuilder: (_, i) => productImageBox(_imageList[i], base: Api.base),
                  ),
                  if (_imageList.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: _dots(),
                    ),
                ]),
              ),
              // ═══ معلومات المنتج ═══
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (store?['name'] != null)
                      Flexible(
                        child: Text('${store['name']}', style: A.t(11, c: A.primary, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(width: 8),
                    if ((store?['rating'] ?? 0) as num > 0) ...[
                      const Icon(Icons.star_rounded, size: 14, color: A.star),
                      Text('${(store?['rating'] ?? 0) as num > 0 ? (store['rating'] as num).toStringAsFixed(1) : ''}',
                          style: A.t(11, c: A.ink, w: FontWeight.w900)),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Text(prod.name, style: A.t(19.5, w: FontWeight.w900, h: 1.3)),
                  const SizedBox(height: 12),
                  // السعر — صف منفصل: السعر الكبير + شارة الخصم الحمراء، وتحته السعر السابق والمخزون
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(prod.displayPrice), style: A.t(28, c: A.ink, w: FontWeight.w900)),
                    if (prod.hasOffer) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: A.danger,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: A.danger.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Text('خصم $offPct%', style: A.t(11, c: Colors.white, w: FontWeight.w900)),
                      ),
                    ],
                  ]),
                  if (prod.hasOffer) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(money(prod.price), style: A.t(13, c: A.muted, decoration: TextDecoration.lineThrough, w: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('وفّرت ${money((prod.price - prod.displayPrice).clamp(0, double.infinity))} 🎉', style: A.t(11.5, c: A.success, w: FontWeight.w800)),
                      const Spacer(),
                      if (!prod.outOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: A.success.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
                          child: Text('● متوفر الآن', style: A.t(11, c: A.success, w: FontWeight.w900)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: A.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
                          child: Text('● نفد المخزون', style: A.t(11, c: A.danger, w: FontWeight.w900)),
                        ),
                    ]),
                  ] else ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Spacer(),
                      if (!prod.outOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: A.success.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
                          child: Text('● متوفر الآن · المخزون ${prod.stock}', style: A.t(11, c: A.success, w: FontWeight.w900)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: A.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
                          child: Text('● نفد المخزون', style: A.t(11, c: A.danger, w: FontWeight.w900)),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  // ═══ بوكس المتجر الناشر ═══
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: A.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: A.line),
                    ),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: storeLogo(store?['logo']?.toString() ?? '', size: 46, radius: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(
                              child: Text('${store['name'] ?? ''}', style: A.t(14, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (store['verified'] == true) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded, size: 15, color: A.primary),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 14, color: A.star),
                            Text('${(store['rating'] ?? 0) as num > 0 ? (store['rating'] as num).toStringAsFixed(1) : 'جديد'} · ${store['reviews_count'] ?? 0} تقييم', style: A.t(10.5, c: A.muted, w: FontWeight.w700)),
                            if (store['is_open'] == true) ...[
                              const SizedBox(width: 6),
                              const Text('●', style: TextStyle(fontSize: 8, color: A.success)),
                              const Text('مفتوح الآن', style: TextStyle(fontSize: 10, color: A.success, fontWeight: FontWeight.w700)),
                            ],
                          ]),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(storeId: widget.storeId))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(gradient: A.gradNavy, borderRadius: BorderRadius.circular(10)),
                          child: const Text('المتجر', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ]),
                  ),
                  // ═══ اختيار اللون ثم المقاس — بوكس أنيق ═══
                  if (hasVariant) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: A.line, width: 1.2),
                        boxShadow: const [BoxShadow(color: Color(0x0A0A1120), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: Column(children: [
                        if (colorList.length > 1 || (colorList.length == 1 && colorList.first.isNotEmpty)) ...[
                          Row(children: [
                            const Icon(Icons.palette_outlined, size: 16, color: A.primary),
                            const SizedBox(width: 6),
                            Text('اختر اللون', style: A.t(13, w: FontWeight.w900)),
                            const Spacer(),
                            if (selColor.isNotEmpty)
                              Text(selColor, style: A.t(11, c: A.primary, w: FontWeight.w800)),
                          ]),
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
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selected ? A.primary : A.bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selected ? A.primary : A.line, width: 1.2),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: selected ? Colors.white : A.line, width: 2),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(c.isEmpty ? 'قياسي' : c,
                                        style: A.t(11.5, c: selected ? Colors.white : A.ink, w: FontWeight.w800)),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: A.line),
                          const SizedBox(height: 12),
                        ],
                        // المقاسات
                        Row(children: [
                          const Icon(Icons.straighten_rounded, size: 16, color: A.primary),
                          const SizedBox(width: 6),
                          Text('اختر المقاس', style: A.t(13, w: FontWeight.w900)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _sizeGuideSheet(prod, variants),
                            child: const Row(children: [
                              Icon(Icons.table_chart_outlined, size: 14, color: A.primary),
                              SizedBox(width: 4),
                              Text('دليل المقاسات والقياسات 📐', style: TextStyle(fontSize: 10.5, color: A.primary, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: (selColor.isEmpty && colorList.length > 1)
                                ? colorRows.isEmpty
                                    ? []
                                    : []
                                : (selColor.isEmpty && (colorList.isEmpty || (colorList.length == 1 && colorList.first.isEmpty)))
                                    ? variants.asMap().entries.map((ve) => _sizeChip(ve.key, ve.value)).toList()
                                    : colorRows.asMap().entries.map((ve) => _sizeChip(ve.key, ve.value)).toList(),
                          ),
                        ),
                        // ═══ ملخص التركيبة المختارة ═══
                        if (_variantReady) ...[
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: A.line),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              color: A.success.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: A.success.withValues(alpha: .35)),
                            ),
                            child: Row(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('التركيبة المختارة ✓', style: A.t(11.5, c: A.success, w: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (selColor.isNotEmpty) selColor,
                                    if (selSize >= 0) _selLabel,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: A.t(12, c: A.ink, w: FontWeight.w800),
                                ),
                              ]),
                              const Spacer(),
                              Text('متوفر: $_selStock', style: A.t(12.5, c: A.success, w: FontWeight.w900)),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  // ═══ خدمات التوصيل والدفع — شريط أفقي ═══
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: A.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: A.line),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _serviceChip('🚚', 'توصيل\n30-60 دقيقة', 'داخل الكوت'),
                      _serviceChip('💵', 'كاش عند\nالاستلام', 'ادفع بعد المشاهدة'),
                      _serviceChip('🔄', 'استرجاع\nخلال ${store['warranty_days'] ?? 3} أيام', 'ضمان المتجر'),
                    ]),
                  ),
                  // ═══ التفاصيل والمواصفات — شبكة كاملة مع القياسات ═══
                  const SizedBox(height: 20),
                  Row(children: [
                    const Icon(Icons.notes_rounded, size: 17, color: A.ink),
                    const SizedBox(width: 7),
                    Text('التفاصيل والمواصفات', style: A.t(15.5, w: FontWeight.w900)),
                    const Spacer(),
                    if (prod.attributes.entries.where((e) => !['size', 'color'].contains(e.key)).isNotEmpty)
                      Text('${prod.attributes.entries.where((e) => !['size', 'color'].contains(e.key)).length} مواصفة', style: A.t(10.5, c: A.muted, w: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: A.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: A.line),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (prod.attributes.entries.where((e) => !['size', 'color'].contains(e.key)).isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('وصف المتجر الكامل متوفر فوق — التفاصيل الإضافية قريباً',
                                style: TextStyle(fontSize: 12, color: A.muted, fontWeight: FontWeight.w600)),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: prod.attributes.entries
                                .where((e) => !['size', 'color'].contains(e.key))
                                .map((e) => _specChip(e.key, '${e.value}'))
                                .toList(),
                          ),
                        const Divider(height: 18, color: A.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('الوصف:', style: TextStyle(fontSize: 12.5, color: A.muted, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                prod.description.isEmpty ? 'منتج من ${store['name'] ?? ''}' : prod.description,
                                style: A.t(12.5, c: A.ink, h: 1.7, w: FontWeight.w600),
                              ),
                            ),
                          ]),
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
                ]),
              ),
            ],
          ),
          // ═══ شريط علوي زجاجي فوق الصورة ═══
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Row(children: [
              IconGlass(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconGlass(icon: Icons.share_rounded, onTap: _share),
              const SizedBox(width: 6),
              IconGlass(
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: isFav ? A.danger : null,
                onTap: _toggleFav,
              ),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x140A1120), width: 1)),
        ),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(color: A.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: A.line)),
            child: Row(children: [
              IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove, color: A.muted)),
              Text('$qty', style: A.t(16, w: FontWeight.w900)),
              IconButton(onPressed: qty < 20 ? () => setState(() => qty++) : null, icon: const Icon(Icons.add, color: A.primary)),
            ]),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 10),
          Expanded(
            child: SolidBtn(
              label: prod.outOfStock
                  ? 'غير متوفر'
                  : hasVariant && !_variantReady
                      ? 'اختر اللون والمقاس أولاً 👆'
                      : 'أضف للسلة · ${money(prod.displayPrice * qty)}',
              color: prod.outOfStock || (hasVariant && !_variantReady) ? A.primary : A.accent,
              disabled: prod.outOfStock || (hasVariant && !_variantReady),
              onTap: _addToCart,
            ),
          ),
        ]),
      ),
    );
  }

  String get _selLabel {
    final variants = p['variants'] is List ? (p['variants'] as List).cast<Map>() : <Map>[];
    if (selSize < 0 || selSize >= variants.length) return '';
    final colorList = _distinctColors(variants);
    if (colorList.length == 1 && colorList.first.isEmpty) return '${variants[selSize]['name'] ?? ''}';
    final rows = variants.where((v) => '${v['color'] ?? ''}' == selColor).toList();
    if (selSize < 0 || selSize >= rows.length) return '';
    return '${rows[selSize]['name'] ?? ''}';
  }

  Widget _sizeChip(int index, Map v) {
    final selected = selSize == index;
    final soldOut = ((v['stock'] as num?)?.toInt() ?? 0) == 0;
    return GestureDetector(
      onTap: soldOut ? null : () => setState(() => selSize = selected ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? A.primary : A.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? A.primary : A.line, width: 1.2),
        ),
        child: Column(children: [
          Text('${v['name'] ?? ''}', style: A.t(13, c: selected ? Colors.white : A.ink, w: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(soldOut ? 'نفد' : '${v['stock'] ?? 0} متوفر',
              style: A.t(9.5, c: selected ? Colors.white.withValues(alpha: .85) : (soldOut ? A.danger : A.muted), w: FontWeight.w700)),
        ]),
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
              color: i == imgIdx ? A.primary : Colors.white.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
    final letterSizes = variants.map((v) => '${v['name'] ?? ''}'.toUpperCase()).where((s) => chart.containsKey(s)).toSet();
    showSheet(context, Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetTitle('دليل المقاسات والقياسات 📐'),
          const SizedBox(height: 12),
          if (letterSizes.isNotEmpty) ...[
            Text('💡 حسب القياسات التقريبية الشائعة (بشكل اعتمدها المتجر):', style: A.t(12, c: A.muted, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: A.line)),
              child: Table(
                border: TableBorder.all(color: A.line),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(decoration: const BoxDecoration(color: A.bg), children: [
                    for (final h in ['المقاس', 'الصدر (سم)', 'الخصر (سم)', 'الطول (سم)'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Center(child: Text(h, style: A.t(10.5, w: FontWeight.w900))),
                      ),
                  ]),
                  for (final s in chart.entries.where((e) => letterSizes.contains(e.key)))
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Center(child: Text(s.key, style: A.t(11, w: FontWeight.w900))),
                      ),
                      for (final m in s.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Center(child: Text(m, style: A.t(11, w: FontWeight.w700))),
                        ),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('* قيم تقريبية — قد تختلف بين المصنّعين، والمتجر يحدد المقاس المناسب عند الاستلام.',
                style: A.t(9.5, c: A.muted, w: FontWeight.w600)),
            const SizedBox(height: 12),
          ],
          Text('مقاسات المتوفر حالياً وحالة المخزون:', style: A.t(12, c: A.muted, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: A.line, borderRadius: BorderRadius.circular(12)),
            children: [
              TableRow(decoration: const BoxDecoration(color: A.bg), children: [
                for (final h in ['المقاس', 'المتوفر', 'الحالة'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(child: Text(h, style: A.t(11.5, w: FontWeight.w900))),
                  ),
              ]),
              for (final v in variants)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(child: Text('${v['name'] ?? ''}', style: A.t(11.5, w: FontWeight.w800))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(child: Text('${v['stock'] ?? 0}', style: A.t(11.5, w: FontWeight.w800))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: ((v['stock'] as num?)?.toInt() ?? 0) > 0 ? A.success.withValues(alpha: .1) : A.danger.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(((v['stock'] as num?)?.toInt() ?? 0) > 0 ? 'متوفر' : 'نفد',
                            style: A.t(10, c: ((v['stock'] as num?)?.toInt() ?? 0) > 0 ? A.success : A.danger, w: FontWeight.w900)),
                      ),
                    ),
                  ),
                ]),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: A.primary.withValues(alpha: .06), borderRadius: BorderRadius.circular(12), border: Border.all(color: A.primary.withValues(alpha: .25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📏 كيف تقيس بشكل صحيح؟', style: A.t(12, c: A.primary, w: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('• الصدر: محيط أوسع نقطة تحت الإبط\n• الخصر: أنحف نقطة فوق السرة\n• الطول: من الكتف حتى نهاية الثوب — وقارنها بالجدول',
                  style: A.t(11, c: A.ink, h: 1.9, w: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('مقاس غير مناسب؟ اضغط أي مقاس بأعلى الصفحة وسيُحفظ اختيارك تلقائياً 👌',
              style: A.t(11.5, c: A.muted, w: FontWeight.w700), textAlign: TextAlign.center),
        ]),
      ),
    ));
  }

  void _share() {
    final nm = (p?['name'] as String?) ?? 'منتج';
    final pr = (p?['has_offer'] == true || p?['has_offer'] == 1) ? (p?['offer_price'] ?? 0) : (p?['price'] ?? 0);
    Share.share('شوف هذا المنتج على زبون 🛍️\n$nm — ${money(pr)}\nhttps://zaboon.app/p/${widget.productId}');
  }

  Future<void> _toggleFav() async {
    if (!Api.logged) {
      toast(context, 'سجل دخولك لحفظ المفضلة');
      return;
    }
    try {
      final d = await Api.post('/api/customer/favorites', {'product_id': widget.productId});
      setState(() => isFav = d['favorite'] == true);
      toast(context, d['favorite'] == true ? 'انضاف للمفضلة ❤️' : 'انحذف من المفضلة');
      AppState.i.favsReload.value++;
    } catch (e) {
      toast(context, '$e', error: true);
    }
  }


  /// صور المنتج: عمود images (من المعرض) وإن فاضي → الصورة الأساسية
  List<String> get _imageList {
    final raw = p?['images'];
    final imgs = raw is List
        ? raw.map((s) => s.toString().trim()).where((s) => s.isNotEmpty).toList()
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('⭐', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text('التقييمات والمراجعات', style: A.t(15.5, w: FontWeight.w900)),
        const Spacer(),
        if (total > 0)
          Text('${total.toStringAsFixed(1)} ★', style: A.t(14, c: const Color(0xFFFBBF24), w: FontWeight.w900)),
      ]),
      const SizedBox(height: 8),
      if (reviews.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: A.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: A.line)),
          child: Text('لا توجد تقييمات بعد — كن أول من يقيّم 🖊️', style: A.t(12.5, c: A.muted, w: FontWeight.w700)),
        )
      else ...[
        Text('بناء على $count تقييم من العملاء', style: A.t(11, c: A.muted, w: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final rev in reviews.take(9)) _reviewCard(Map<String, dynamic>.from(rev)),
      ],
    ]);
  }

  Widget _reviewCard(Map<String, dynamic> rev) {
    final rating = ((rev['rating'] ?? 0) as num).toInt().clamp(0, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: A.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: A.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Text('${(rev['user_name'] ?? '👤').toString().trim()}'.isEmpty ? '👤' : '${rev['user_name'] ?? '👤'}'.substring(0, 1), style: A.t(12, c: A.primary, w: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${rev['user_name'] ?? 'عميل'}', style: A.t(12.5, w: FontWeight.w900))),
              Text('${rev['created_at']?.toString().substring(0, 10) ?? ''}', style: A.t(10, c: A.muted)),
            ]),
            const SizedBox(height: 3),
            Text('★' * rating + '☆' * (5 - rating), style: A.t(13, c: const Color(0xFFFBBF24))),
            if ('${rev['comment'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('${rev['comment']}', style: A.t(12, c: A.muted, h: 1.5)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _productsRow(String title, List list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: A.t(15.5, w: FontWeight.w900)),
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
              child: _ProdCard(product: m, onOpen: () => pushProduct(context, sid, Product.fromJson(m).id)),
            );
          },
        ),
      ),
    ]);
  }
}
