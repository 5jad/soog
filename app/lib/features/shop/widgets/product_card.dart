import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

/// ═══ أنماط بدرات صورة المنتج ═══
enum ProdBadgeStyle {
  /// بدرات بارزة (خصم أحمر / نفد داكن) — كروت home و category و favorites
  badgeWow,

  /// بدرات glass (تدرج برتقالي للخصم، داكن شفاف لنفد) — بوكس المتجر العام
  glass,
}

/// ═══ خيارات بوكس المنتج الموحد ═══
/// كل القياسات هنا مسجلة من النسخ الأصلية الثلاث (favorites / category /
/// store_screen الزجاجي) — بوكس كل شاشة يحتفظ بشكله الحالي حرفياً،
/// والكود فقط أصبح مشتركاً عبر presets.
class ProdCardOptions {
  /// تبطين منطقة التفاصيل
  final EdgeInsetsGeometry padding;
  /// اسم المنتج
  final double nameSize;
  final int nameMaxLines;
  /// اسم المتجر (يظهر فقط لو مررت storeName لـ ProdCard)
  final double storeNameSize;
  /// نقاط ألوان المتغيرات (نمط home/favorites)
  final bool showDots;
  /// المسافة قبل سعر العرض المشطوب
  final double offerGap;
  /// المسافة بعد سعر العرض (قبل صف السعر)
  final double offerGapAfter;
  /// حجم سعر العرض المشطوب
  final double offerSize;
  /// glass: يحتفظ بمسافة العرض حتى بدون عرض فعلي
  final bool alwaysOfferGap;
  /// السعر الرئيسي
  final double priceSize;
  final Color priceColor;
  /// زر الجمع
  final double addWidth;
  final double addRadius;
  final double addIconSize;
  /// تثبيت السعر أسفل البطاقة (home/favorites) أو أسفل المضمون (category/glass)
  final bool pinBottom;
  /// نمط البدرات
  final ProdBadgeStyle badgeStyle;
  /// بطاقة زجاجية بزوايا 16 (بوكس المتجر العام)
  final bool glassy;

  const ProdCardOptions({
    this.padding = const EdgeInsets.fromLTRB(8, 4, 8, 5),
    this.nameSize = 10.5,
    this.nameMaxLines = 1,
    this.storeNameSize = 8.5,
    this.showDots = true,
    this.offerGap = 3,
    this.offerGapAfter = 0,
    this.offerSize = 8.5,
    this.alwaysOfferGap = false,
    this.priceSize = 12.5,
    this.priceColor = AppColors.ink,
    this.addWidth = 26,
    this.addRadius = 8,
    this.addIconSize = 16,
    this.pinBottom = true,
    this.badgeStyle = ProdBadgeStyle.badgeWow,
    this.glassy = false,
  });

  /// المظهر الافتراضي (home/search) — B بلا storeName و pinDown مثبت
  static const home = ProdCardOptions();

  /// favorites = home + storeName بحجم 8.5
  static const favorites = ProdCardOptions(storeNameSize: 8.5);

  /// نمط category_products: اسم بسطرين بلا نقاط، سعر أكبر
  static const category = ProdCardOptions(
    padding: EdgeInsets.fromLTRB(9, 5, 9, 6),
    nameSize: 11,
    nameMaxLines: 2,
    storeNameSize: 9.5,
    showDots: false,
    offerGap: 0,
    offerGapAfter: 2,
    offerSize: 9.5,
    priceSize: 13.5,
    addWidth: 28,
    addRadius: 9,
    addIconSize: 17,
    pinBottom: false,
  );

  /// نمط بوكس المتجر العام الزجاجي
  static const glass = ProdCardOptions(
    padding: EdgeInsets.fromLTRB(9, 8, 9, 8),
    nameSize: 11.5,
    nameMaxLines: 2,
    storeNameSize: 9.5,
    showDots: false,
    offerGap: 4,
    offerSize: 9.5,
    alwaysOfferGap: true,
    priceSize: 14,
    priceColor: AppColors.accent,
    addWidth: 30,
    addRadius: 10,
    addIconSize: 18,
    pinBottom: false,
    badgeStyle: ProdBadgeStyle.glass,
    glassy: true,
  );
}

/// ═══ بوكس المنتج الموحد ═══
/// المرجع الوحيد لبطاقة المنتج — كل الشاشات تستخدمه بخياراتها.
class ProdCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onOpen;
  /// اسم المتجر — يظهر فوق اسم المنتج (favorites/category)
  final String? storeName;
  /// عنصر يوضع أسفل يمين الصورة (زر القلب في المفضلة)
  final Widget? overlayAction;
  /// زر الجمع المخصص (بدل quickAdd الافتراضي)
  final VoidCallback? onAdd;
  /// false = زر الجمع بدون تأثير (نفد)
  final bool addEnabled;
  final ProdCardOptions opts;
  const ProdCard({
    super.key,
    required this.product,
    required this.onOpen,
    this.storeName,
    this.overlayAction,
    this.onAdd,
    this.addEnabled = true,
    this.opts = const ProdCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final prod = Product.fromJson(product);
    final offPct = prod.hasOffer && prod.price > 0
        ? ((prod.price - prod.displayPrice) / prod.price * 100).round()
        : 0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProdImageStack(
          image: prod.image,
          offPct: offPct,
          hasOffer: prod.hasOffer,
          outOfStock: prod.outOfStock,
          badgeStyle: opts.badgeStyle,
          overlayAction: overlayAction,
        ),
        Expanded(
          child: Padding(
            padding: opts.padding,
            child: _details(context, prod),
          ),
        ),
      ],
    );
    if (opts.glassy) {
      return GlassCard(
        onTap: onOpen,
        radius: 16,
        padding: EdgeInsets.zero,
        child: content,
      );
    }
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  /// منطقة التفاصيل: اسم المتجر ← الاسم ← النقاط ← العرض ← السعر + زر الجمع
  Widget _details(BuildContext context, Product prod) {
    final name = storeName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: AppType.style(
              opts.storeNameSize,
              color: AppColors.primary,
              weight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          prod.name,
          style: AppType.style(opts.nameSize, weight: FontWeight.w800),
          maxLines: opts.nameMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        // نقاط ألوان المتغيرات (مثل شي إن) — لون كل تركيبة بلا تكرار
        if (opts.showDots && prod.variants.isNotEmpty) ...[
          const SizedBox(height: 3),
          _dotsRow(prod),
        ],
        if (prod.hasOffer) ...[
          SizedBox(height: opts.offerGap),
          Text(
            formatMoney(prod.price),
            style: AppType.style(
              opts.offerSize,
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if (opts.alwaysOfferGap)
          SizedBox(height: opts.offerGap),
        if (opts.offerGapAfter > 0) SizedBox(height: opts.offerGapAfter),
        // السعر + زر الإضافة — مثبتان أسفل البوكس (أو أسفل المضمون حسب النمط)
        if (opts.pinBottom) const Spacer(),
        Row(
          children: [
            Expanded(
              child: Text(
                formatMoney(prod.displayPrice),
                style: AppType.style(
                  opts.priceSize,
                  color: opts.priceColor,
                  weight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: addEnabled ? (onAdd ?? () => quickAdd(context, product)) : null,
              child: Container(
                width: opts.addWidth,
                height: opts.addWidth,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(opts.addRadius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_rounded,
                  size: opts.addIconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// نقاط ألوان المتغيرات + "+N" للزيادة
  Widget _dotsRow(Product prod) {
    final dots = <Color>[];
    for (final v in prod.variants) {
      final c = _dotsColor(
        '${v is Map ? (v['color'] ?? (v['name'] ?? '')) : v}',
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

/// ═══ صورة المنتج + بدراتها (مشتركة بين ProdCard وبطاقة التاجر) ═══
class ProdImageStack extends StatelessWidget {
  final String? image;
  /// نسبة الخصم — null يخفي شارة الخصم
  final int? offPct;
  final bool hasOffer;
  final bool outOfStock;
  final ProdBadgeStyle badgeStyle;
  /// عنصر أسفل يمين الصورة (زر القلب في المفضلة)
  final Widget? overlayAction;
  /// أساس روابط الصور (بطاقة التاجر مثلاً)
  final String? imageBase;
  /// بدرة خصم مخصصة — تغلب على badgeStyle (بطاقة التاجر)
  final Widget? offerBadge;
  /// بدرة نفد مخصصة — تغلب على badgeStyle (بطاقة التاجر)
  final Widget? stockBadge;
  final double imageRadius;
  const ProdImageStack({
    super.key,
    this.image,
    this.offPct,
    this.hasOffer = false,
    this.outOfStock = false,
    this.badgeStyle = ProdBadgeStyle.badgeWow,
    this.overlayAction,
    this.imageBase,
    this.offerBadge,
    this.stockBadge,
    this.imageRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          productImageBox(image, base: imageBase, radius: imageRadius),
          if (hasOffer)
            Positioned(
              top: 8,
              right: 8,
              child: offerBadge ??
                  (badgeStyle == ProdBadgeStyle.glass
                      ? _glassBadge('خصم ${offPct ?? 0}%')
                      : BadgeWow('خصم ${offPct ?? 0}%')),
            ),
          if (outOfStock)
            Positioned(
              top: 8,
              left: 8,
              child: stockBadge ??
                  (badgeStyle == ProdBadgeStyle.glass
                      ? _glassBadge('نفد', dark: true)
                      : BadgeWow('نفد', dark: true)),
            ),
          if (overlayAction case final Widget oa)
            Positioned(bottom: 8, right: 8, child: oa),
        ],
      ),
    );
  }

  /// بدرة glass: تدرج برتقالي للخصم / داكن شفاف لنفد
  Widget _glassBadge(String label, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: dark ? null : AppColors.gradSun,
        color: dark ? const Color(0xDD0A1120) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppType.style(
          9.5,
          color: Colors.white,
          weight: FontWeight.w900,
        ),
      ),
    );
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

/// بدرة "خصم"/"نفد" البارزة — كروت home و favorites و category
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