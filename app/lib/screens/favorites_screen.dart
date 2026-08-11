import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customer_shell.dart';

/// المفضلة — تبويب بالشريط السفلي
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List favs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AppState.i.favsReload.addListener(_load);
  }

  @override
  void dispose() {
    AppState.i.favsReload.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/customer/favorites');
      favs = d['products'] ?? [];
      AppState.i.favsCount.value = favs.length;
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _unfav(Map<String, dynamic> prod) async {
    await Api.del('/api/customer/favorites/${prod['id']}');
    _load();
  }

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
          : favs.isEmpty
              ? const EmptyState(icon: '🤍', title: 'لا مفضلة بعد', sub: 'اضغط ♡ على أي منتج يعجبك', lottie: 'fav_empty')
              : RefreshIndicator(
                  onRefresh: _load,
                  color: A.primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: favs.length,
                    itemBuilder: (_, i) {
                      final f = Map<String, dynamic>.from(favs[i] as Map);
                      final prod = Product.fromJson(f);
                      final storeId = (f['store_id'] as num?)?.toInt() ?? 0;
                      final offPct = prod.hasOffer && prod.price > 0
                          ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
                          : 0;
                      final dots = <Color>[];
                      for (final v in (prod.variants as List)) {
                        final c = _dotsColor('${v is Map ? (v['color'] ?? (v['name'] ?? '')) : v}');
                        if (!dots.contains(c)) dots.add(c);
                      }
                      return GestureDetector(
                        onTap: () => pushProduct(context, storeId, prod.id),
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
                                // قلب — إزالة من المفضلة
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => _unfav(f),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.favorite_rounded, color: A.danger, size: 17),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${f['store_name'] ?? ''}',
                                      style: A.t(8.5, c: A.primary, w: FontWeight.w800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(prod.name, style: A.t(10.5, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (dots.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(children: [
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
                                    ]),
                                  ],
                                  if (prod.hasOffer) ...[
                                    const SizedBox(height: 3),
                                    Text(money(prod.price), style: A.t(8.5, c: A.muted, decoration: TextDecoration.lineThrough)),
                                  ],
                                  // السعر + زر الإضافة — مثبتان أسفل كل بوكس
                                  const Spacer(),
                                  Row(children: [
                                    Expanded(child: Text(money(prod.displayPrice), style: A.t(12.5, c: A.ink, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    GestureDetector(
                                      onTap: () => quickAdd(context, f),
                                      child: Container(
                                        width: 26, height: 26,
                                        decoration: BoxDecoration(color: A.primary, borderRadius: BorderRadius.circular(8)),
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
                    },
                  ),
                ),
    );
  }
}