/* ═══════════════════════════════════════════════════════════════
   سعر التوصيل — معادلة المسافة (متعدد المحلات + تفاصيل شفافة)
   ملف إعداد واحد: غيّر الأرقام من DELIVERY_CONFIG وتتأثر كل الحسابات
   ═══════════════════════════════════════════════════════════════ */

/** جميع الأرقام القابلة للتعديل في مكان واحد */
export const DELIVERY_CONFIG = {
  basePrice: 1500,        // السعر الأساسي (د.ع) — يشمل أول 3 كم
  extraShopFee: 500,      // رسم كل محل إضافي بعد الأول (د.ع)
  pricePerKm: 150,        // سعر الكيلومتر الزائد (د.ع)
  freeDistanceKm: 3,      // المسافة المجانية المشمولة بالسعر الأساسي (كم)
  minPrice: 1800,         // الحد الأدنى المضمون للمندوب (د.ع)
  roadFactor: 1.3,        // معامل تصحيح مسار الطريق (الطريق أطول من خط الطيران)
};

/**
 * مسافة Haversine بين نقطتين بالكيلومتر
 * @param {{lat:number,lng:number}} a النقطة الأولى
 * @param {{lat:number,lng:number}} b النقطة الثانية
 * @returns {number} المسافة بالكيلومترات (مقرّبة لمنزلتين)
 */
export function haversineKm(a, b) {
  const R = 6371; // نصف قطر الأرض بالكيلومتر
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(s)) * 100) / 100;
}

/**
 * حساب سعر توصيل الطلب (من المحل الأول → المحل الثاني → ... → الزبون)
 * @param {Array<{lat:number,lng:number}>} shops إحداثيات المحلات بترتيب الاستلام
 * @param {{lat:number,lng:number}} customerLocation إحداثيات الزبون
 * @param {Partial<typeof DELIVERY_CONFIG>} [overrides] أرقام بديلة (اختياري)
 * @returns {{total_price:number, breakdown:object}} السعر + التفاصيل للعرض الشفاف
 */
export function calculateDeliveryPrice(shops, customerLocation, overrides = {}) {
  const C = { ...DELIVERY_CONFIG, ...overrides };
  const points = [...(shops || []), customerLocation];

  // 1) المسافة التراكمية للمسار الكامل (هافرسين بين كل نقطتين متتاليتين)
  let straightKm = 0;
  for (let i = 1; i < points.length; i++) straightKm += haversineKm(points[i - 1], points[i]);

  // معامل تصحيح الطريق — خط الطيران أقصر من الطريق الفعلي دائماً
  const distanceKm = Math.round(straightKm * C.roadFactor * 100) / 100;

  // 2) المعادلة: الأساسي + رسوم المحلات الإضافية + الكيلومترات الزائدة
  const shopCount = Math.max(1, (shops || []).length);
  const extraShopsFee = (shopCount - 1) * C.extraShopFee;
  const extraDistanceKm = Math.max(0, distanceKm - C.freeDistanceKm);
  const extraDistanceFee = Math.round(extraDistanceKm * C.pricePerKm);

  let total = C.basePrice + extraShopsFee + extraDistanceFee;

  // 3) الحد الأدنى المضمون
  total = Math.max(total, C.minPrice);

  return {
    total_price: total,
    breakdown: {
      base_price: C.basePrice,
      extra_shops_fee: extraShopsFee,
      distance_km: distanceKm,
      free_distance_km: C.freeDistanceKm,
      extra_distance_fee: extraDistanceFee,
      price_per_km: C.pricePerKm,
    },
  };
}
