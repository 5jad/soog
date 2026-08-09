import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customer_shell.dart';

/// صفحة منتجات فئة معينة من كل المتاجر — شبكة متلاصقة بحواف حادة
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/products?category_id=${widget.categoryId}');
      products = d['products'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryName}')),
      body: loading
          ? const Loader()
          : Stack(children: [
              RefreshIndicator(
                onRefresh: _load,
                color: A.primary,
                child: products.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        EmptyState(icon: '📦', title: 'ماكو منتجات بهذه الفئة'),
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
    );
  }
}