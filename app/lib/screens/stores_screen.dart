import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

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
        title: Text(widget.categoryName ?? 'المتاجر'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: ctrl,
              onChanged: (v) => setState(() => q = v),
              style: A.t(13, w: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'ابحث عن متجر...',
                hintStyle: A.t(12.5, c: A.muted, w: FontWeight.w600),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(right: 14, left: 6),
                  child: Icon(Icons.search_rounded, color: A.muted, size: 20),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
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
        ),
      ),
      body: loading
          ? const Loader()
          : Column(children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChipG(label: 'الكل', active: cat == null, onTap: () => setState(() => cat = null)),
                    ),
                    ...categories.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChipG(
                            label: '${c['icon'] ?? ''} ${c['name'] ?? ''}',
                            active: cat == c['id'],
                            onTap: () => setState(() => cat = cat == c['id'] ? null : c['id']),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: '🏪', title: 'ماكو متاجر بهذا القسم')
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 0,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
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
                        },
                      ),
              ),
            ]),
    );
  }
}