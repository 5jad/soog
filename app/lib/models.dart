/// نماذج البيانات — فئات خفيفة فوق JSON الباك اند
class Store {
  final int id;
  final String name, logo, description, categoryName;
  final int categoryId;
  final double rating;
  final int reviewsCount;
  final bool verified;
  final String status;
  final String? cover;

  Store({
    required this.id,
    required this.name,
    required this.logo,
    required this.description,
    required this.categoryName,
    required this.categoryId,
    required this.rating,
    required this.reviewsCount,
    required this.verified,
    required this.status,
    this.cover,
  });

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as int,
        name: j['name'] ?? '',
        logo: j['logo'] ?? '',
        description: j['description'] ?? '',
        categoryName: j['category_name'] ?? '',
        categoryId: (j['category_id'] as num?)?.toInt() ?? 0,
        rating: double.tryParse('${j['rating'] ?? ''}') ?? (j['rating'] as num?)?.toDouble() ?? 0,
        reviewsCount: (j['reviews_count'] as num?)?.toInt() ?? 0,
        verified: j['verified'] == true || j['verified'] == 1,
        status: j['status'] ?? 'pending',
        cover: j['cover'] ?? '',
      );

  bool get open => status == 'approved' || status == 'active';
}

class Product {
  final int id, storeId;
  final String name, description, image;
  final double price;
  final int stock;
  final bool hasOffer;
  final double offerPrice;
  final String? variantName;
  final List<dynamic> variants;
  final Map<String, dynamic> attributes;

  Product({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.stock,
    required this.hasOffer,
    required this.offerPrice,
    this.variantName,
    this.variants = const [],
    this.attributes = const {},
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        storeId: (j['store_id'] as num?)?.toInt() ?? 0,
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        image: j['image'] ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        hasOffer: j['has_offer'] == true || j['has_offer'] == 1,
        offerPrice: (j['offer_price'] as num?)?.toDouble() ?? 0,
        variantName: j['variant_name'] as String?,
        variants: j['variants'] is List ? j['variants'] : [],
        attributes: j['attributes'] is Map ? Map<String, dynamic>.from(j['attributes'] as Map) : const {},
      );

  double get displayPrice => (hasOffer && offerPrice > 0) ? offerPrice : price;
  bool get outOfStock => stock <= 0;
}

/// تعريف سمة من الفئة (من جدول category_attrs في الباك اند)
class CategoryAttr {
  final int id, categoryId;
  final String key, label, type;
  final List<dynamic> options;
  final bool required;
  CategoryAttr(this.id, this.categoryId, this.key, this.label, this.type, this.options, this.required);
  factory CategoryAttr.fromJson(Map<String, dynamic> j) => CategoryAttr(
        (j['id'] as num?)?.toInt() ?? 0,
        (j['category_id'] as num?)?.toInt() ?? 0,
        j['key'] ?? '',
        j['label'] ?? '',
        j['type'] ?? 'text',
        j['options'] is List ? j['options'] : const [],
        j['required'] == true || j['required'] == 1,
      );
}

class Order {
  final int id;
  final String code, status, createdAt;
  final double total;
  final String storeName, storeLogo, courierName, address;
  final int storeId;
  final String? paymentMethod;
  final int itemsCount;

  Order({
    required this.id,
    required this.code,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.storeName,
    required this.storeLogo,
    required this.courierName,
    required this.address,
    required this.storeId,
    this.paymentMethod,
    this.itemsCount = 0,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        code: j['code'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: j['created_at'] ?? '',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        storeName: j['store_name'] ?? '',
        storeLogo: j['store_logo'] ?? '',
        courierName: j['courier_name'] ?? '',
        address: j['address'] ?? '',
        storeId: (j['store_id'] as num?)?.toInt() ?? 0,
        paymentMethod: j['payment_method'] as String?,
        itemsCount: (j['items_count'] as num?)?.toInt() ?? 0,
      );
}
