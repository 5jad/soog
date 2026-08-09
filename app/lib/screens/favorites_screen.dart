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
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/customer/favorites');
      favs = d['products'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة ❤️')),
      body: loading
          ? const Loader()
          : favs.isEmpty
              ? const EmptyState(icon: '🤍', title: 'لا مفضلة بعد', sub: 'اضغط ♡ على أي منتج يعجبك')
              : RefreshIndicator(
                  onRefresh: _load,
                  color: A.primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
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
                      return GestureDetector(
                        onTap: () => pushProduct(context, storeId, prod.id),
                        child: Container(
                          margin: const EdgeInsets.all(7),
                          decoration: A.glass(radius: 16),
                          clipBehavior: Clip.antiAlias,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Stack(fit: StackFit.expand, children: [
                                productImageBox(prod.image),
                                if (prod.outOfStock)
                                  Positioned(top: 8, left: 8, child: BadgeWow('نفد', dark: true)),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await Api.post('/api/customer/favorites', {'product_id': prod.id});
                                      _load();
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.favorite_rounded, color: A.danger, size: 16),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${f['store_name'] ?? ''}', style: A.t(9.5, c: A.primary, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(prod.name, style: A.t(11, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(money(prod.displayPrice), style: A.t(13.5, c: A.accent, w: FontWeight.w900)),
                              ]),
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