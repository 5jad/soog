import 'package:flutter/material.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

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
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _unfav(Map<String, dynamic> prod) async {
    await Api.del('/api/customer/favorites/${prod['id']}');
    _load();
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
          : favs.isEmpty
          ? const EmptyState(
              icon: '🤍',
              title: 'لا مفضلة بعد',
              sub: 'اضغط ♡ على أي منتج يعجبك',
              lottie: 'empty_state',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
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
                  final storeId = (f['store_id'] as num?)?.toInt() ?? 0;
                  return ProdCard(
                    product: f,
                    onOpen: () => pushProduct(
                      context,
                      storeId,
                      (f['id'] as num?)?.toInt() ?? 0,
                    ),
                    storeName: '${f['store_name'] ?? ''}',
                    overlayAction: GestureDetector(
                      onTap: () => _unfav(f),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.danger,
                          size: 17,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
