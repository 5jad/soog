import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

class ProdCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onOpen;
  const ProdCard({required this.product, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final prod = Product.fromJson(product);
    final offPct = prod.hasOffer && prod.price > 0
        ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
        : 0;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  productImageBox(prod.image),
                  if (prod.hasOffer)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: BadgeWow('خصم $offPct%'),
                    ),
                  if (prod.outOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: BadgeWow('نفد', dark: true),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod.name,
                      style: AppType.style(10.5, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // نقاط ألوان المتغيرات (مثل شي إن) — لون كل تركيبة بلا تكرار
                    if (prod.variants.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Builder(
                        builder: (ctx) {
                          final dots = <Color>[];
                          for (final v in prod.variants) {
                            final c = _dotsColor(
                              '${(v is Map ? (v['color'] ?? (v['name'] ?? '')) : v)}',
                            );
                            if (!dots.contains(c)) dots.add(c);
                          }
                          return Row(
                            children: [
                              for (final c in dots.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black12,
                                        width: 0.7,
                                      ),
                                    ),
                                  ),
                                ),
                              if (dots.length > 4)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    '+${dots.length - 4}',
                                    style: AppType.style(
                                      8,
                                      color: AppColors.muted,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (prod.hasOffer) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatMoney(prod.price),
                        style: AppType.style(
                          8.5,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    // السعر + زر الإضافة — مثبتان أسفل كل بوكس مهما تغيرت التفاصيل
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatMoney(prod.displayPrice),
                            style: AppType.style(
                              12.5,
                              color: AppColors.ink,
                              weight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Builder(
                          builder: (_) => GestureDetector(
                            onTap: () => quickAdd(context, product),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // لون تقريبي لأسماء الألوان العربية الشائعة (تغريبي بسيط)
  Color _dotsColor(dynamic name) {
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
      'بنفسجية': Color(0xFF7C3AED),
      'purple': Color(0xFF7C3AED),
      'وردي': Color(0xFFF472B6),
      'وردية': Color(0xFFF472B6),
      'pink': Color(0xFFF472B6),
      'رمادي': Color(0xFF9CA3AF),
      'رمادية': Color(0xFF9CA3AF),
      'grey': Color(0xFF9CA3AF),
      'بني': Color(0xFF7C4A23),
      'بنية': Color(0xFF7C4A23),
      'brown': Color(0xFF7C4A23),
      'برتقالي': Color(0xFFF97316),
      'برتقالية': Color(0xFFF97316),
      'orange': Color(0xFFF97316),
    };
    return map.entries
        .firstWhere(
          (e) => n.contains(e.key),
          orElse: () => const MapEntry('', Color(0xFFD9DEE7)),
        )
        .value;
  }
}

/// إضافة سريعة للسلة — مثل زر + في الديمو
void quickAdd(
  BuildContext context,
  Map<String, dynamic> prod, {
  int qty = 1,
}) {
  final variants = prod['variants'];
  if (variants is List && variants.isNotEmpty) {
    // منتج بمتغيرات — فتح الصفحة ليختار اللون/القياس
    final storeId = (prod['store_id'] as num?)?.toInt() ?? 0;
    final pid = (prod['id'] as num?)?.toInt() ?? 0;
    if (storeId > 0 && pid > 0) {
      toast(context, 'لهذا المنتج ألوان/مقاسات — اخترها من صفحته ثم أضفه');
      return pushProduct(context, storeId, pid);
    }
  }
  final pid = (prod['id'] as num?)?.toInt() ?? 0;
  if (!Api.logged) {
    final existing = AppState.i.guestCart.indexWhere(
      (e) => e['product_id'] == pid,
    );
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
        'price': prod['has_offer'] == true || prod['has_offer'] == 1
            ? prod['offer_price']
            : prod['price'],
        'qty': qty,
        'variant': null,
      });
    }
    AppState.i.setCart(cartTotalQty(AppState.i.guestCart));
    addPop(context);
    return;
  }
  Api.post('/api/customer/cart', {'product_id': pid, 'qty': qty})
      .then((_) {
        AppState.i.setCart(AppState.i.cartCount.value + qty);
        addPop(context);
      })
      .catchError((e) {
        toast(context, '${e is ApiException ? e.message : e}', error: true);
      });
}

class BadgeWow extends StatelessWidget {
  final String label;
  final bool dark;
  const BadgeWow(this.label, {super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFF0A1120) : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppType.style(11, color: Colors.white, weight: FontWeight.w900),
      ),
    );
  }
}
