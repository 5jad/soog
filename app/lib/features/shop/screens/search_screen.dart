import 'package:flutter/material.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/screens/home_screen.dart';
import 'package:zaboon/features/shop/screens/category_products_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/customer_shell.dart';

/// صفحة البحث والفئات — بدل تبويب السلة السابق
/// تصميم مستوحى من المتاجر العالمية: شريط بحث ثابت + شيبز فئات +
/// ترند اليوم + جديد عندنا + فلترة كاملة (ترتيب/سعر/لون/مقاس/عروض)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final qCtrl = TextEditingController();
  final minC = TextEditingController();
  final maxC = TextEditingController();
  String q = '';
  List categories = [];
  Map catProducts = {};
  List trending = [];
  List recent = [];
  final List<Map<String, dynamic>> selCats = [];
  String sort = 'newest';
  final List<String> selColors = [];
  final List<String> selSizes = [];
  bool offerOnly = false;
  List metaColors = [];
  List metaSizes = [];
  List gridProducts = [];
  bool gridLoading = false;
  bool gridLoadingMore = false;
  int gridTotal = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  @override
  void dispose() {
    qCtrl.dispose();
    minC.dispose();
    maxC.dispose();
    super.dispose();
  }

  bool get hasFilters =>
      sort != 'newest' ||
      minC.text.trim().isNotEmpty ||
      maxC.text.trim().isNotEmpty ||
      selColors.isNotEmpty ||
      selSizes.isNotEmpty ||
      offerOnly;

  bool get resultsMode => q.isNotEmpty || selCats.isNotEmpty || hasFilters;

  int get activeFiltersCount => [
    sort != 'newest' ? 1 : 0,
    minC.text.trim().isNotEmpty || maxC.text.trim().isNotEmpty ? 1 : 0,
    selColors.isNotEmpty ? 1 : 0,
    selSizes.isNotEmpty ? 1 : 0,
    offerOnly ? 1 : 0,
  ].reduce((a, b) => a + b);

  /// الواجهة التصفحية: الفئات + الترند + الجديد
  Future<void> _loadExplore() async {
    try {
      final d = await Api.get('/api/categories');
      categories = d['categories'] ?? [];
      final results = await Future.wait([
        Api.get('/api/products?best=true'),
        Api.get('/api/products'),
        for (final c in categories)
          Api.get('/api/products?category_id=${c['id']}&limit=6'),
      ]);
      trending = results[0]['products'] ?? [];
      recent = results[1]['products'] ?? [];
      catProducts = {
        for (var i = 0; i < categories.length; i++)
          categories[i]['id']: (results[i + 2]['products'] ?? []),
      };
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadGrid() async {
    setState(() => gridLoading = true);
    final qs = <String>[];
    if (selCats.isNotEmpty) {
      qs.add('category_id=${selCats.map((c) => c['id']).join(',')}');
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
      final d = await Api.get('/api/products?${qs.join('&')}&limit=24');
      gridProducts = d['products'] ?? [];
      gridTotal = (d['total'] ?? gridProducts.length) as int;
    } catch (_) {
    } finally {
      if (mounted) setState(() => gridLoading = false);
    }
  }

  /// يجلب الصفحة التالية من نتائج البحث ويضيفها للشبكة
  Future<void> _loadGridMore() async {
    if (gridLoadingMore || gridLoading || gridProducts.length >= gridTotal) {
      return;
    }
    setState(() => gridLoadingMore = true);
    final qs = <String>[];
    if (selCats.isNotEmpty) {
      qs.add('category_id=${selCats.map((c) => c['id']).join(',')}');
    }
    if (q.isNotEmpty) qs.add('q=$q');
    if (sort != 'newest') qs.add('sort=$sort');
    if (minC.text.trim().isNotEmpty) qs.add('min_price=${minC.text.trim()}');
    if (maxC.text.trim().isNotEmpty) qs.add('max_price=${maxC.text.trim()}');
    if (selColors.isNotEmpty) qs.add('colors=${selColors.join(',')}');
    if (selSizes.isNotEmpty) qs.add('sizes=${selSizes.join(',')}');
    if (offerOnly) qs.add('offer=true');
    try {
      final d = await Api.get(
        '/api/products?${qs.join('&')}&limit=24&offset=${gridProducts.length}',
      );
      final more = d['products'] ?? [];
      if (!mounted) return;
      setState(() {
        if (more.isEmpty) {
          gridTotal = gridProducts.length;
        } else {
          final seen = <int>{for (final p in gridProducts) p['id'] as int};
          gridProducts = [
            ...gridProducts,
            ...[
              for (final p in more)
                if (seen.add(p['id'] as int)) p
            ],
          ];
          gridTotal = (d['total'] ?? gridProducts.length) as int;
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => gridLoadingMore = false);
    }
  }

  Future<void> _loadMeta() async {
    try {
      final d = await Api.get(
        '/api/products/meta?category_id=${selCats.map((c) => c['id']).join(',')}',
      );
      metaColors = d['colors'] ?? [];
      metaSizes = d['sizes'] ?? [];
    } catch (_) {}
  }

  /// تبديل فئة — الزبون يحدد أكثر من فئة بنفس الوقت
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

  void _removeCat(Map c) {
    setState(() => selCats.removeWhere((x) => x['id'] == c['id']));
    _loadGrid();
  }

  /// مسح كل شي — نرجع لوضع التصفح
  void _clearAll() {
    qCtrl.clear();
    setState(() {
      q = '';
      selCats.clear();
      _resetFilters();
    });
    _loadGrid();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _loadGrid();
  }

  Widget _chipFilter(String val, String label, String cur, ValueChanged onTap) {
    final active = cur == val;
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppType.style(
            11.5,
            color: active ? Colors.white : AppColors.ink,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _priceField(String hint, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Color _dot(String name) {
    final n = '$name'.toLowerCase().trim();
    const map = {
      'أحمر': Color(0xFFE7352B),
      'احمر': Color(0xFFE7352B),
      'red': Color(0xFFE7352B),
      'أزرق': Color(0xFF2453CB),
      'ازرق': Color(0xFF2453CB),
      'blue': Color(0xFF2453CB),
      'أسود': Color(0xFF202126),
      'اسود': Color(0xFF202126),
      'black': Color(0xFF202126),
      'أبيض': Color(0xFFF5F5F5),
      'ابيض': Color(0xFFF5F5F5),
      'white': Color(0xFFF5F5F5),
      'أخضر': Color(0xFF1E8A4C),
      'اخضر': Color(0xFF1E8A4C),
      'green': Color(0xFF1E8A4C),
      'أصفر': Color(0xFFF2C513),
      'اصفر': Color(0xFFF2C513),
      'yellow': Color(0xFFF2C513),
      'بنفسجي': Color(0xFF7C3AED),
      'purple': Color(0xFF7C3AED),
      'وردي': Color(0xFFF472B6),
      'pink': Color(0xFFF472B6),
      'رمادي': Color(0xFF9CA3AF),
      'grey': Color(0xFF9CA3AF),
      'بني': Color(0xFF7C4A23),
      'brown': Color(0xFF7C4A23),
      'برتقالي': Color(0xFFF97316),
      'orange': Color(0xFFF97316),
      'بيج': Color(0xFFE5CBB0),
      'ذهبي': Color(0xFFD4AF37),
    };
    return map.entries
        .firstWhere(
          (e) => n.contains(e.key),
          orElse: () => const MapEntry('', Color(0xFFD9DEE7)),
        )
        .value;
  }

  String _sortLabel(String s) => switch (s) {
    'best' => 'الأفضل تقييماً',
    'discount' => 'الأكثر خصماً',
    'price_asc' => 'السعر: من الأقل',
    'price_desc' => 'السعر: من الأعلى',
    _ => 'الأحدث',
  };

  Future<void> _openFilterSheet() async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // نص الشاشة على طبقة صلبة فوق الزجاج (القاعدة 3)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'الفلترة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              qCtrl.clear();
                              q = '';
                              _clearAll();
                              setS(() {});
                            },
                            child: const Text(
                              'مسح الكل',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الفئة',
                        style: AppType.style(12.5, weight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          GestureDetector(
                            onTap: () => setS(() {
                              final id = c['id'];
                              final i = selCats.indexWhere(
                                (x) => x['id'] == id,
                              );
                              if (i >= 0) {
                                selCats.removeAt(i);
                              } else {
                                selCats.add(
                                  Map<String, dynamic>.from(c as Map),
                                );
                              }
                              _resetFilters();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selCats.any((x) => x['id'] == c['id'])
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: selCats.any((x) => x['id'] == c['id'])
                                      ? AppColors.primary
                                      : AppColors.line,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${c['icon'] ?? '🛍'} ',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${c['name'] ?? ''}',
                                    style: AppType.style(
                                      11.5,
                                      color:
                                          selCats.any((x) => x['id'] == c['id'])
                                          ? Colors.white
                                          : AppColors.ink,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الترتيب',
                        style: AppType.style(12.5, weight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipFilter(
                          'newest',
                          'الأحدث',
                          sort,
                          (v) => setS(() => sort = v as String),
                        ),
                        _chipFilter(
                          'best',
                          'الأفضل تقييماً',
                          sort,
                          (v) => setS(() => sort = v as String),
                        ),
                        _chipFilter(
                          'discount',
                          'الأكثر خصماً',
                          sort,
                          (v) => setS(() => sort = v as String),
                        ),
                        _chipFilter(
                          'price_asc',
                          'السعر: من الأقل',
                          sort,
                          (v) => setS(() => sort = v as String),
                        ),
                        _chipFilter(
                          'price_desc',
                          'السعر: من الأعلى',
                          sort,
                          (v) => setS(() => sort = v as String),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'السعر (د.ع)',
                        style: AppType.style(12.5, weight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _priceField('من', minC)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Expanded(child: _priceField('إلى', maxC)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (metaColors.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'اللون',
                          style: AppType.style(12.5, weight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in metaColors) ...[
                            GestureDetector(
                              onTap: () => setS(() {
                                selColors.contains(c)
                                    ? selColors.remove(c)
                                    : selColors.add('$c');
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: selColors.contains(c)
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selColors.contains(c)
                                        ? AppColors.primary
                                        : AppColors.line,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: _dot('$c'),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$c',
                                      style: AppType.style(
                                        11.5,
                                        color: selColors.contains(c)
                                            ? Colors.white
                                            : AppColors.ink,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (metaSizes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'المقاس',
                          style: AppType.style(12.5, weight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in metaSizes) ...[
                            GestureDetector(
                              onTap: () => setS(() {
                                selSizes.contains(s)
                                    ? selSizes.remove(s)
                                    : selSizes.add('$s');
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: selSizes.contains(s)
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: selSizes.contains(s)
                                        ? AppColors.primary
                                        : AppColors.line,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  '$s',
                                  style: AppType.style(
                                    11.5,
                                    color: selSizes.contains(s)
                                        ? Colors.white
                                        : AppColors.ink,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.accent,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'العروض والخصومات فقط',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Switch(
                            value: offerOnly,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setS(() => offerOnly = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SolidBtn(
                      label: 'عرض النتائج',
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (applied == true) _loadGrid();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _searchRow(),
            Expanded(child: resultsMode ? _resultsView() : _exploreView()),
          ],
        ),
      ),
    );
  }

  /// شريط البحث + زر الفلترة (ثابتان أعلى الصفحة مثل المتاجر العالمية)
  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: qCtrl,
              onChanged: (v) => setState(() => q = v.trim()),
              onSubmitted: (_) => _submit(),
              style: AppType.style(13, weight: FontWeight.w700),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج أو لون أو مقاس... 🔍',
                hintStyle: AppType.style(
                  12.5,
                  color: AppColors.muted,
                  weight: FontWeight.w600,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: _submit,
                ),
                suffixIcon: q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: AppColors.muted,
                        ),
                        onPressed: () {
                          qCtrl.clear();
                          setState(() => q = '');
                          if (resultsMode) _loadGrid();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.line,
                    width: 1.1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasFilters ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFilters ? AppColors.primary : AppColors.line,
                  width: 1.2,
                ),
                boxShadow: hasFilters
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 22,
                    color: hasFilters ? Colors.white : AppColors.ink,
                  ),
                  if (hasFilters)
                    Positioned(
                      left: -6,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$activeFiltersCount',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// قسم فئة: عنوان + زر «عرض الكل» + شريط منتجاتها بصفين
  Widget _catSection(Map c) {
    final prods = catProducts[c['id']] ?? <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Row(
            children: [
              Text('${c['icon'] ?? '🛍'}  ', style: AppType.style(17)),
              Expanded(
                child: SectionTitle(
                  '${c['name'] ?? ''}',
                  onMore: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryProductsScreen(
                        categoryId: (c['id'] as num).toInt(),
                        categoryName: '${c['name'] ?? ''}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (prods.isEmpty)
          const SizedBox.shrink()
        else
          prodStrip(context, prods),
      ],
    );
  }

  /// وضع التصفح: ترند اليوم + الفئات بشرائطها + جديد عندنا
  Widget _exploreView() {
    if (loading) return const Loader();
    return RefreshIndicator(
      onRefresh: _loadExplore,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.accent,
                  size: 21,
                ),
                const SizedBox(width: 6),
                Expanded(child: SectionTitle('ترند اليوم')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (trending.isEmpty)
            const SizedBox.shrink()
          else
            prodStrip(context, trending),
          for (final c in categories) _catSection(c),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(child: SectionTitle('جديد عندنا')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'ماكو منتجات للعرض حالياً',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            prodStrip(context, recent),
        ],
      ),
    );
  }

  /// وضع النتائج: شبكة المنتجات بعد البحث أو الفئة أو الفلترة
  Widget _resultsView() {
    final chips = <Widget>[];
    for (final c in selCats) {
      chips.add(_miniChip('${c['name']}', () => _removeCat(c), danger: true));
    }
    if (sort != 'newest') {
      chips.add(
        _miniChip(
          _sortLabel(sort),
          () => setState(() {
            sort = 'newest';
            _loadGrid();
          }),
        ),
      );
    }
    if (offerOnly) {
      chips.add(
        _miniChip(
          'العروض فقط',
          () => setState(() {
            offerOnly = false;
            _loadGrid();
          }),
        ),
      );
    }
    if (chips.isNotEmpty) {
      chips.add(_miniChip('مسح الكل', _clearAll, danger: true));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${gridProducts.length} نتيجة',
                  style: AppType.style(
                    12,
                    color: AppColors.muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
        Expanded(
          child: gridLoading
              ? const Loader()
              : gridProducts.isEmpty
              ? EmptyState(
                  icon: '🤷',
                  title: 'لا توجد نتائج',
                  sub: 'جرّب كلمة أخرى أو امسح الفلاتر',
                  lottie: 'no_results', // حالة عدم نتائج البحث — once
                  action: 'مسح الفلاتر',
                  onAction: _clearAll,
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 6),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 0,
                          childAspectRatio: 0.55,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final m = Map<String, dynamic>.from(
                              gridProducts[i] as Map,
                            );
                            return ProdCard(
                              product: m,
                              onOpen: () => pushProduct(
                                context,
                                m['store_id'],
                                m['id'],
                              ),
                            );
                          },
                          childCount: gridProducts.length,
                        ),
                      ),
                    ),
                    // زر عرض المزيد — يتوفر للنصف الثاني من النتائج
                    if (gridProducts.length < gridTotal)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: GlassCard(
                            onTap: gridLoadingMore ? null : _loadGridMore,
                            child: Center(
                              child: gridLoadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      'عرض المزيد (${gridTotal - gridProducts.length} متبقي)',
                                      style: AppType.style(
                                        13,
                                        color: AppColors.primary,
                                        weight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _miniChip(String label, VoidCallback onTap, {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: danger
              ? AppColors.danger.withOpacity(0.08)
              : AppColors.primary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: danger ? AppColors.danger : AppColors.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              size: 14,
              color: danger ? AppColors.danger : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppType.style(
                10.5,
                color: danger ? AppColors.danger : AppColors.primary,
                weight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
