import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notifications_screen.dart';

/// قائمة المتاجر مع بحث وتصفية حسب القسم — بهوية الديمو
class StoresScreen extends StatefulWidget {
  final String? initialQuery;
  final int? categoryId;
  final String? categoryName;
  final void Function(Store) onOpen;
  const StoresScreen({super.key, this.initialQuery, this.categoryId, this.categoryName, required this.onOpen});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  late String q = widget.initialQuery ?? '';
  final ctrl = TextEditingController();
  List all = [];
  List categories = [];
  List favorites = [];
  final List<int> catIds = [];
  String sortStores = 'top';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    ctrl.text = q;
    if (widget.categoryId != null) catIds.add(widget.categoryId!);
    _load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/stores');
      final c = await Api.get('/api/categories');
      all = d['stores'] ?? [];
      AppState.i.storesCount.value = all.length;
      categories = c['categories'] ?? [];
      if (Api.logged) {
        try {
          final f = await Api.get('/api/customer/store-favorites');
          favorites = f['favorites'] ?? [];
        } catch (_) {}
      }
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Store> get filtered {
    var list = all.map((s) => Store.fromJson(Map<String, dynamic>.from(s as Map))).where((s) => s.open).toList();
    if (q.isNotEmpty) list = list.where((s) => s.name.contains(q) || s.categoryName.contains(q)).toList();
    if (catIds.isNotEmpty) list = list.where((s) => catIds.contains(s.categoryId)).toList();
    switch (sortStores) {
      case 'low': list.sort((a, b) => a.rating.compareTo(b.rating));
      case 'most': list.sort((a, b) => b.reviewsCount.compareTo(a.reviewsCount));
      default: list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  static const _covers = [A.gradNavy, A.gradSun, A.gradSky];

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Scaffold(
      backgroundColor: A.bg,
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 14,
        centerTitle: true,
        title: const TopBarPill(),
        actions: [
          const SizedBox(width: 8),
          Stack(clipBehavior: Clip.none, children: [
            IconGlass(
              icon: Icons.notifications_none_rounded,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            Positioned(
              right: -1,
              top: -1,
              child: ValueListenableBuilder<int>(
                valueListenable: AppState.i.unreadNotifs,
                builder: (_, v, __) => CountBadge(v),
              ),
            ),
          ]),
          const SizedBox(width: 10),
        ],
      ),
      body: loading
          ? const Loader()
          : ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
              // البحث + زر الفلترة — بنفس قياسات صفحة الرئيسية
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onChanged: (v) => setState(() => q = v),
                      style: A.t(13, w: FontWeight.w700),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن متجر...',
                        hintStyle: A.t(12.5, c: A.muted, w: FontWeight.w600),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(right: 14, left: 6),
                          child: Icon(Icons.search_rounded, color: A.muted, size: 20),
                        ),
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
                    onTap: _openFilterSheet,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: catIds.isNotEmpty || sortStores != 'top' ? A.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: catIds.isNotEmpty || sortStores != 'top' ? A.primary : A.line, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Icon(Icons.tune_rounded, size: 22, color: catIds.isNotEmpty || sortStores != 'top' ? Colors.white : A.ink),
                        if (catIds.isNotEmpty || sortStores != 'top')
                          Positioned(
                            left: -6,
                            top: -8,
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(color: A.accent, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${catIds.length + (sortStores != 'top' ? 1 : 0)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
              // المتاجر المتابعة
              if (favorites.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(children: [
                    const Icon(Icons.storefront_rounded, size: 17, color: A.primary),
                    const SizedBox(width: 7),
                    Text('متاجر متابعهن', style: A.t(13, w: FontWeight.w900)),
                  ]),
                ),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: [
                      for (final f in favorites)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: GestureDetector(
                            onTap: () {
                              final s = all.where((x) => x['id'] == f['store_id']).firstOrNull;
                              if (s == null) return;
                              widget.onOpen(Store.fromJson(Map<String, dynamic>.from(s as Map)));
                            },
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.all(10),
                              decoration: A.card(radius: A.r16),
                              child: Row(children: [
                                storeLogo('${f['store_logo'] ?? ''}', size: 44, radius: 12),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('${f['store_name'] ?? ''}', style: A.t(11.5, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.star_rounded, size: 11, color: A.star),
                                    Text('${(f['rating'] ?? 0).toStringAsFixed(1)}', style: A.t(10, w: FontWeight.w800)),
                                  ]),
                                ])),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: '🏪', title: 'ماكو متاجر بهذا القسم'))
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 0.68,
                  children: [
                    for (var i = 0; i < list.length; i++) _storeGridItem(list[i], i),
                  ],
                ),
            ]),
    );
  }

  /// بوكس فلترة المتاجر — فئات متعددة + ترتيب
  Future<void> _openFilterSheet() async {
    final tempCatIds = List<int>.from(catIds);
    var sort = sortStores;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: A.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('الفلترة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
              ]),
              Text('الفئة', style: A.t(12.5, w: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in categories)
                  GestureDetector(
                    onTap: () => setS(() {
                      final id = c['id'] as int;
                      tempCatIds.contains(id) ? tempCatIds.remove(id) : tempCatIds.add(id);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: tempCatIds.contains(c['id']) ? A.primary : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tempCatIds.contains(c['id']) ? A.primary : A.line, width: 1.2),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${c['icon'] ?? '🛍'} ', style: const TextStyle(fontSize: 12)),
                        Text('${c['name'] ?? ''}', style: A.t(11.5, c: tempCatIds.contains(c['id']) ? Colors.white : A.ink, w: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Text('الترتيب', style: A.t(12.5, w: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                GestureDetector(
                  onTap: () => setS(() => sort = 'top'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sort == 'top' ? A.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sort == 'top' ? A.primary : A.line, width: 1.2),
                    ),
                    child: Text('الأعلى تقييماً', style: A.t(11.5, c: sort == 'top' ? Colors.white : A.ink, w: FontWeight.w800)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setS(() => sort = 'low'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sort == 'low' ? A.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sort == 'low' ? A.primary : A.line, width: 1.2),
                    ),
                    child: Text('الأقل تقييماً', style: A.t(11.5, c: sort == 'low' ? Colors.white : A.ink, w: FontWeight.w800)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setS(() => sort = 'most'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sort == 'most' ? A.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sort == 'most' ? A.primary : A.line, width: 1.2),
                    ),
                    child: Text('الأكثر تقييماً', style: A.t(11.5, c: sort == 'most' ? Colors.white : A.ink, w: FontWeight.w800)),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: A.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    catIds..clear()..addAll(tempCatIds);
                    sortStores = sort;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('تطبيق', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// بطاقة متجر داخل شبكة المتاجر
  Widget _storeGridItem(Store s, int i) {
    final cover = _covers[i % _covers.length];
    final hasCover = isUrlCover(s.cover ?? '');
    return GestureDetector(
      onTap: () => widget.onOpen(s),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: A.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  productImageBox(s.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: cover),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                    child: Container(
                      width: 48, height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: storeLogo(s.logo, size: 42, radius: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(s.name, style: A.t(11.5, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (s.verified) const SizedBox(width: 3),
                if (s.verified) const VerifiedTag(),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Text('${s.rating.toStringAsFixed(1)}', style: A.t(11, w: FontWeight.w900)),
                const Icon(Icons.star_rounded, size: 13, color: A.star),
                const SizedBox(width: 3),
                Expanded(child: Text('${s.reviewsCount} تقييم', style: A.t(9.5, c: A.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}