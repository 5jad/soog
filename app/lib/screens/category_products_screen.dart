import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customer_shell.dart';

/// صفحة منتجات فئة معينة — شبكة متلاصقة + فلترة بأسلوب شي إن/إيباي
class CategoryProductsScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  const CategoryProductsScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List products = [];
  bool loading = true;

  // ═══ حالة الفلترة ═══
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
    _loadMeta();
  }

  @override
  void dispose() {
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

  Future<void> _loadMeta() async {
    try {
      final d = await Api.get('/api/products/meta?category_id=${widget.categoryId}');
      metaColors = d['colors'] ?? [];
      metaSizes = d['sizes'] ?? [];
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final q = <String>['category_id=${widget.categoryId}'];
    if (sort != 'newest') q.add('sort=$sort');
    if (minC.text.trim().isNotEmpty) q.add('min_price=${minC.text.trim()}');
    if (maxC.text.trim().isNotEmpty) q.add('max_price=${maxC.text.trim()}');
    if (selColors.isNotEmpty) q.add('colors=${selColors.join(',')}');
    if (selSizes.isNotEmpty) q.add('sizes=${selSizes.join(',')}');
    if (offerOnly) q.add('offer=true');
    try {
      final d = await Api.get('/api/products?${q.join('&')}');
      products = d['products'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      sort = 'newest';
      minC.clear();
      maxC.clear();
      selColors.clear();
      selSizes.clear();
      offerOnly = false;
    });
    _load();
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

  Future<void> _openFilters() async {
    final applied = await _openFilterSheet();
    if (applied == true) _load();
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
                  TextButton(onPressed: _clearFilters, child: const Text('مسح الكل', style: TextStyle(fontWeight: FontWeight.w800, color: A.danger))),
                  IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close_rounded)),
                ]),
                // الترتيب
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
                // السعر
                Text('السعر (د.ع)', style: A.t(12.5, w: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _priceField('من', minC)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: TextStyle(fontSize: 14, color: A.muted))),
                  Expanded(child: _priceField('إلى', maxC)),
                ]),
                const SizedBox(height: 16),
                // الألوان
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
                // المقاسات
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
                // العروض فقط
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

  @override
  Widget build(BuildContext context) {
    final active = hasFilters;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName}'),
        actions: [
          IconButton(
            onPressed: _openFilters,
            tooltip: 'فلاتر',
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.tune_rounded),
              if (active)
                Positioned(
                  left: -2, top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                    child: Text('${[sort != 'newest' ? 1 : 0, minC.text.trim().isNotEmpty || maxC.text.trim().isNotEmpty ? 1 : 0, selColors.length > 0 ? 1 : 0, selSizes.length > 0 ? 1 : 0, offerOnly ? 1 : 0].reduce((a, b) => a + b)}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        // شرائح الفلاتر النشطة (مثل شي إن)
        if (active)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              children: [
                if (sort != 'newest')
                  _activeChip(_sortLabel(sort), () => setState(() { sort = 'newest'; _load(); })),
                if (minC.text.trim().isNotEmpty || maxC.text.trim().isNotEmpty)
                  _activeChip('سعر: ${minC.text.trim().isEmpty ? '0' : minC.text.trim()}-${maxC.text.trim().isEmpty ? '∞' : maxC.text.trim()}', () => setState(() { minC.clear(); maxC.clear(); _load(); })),
                for (final c in List.of(selColors))
                  _activeChip('لون: $c', () => setState(() { selColors.remove(c); _load(); })),
                for (final s in List.of(selSizes))
                  _activeChip('مقاس: $s', () => setState(() { selSizes.remove(s); _load(); })),
                if (offerOnly)
                  _activeChip('عروض فقط', () => setState(() { offerOnly = false; _load(); })),
                _activeChip('مسح الكل', _clearFilters, danger: true),
              ],
            ),
          ),
        Expanded(
          child: loading
              ? const Loader()
              : Stack(children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    color: A.primary,
                    child: products.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 120),
                            EmptyState(icon: '📦', title: 'ماكو منتجات مطابقة للفلترة'),
                          ])
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 0,
                              crossAxisSpacing: 0,
                              childAspectRatio: 0.55,
                            ),
                            itemCount: products.length,
                            itemBuilder: (_, i) {
                              final m = Map<String, dynamic>.from(products[i] as Map);
                              final p = Product.fromJson(m);
                              final storeId = (products[i]['store_id'] as num?)?.toInt() ?? 0;
                              return GestureDetector(
                                onTap: () => pushProduct(context, storeId, p.id),
                                child: Container(
                                  decoration: A.glass(radius: 0),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    AspectRatio(
                                      aspectRatio: 3 / 4,
                                      child: Stack(fit: StackFit.expand, children: [
                                        productImageBox(p.image),
                                        if (p.hasOffer)
                                          Positioned(
                                            top: 8, right: 8,
                                            child: BadgeWow('خصم ${p.price > 0 ? (((p.price - p.displayPrice) / p.price) * 100).round() : 0}%'),
                                          ),
                                        if (p.outOfStock) Positioned(top: 8, left: 8, child: BadgeWow('نفد', dark: true)),
                                      ]),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(products[i]['store_name']?.toString() ?? '', style: A.t(9.5, c: A.primary, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(p.name, style: A.t(11, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        if (p.hasOffer) ...[
                                          const SizedBox(height: 2),
                                          Text(money(p.price), style: A.t(9.5, c: A.muted, decoration: TextDecoration.lineThrough)),
                                        ],
                                        const SizedBox(height: 2),
                                        Row(children: [
                                          Expanded(child: Text(money(p.displayPrice), style: A.t(13.5, c: A.accent, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          GestureDetector(
                                            onTap: () => quickAdd(context, m),
                                            child: Container(
                                              width: 28, height: 28,
                                              decoration: BoxDecoration(gradient: A.gradSun, borderRadius: BorderRadius.circular(9)),
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                                            ),
                                          ),
                                        ]),
                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                ]),
        ),
      ]),
    );
  }

  String _sortLabel(String s) => switch (s) {
        'best' => 'الأفضل تقييماً',
        'discount' => 'الأكثر خصماً',
        'price_asc' => 'السعر: من الأقل',
        'price_desc' => 'السعر: من الأعلى',
        _ => 'الأحدث',
      };

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