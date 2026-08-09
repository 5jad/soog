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
  int? cat;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    ctrl.text = q;
    cat = widget.categoryId;
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
    if (cat != null) list = list.where((s) => s.categoryId == cat).toList();
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
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: A.glass(radius: 999, soft: true),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded, color: A.primary, size: 14),
              const SizedBox(width: 5),
              Text('واسط · الكوت', style: A.t(12, c: A.primary, w: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${all.length} متجر متاح', style: A.t(10.5, c: A.muted, w: FontWeight.w600)),
        ]),
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
              // البحث — بنفس قياسات صفحة الرئيسية
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              // شريط الفئات — بنفس قياسات صفحة الرئيسية
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
                          label: '${c['icon'] ?? ''} ${c['name'] ?? ''}',
                          active: cat == c['id'],
                          onTap: () => setState(() => cat = cat == c['id'] ? null : c['id']),
                        ),
                      ),
                  ],
                ),
              ),
              // المتاجر المتابعة — أسفل شريط الفئات
              if (favorites.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(children: [
                    const Icon(Icons.storefront_rounded, size: 17, color: A.primary),
                    const SizedBox(width: 7),
                    Text('متاجر متابعتن', style: A.t(13, w: FontWeight.w900)),
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
                              decoration: A.glass(radius: 16),
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

  /// بطاقة متجر داخل شبكة المتاجر
  Widget _storeGridItem(Store s, int i) {
    final cover = _covers[i % _covers.length];
    final hasCover = isUrlCover(s.cover ?? '');
    return GestureDetector(
      onTap: () => widget.onOpen(s),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: A.glass(radius: 0),
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