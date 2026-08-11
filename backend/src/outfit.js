import { q, one } from './db.js';

/* ═══════════════════════════════════════════════════════════════
   محرك التنسيق الذكي «نسّق لي» — يبني إطلالة كاملة حول أي منتج
   بدون ذكاء اصطناعي: تصنيف أدوار + قواعد توافق + تناغم ألوان + جودة
   ═══════════════════════════════════════════════════════════════ */

// ── 1) تصنيف دور القطعة من اسم المنتج (مع الاحتياط بالفئة) ──
const ROLE_KEYWORDS = {
  top: ['قميص', 'تيشيرت', 'تي شيرت', 'تيشرت', 'بلوزة', 'سويتشرت', 'سويت', 'بلوفر', 'فانيلة', 'بنية', 'شميز', 'توب', 'بلايز'],
  bottom: ['بنطلون', 'جينز', 'شورت', 'بشت', 'دراجة', 'كارجو', 'سروال', 'تنورة', 'سكرت'],
  outerwear: ['جاكيت', 'بليزر', 'معطف', 'كنزة', 'سويتر', 'صدرية', 'كوت', 'بادي', 'هاودي', 'هودي', 'عباية'],
  shoes: ['حذاء', 'جزم', 'صندل', 'شبشب', 'كوتش', 'بوت', 'كعب', 'سنيكرز', 'سكيت'],
  watch: ['ساعة', 'سواتش'],
  bag: ['حقيبة', 'شنطة', 'محفظة', 'جيبة', 'شاربورن'],
  fragrance: ['عطر', 'برفان', 'ماء عطر', 'كولونيا'],
  hat: ['طاقية', 'قبعة', 'طوشة'],
  other: ['لعبة', 'ألعاب', 'مكياج', 'عناية', 'كريم', 'شامبو', 'أغذية', 'معلبات', 'أدوية', 'بلايستيشن', 'شاشة', 'جوال', 'لابتوب', 'طبخ', 'مطبخ'],
};

// الفئة احتياطي إذا ما انطابق الاسم
const CATEGORY_ROLES = {
  1: 'top',    // ملابس رجالي
  2: 'top',    // ملابس نسائي
  3: 'other',  // أطفال وألعاب
  4: 'other',  // مكياج وعناية
  5: 'shoes',  // أحذية
  6: 'bag',    // شنط وإكسسوارات
  7: 'other',  // مطاعم وأكل
  8: 'other',  // بقالة
  9: 'other',  // صيدليات
  10: 'other', // إلكترونيات
};

// فئات الجنس (لتفادي تنسيق رجالي مع نسائي)
const MALE_CATS = new Set([1]);
const FEMALE_CATS = new Set([2]);

// ── 2) مصفوفة توافق الأدوار — كم ينسجم كل زوج ──
const COMPAT = {
  top: { bottom: 0.95, shoes: 0.8, outerwear: 0.9, watch: 0.6, bag: 0.7, fragrance: 0.65, hat: 0.6 },
  bottom: { top: 0.95, shoes: 0.9, outerwear: 0.75, watch: 0.55, bag: 0.65, fragrance: 0.55, hat: 0.55 },
  shoes: { top: 0.8, bottom: 0.9, outerwear: 0.7, watch: 0.55, bag: 0.7, fragrance: 0.55, hat: 0.6 },
  outerwear: { top: 0.9, bottom: 0.75, shoes: 0.7, watch: 0.6, bag: 0.7, fragrance: 0.6, hat: 0.65 },
  watch: { top: 0.6, bottom: 0.55, shoes: 0.55, outerwear: 0.6, bag: 0.6, fragrance: 0.55, hat: 0.5 },
  bag: { top: 0.7, bottom: 0.65, shoes: 0.7, outerwear: 0.7, watch: 0.6, fragrance: 0.6, hat: 0.6 },
  fragrance: { top: 0.65, bottom: 0.55, shoes: 0.55, outerwear: 0.6, watch: 0.55, bag: 0.6, hat: 0.5 },
  hat: { top: 0.6, bottom: 0.55, shoes: 0.6, outerwear: 0.65, watch: 0.5, bag: 0.6, fragrance: 0.5 },
  accessory: { top: 0.7, bottom: 0.65, shoes: 0.7, outerwear: 0.7, watch: 0.6, bag: 0.6, fragrance: 0.6, hat: 0.6 },
};

// الأدوار الأساسية للإطلالة حسب المناسبة
const OCCASION_SLOTS = {
  casual: ['top', 'bottom', 'shoes', 'accessory'],
  work: ['top', 'bottom', 'shoes', 'watch'],
  formal: ['outerwear', 'top', 'bottom', 'shoes'],
  sport: ['top', 'bottom', 'shoes'],
  default: ['top', 'bottom', 'shoes', 'accessory'],
};

// كلمات تفضّل في كل مناسبة (تزيد وزن القطعة لو انطبق اسمها)
const OCCASION_BIAS = {
  casual: ['تيشيرت', 'جينز', 'سنيكرز', 'كوتش', 'طاقية'],
  work: ['قميص', 'شميز', 'بنطلون', 'بليزر', 'ساعة', 'حذاء جلد'],
  formal: ['بليزر', 'جاكيت', 'قميص', 'فستان', 'كعب', 'حذاء'],
  sport: ['رياضي', 'سنيكرز', 'سويت', 'جاكيت', 'تيشيرت'],
};

// ── 3) تناغم الألوان — أسماء عربية → hex ثم مسافة hue ──
const COLORS = {
  'أسود': '#000000', 'ابيض': '#FFFFFF', 'أبيض': '#FFFFFF', 'رمادي': '#9CA3AF', 'رمادي غامق': '#4B5563',
  'كحلي': '#12294E', 'أزرق': '#1D4ED8', 'أزرق فاتح': '#38BDF8', 'سماوي': '#38BDF8', 'ازرق': '#1D4ED8',
  'بنفسجي': '#7C3AED', 'ليلكي': '#C4A7E7', 'وردي': '#F472B6', 'زهري': '#F9A8D4', 'فوشي': '#C026D3',
  'أحمر': '#DC2626', 'عنابي': '#7F1D1D', 'احمر': '#DC2626', 'بني': '#7C4A23', 'بني فاتح': '#A16207',
  'برتقالي': '#F97316', 'أصفر': '#FACC15', 'اخضر': '#16A34A', 'أخضر': '#16A34A', 'أخضر غامق': '#14532D',
  'زيتي': '#4D7C0F', 'بيج': '#E5CBB0', 'ذهبي': '#D4AF37', 'فضي': '#C0C0C0', 'نحاسي': '#B87333',
  'سكري': '#F5E9D7', 'كاكي': '#A8A29E', 'موف': '#8B5CF6', 'نبيتي': '#5B2333', 'تركوازي': '#2DD4BF',
};
const NEUTRAL = new Set(['أسود', 'أبيض', 'ابيض', 'رمادي', 'بيج', 'كحلي', 'فضي', 'سكري']);

function hexToHsl(hex) {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || '');
  if (!m) return null;
  let r = parseInt(m[1], 16) / 255, g = parseInt(m[2], 16) / 255, b = parseInt(m[3], 16) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0));
    else if (max === g) h = ((b - r) / d + 2);
    else h = ((r - g) / d + 4);
    h *= 60;
  }
  return { h, l };
}

export function colorNameOf(text = '') {
  for (const [name, hex] of Object.entries(COLORS)) {
    if (text.includes(name)) return { name, hex };
  }
  return null;
}

function hueDist(a, b) {
  const ha = hexToHsl(a), hb = hexToHsl(b);
  if (!ha || !hb) return 180;
  const d = Math.abs(ha.h - hb.h);
  return Math.min(d, 360 - d);
}

// توافق لونين: محايد → أي لون؛ نفس العائلة → قريب؛ متكامل → بعيد
export function colorScore(c1, c2) {
  if (!c1 || !c2) return 0.75;
  if (NEUTRAL.has(c1.name) || NEUTRAL.has(c2.name)) return 0.95;
  const d = hueDist(c1.hex, c2.hex);
  if (d < 25) return 0.85;      // نفس العائلة
  if (d >= 150) return 0.8;     // متكاملان
  return 0.5;                   // عشوائي بعض الشيء
}

// ── 4) درجة جودة المنتج من بيانات المتجر المتاحة ──
export async function qualityOf(product) {
  if (!product) return { quality: 50, value: 50 };
  const store = await one(`SELECT rating_avg, rating_count FROM stores WHERE id=$1`, [product.store_id]);
  const rating = Number(store?.rating_avg ?? 0);
  const ratingScore = Math.min(100, rating * 20);
  const refunds = await one(`SELECT count(*)::int n FROM refund_requests rr
    JOIN orders o ON o.id=rr.order_id WHERE o.store_id=$1 AND rr.status='accepted'`, [product.store_id]);
  const ordersN = await one(`SELECT count(*)::int n FROM orders WHERE store_id=$1`, [product.store_id]);
  const refundFactor = ordersN.n > 0 ? Math.max(0.4, 1 - refunds.n / ordersN.n) : 0.75;
  const med = await one(`SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price)::numeric m
    FROM products WHERE category_id=$1 AND price>0`, [product.category_id]);
  const medP = Number(med?.m ?? 0);
  const price = Number(product.price || 0);
  const value = medP > 0 ? Math.max(40, Math.min(100, 100 - ((price / medP - 1) * 60))) : 70;
  const stock = Math.min(100, 50 + (Number(product.stock || 0) > 0 ? 40 : 0));
  const quality = Math.round(
    ratingScore * 0.45 + refundFactor * 100 * 0.25 + value * 0.15 + stock * 0.15
  );
  return { quality: Math.min(99, Math.max(30, quality)), value: Math.round(value), rating: ratingScore };
}

// ── 5) جلب المنتجات المرشحة للإطلالة ──
async function candidates(excludeId, genderCats, occasion) {
  const params = [excludeId];
  let w = `p.id <> $1 AND p.is_available AND p.stock>0 AND p.price>0`;
  if (genderCats.length) {
    params.push(genderCats);
    w += ` AND p.category_id NOT IN (SELECT unnest($${params.length}::int[]))`;
  }
  const rows = await q(`SELECT p.*, s.name AS store_name, s.logo AS store_logo, s.rating_avg,
      (pr.active AND pr.percent>0) AS has_offer,
      ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p
    JOIN stores s ON s.id=p.store_id AND s.status='approved'
    LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE ${w}
    LIMIT 400`, params);
  const list = rows.map((r) => ({ ...r, effPrice: Number(r.has_offer ? r.offer_price : r.price) }));
  const bias = OCCASION_BIAS[occasion] || [];
  return list.map((p) => ({ ...p, occBias: bias.some((k) => p.name.includes(k)) ? 0.15 : 0 }));
}

// ── 6) دور القطعة ──
export function roleOf(p) {
  const name = String(p?.name || '');
  for (const [role, keys] of Object.entries(ROLE_KEYWORDS)) {
    if (keys.some((k) => name.includes(k))) return role;
  }
  return CATEGORY_ROLES[p?.category_id] || 'other';
}

// ── 7) بناء الإطلالة حول منتج البذرة ──
export async function buildOutfit(seed, opts = {}) {
  const budget = Number(opts.budget || 0);
  const occasion = OCCASION_SLOTS[opts.occasion] ? opts.occasion : 'default';
  const colorPref = opts.color ? String(opts.color) : ''; // لون مفضّل (اختياري)

  const seedRole = roleOf(seed);
  if (seedRole === 'other') {
    return { title: 'تنسيق متاح للأزياء حالياً', slots: [{ role: 'other', seed: true, id: seed.id, name: seed.name, image: seed.image, price: Number(seed.price), store_id: seed.store_id, store_name: seed.store_name, rating: 0, color: '' }], total: Number(seed.price), fit: 0 };
  }
  const seedColor = colorNameOf(String(seed.attributes?.color || '')) || colorNameOf(String(seed.name || ''));
  const seedEff = Number(seed.has_offer ? seed.offer_price : seed.price);

  const isMale = MALE_CATS.has(seed.category_id);
  const isFemale = FEMALE_CATS.has(seed.category_id);
  const oppCats = isMale ? [...FEMALE_CATS] : isFemale ? [...MALE_CATS] : [];
  const genderCats = oppCats; // لا نعرض قطع الجنس الآخر أصلاً (الفلتر بالاستعلام أعلاه)

  const pool = await candidates(seed.id, genderCats, occasion);
  const byRole = new Map();
  for (const p of pool) {
    const role = roleOf(p);
    if (!byRole.has(role)) byRole.set(role, []);
    byRole.get(role).push(p);
  }

  const slots = OCCASION_SLOTS[occasion].filter((s) => s !== seedRole);
  // إكسسوار إضافي إذا كان المتاح غنياً (ساعة/حقيبة/عطر — الدور الواحد يكفي)
  const extraRoles = ['watch', 'bag', 'fragrance', 'hat', 'outerwear'];
  for (const r of extraRoles) {
    if (!slots.includes(r) && slots.length < 4 && (byRole.get(r)?.length || 0) > 0 && r !== seedRole) {
      slots.push(r);
      break;
    }
  }

  const chosen = { [seedRole]: { ...seed, effPrice: seedEff, role: seedRole, seed: true } };
  const outfitSlots = [{ product: seed, role: seedRole, seed: true }];
  const alternates = {};

  for (const role of slots) {
    const cands = (byRole.get(role) || []).filter((c) => c.id !== seed.id);
    if (!cands.length) continue;
    let best = null, bestScore = -1;
    const scored = [];
    for (const c of cands) {
      const cColor = colorNameOf(String(c.attributes?.color || '')) || colorNameOf(String(c.name || ''));
      let colorS = 1;
      for (const other of Object.values(chosen)) {
        const oColor = colorNameOf(String(other.attributes?.color || '')) || colorNameOf(String(other.name || ''));
        colorS = Math.min(colorS, colorScore(oColor, cColor));
      }
      const compat = COMPAT[seedRole]?.[role] ?? 0.6;
      const genderBonus = (isMale && MALE_CATS.has(c.category_id)) || (isFemale && FEMALE_CATS.has(c.category_id)) ? 0.2
        : (!isMale && !isFemale && (MALE_CATS.has(c.category_id) || FEMALE_CATS.has(c.category_id))) ? 0 : 0.1;
      const priceScore = budget > 0 ? (c.effPrice <= budget / Math.max(2, slots.length) ? 1 : Math.max(0.3, 1 - c.effPrice / budget)) : 0.7;
      const popScore = Math.min(1, (Number(c.rating_avg) || 0) / 5);
      const pref = colorPref ? (cColor?.name === colorPref ? 1 : 0.4) : 1;
      const score = compat * 0.32 + colorS * 0.22 + popScore * 0.13 + priceScore * 0.10 + genderBonus * 0.08 + pref * 0.05 + (c.occBias || 0) * 0.10;
      scored.push({ c, score });
      if (score > bestScore) { bestScore = score; best = c; }
    }
    if (!best) continue;
    chosen[role] = { ...best, effPrice: Number(best.offer_price || best.price), role };
    outfitSlots.push({ product: best, role, seed: false });
    alternates[role] = scored
      .filter((s) => s.c.id !== best.id)
      .sort((a, b) => b.score - a.score)
      .slice(0, 3)
      .map((s) => s.c);
  }

  // الميزانية: حقيبة ظهر بسيطة — إن زاد المجموع ننزل أرخص قطعة غير البذرة
  let total = outfitSlots.reduce((s, x) => s + (x.seed ? seedEff : Number(x.product.offer_price || x.product.price)), 0);
  if (budget > 0 && total > budget) {
    const movable = outfitSlots.filter((x) => !x.seed);
    movable.sort((a, b) => Number(b.product.offer_price || b.product.price) - Number(a.product.offer_price || a.product.price));
    for (const m of movable) {
      if (total <= budget) break;
      const cands = (byRole.get(m.role) || []).sort((a, b) => Number(a.offer_price || a.price) - Number(b.offer_price || b.price));
      const cheaper = cands.find((c) => c.id !== seed.id && (total - Number(m.product.offer_price || m.product.price) + Number(c.offer_price || c.price)) <= budget);
      if (cheaper) {
        total = total - Number(m.product.offer_price || m.product.price) + Number(cheaper.offer_price || cheaper.price);
        m.product = cheaper;
        chosen[m.role] = cheaper;
      }
    }
  }

  const fitScore = outfitSlots.length >= 3 ? 95 : outfitSlots.length >= 2 ? 85 : 70;
  const colorFit = outfitSlots.length > 1
    ? Math.round(100 * (outfitSlots.slice(1).reduce((s, x, i) => {
        const a = colorNameOf(String(x.product.attributes?.color || '')) || colorNameOf(String(x.product.name || ''));
        const prev = chosen[seedRole];
        const b = colorNameOf(String(prev.attributes?.color || '')) || colorNameOf(String(prev.name || ''));
        return s + colorScore(a, b);
      }, 0) / Math.max(1, outfitSlots.length - 1)))
    : 80;

  const titles = {
    casual: 'إطلالة كاجوال', work: 'إطلالة للدوام', formal: 'إطلالة رسمية', sport: 'إطلالة رياضية',
    default: 'إطلالة متكاملة',
  };

  return {
    title: titles[occasion],
    slots: outfitSlots.map((s) => ({
      role: s.role,
      seed: s.seed,
      id: s.product.id,
      name: s.product.name,
      image: s.product.image,
      price: Number(s.product.offer_price || s.product.price),
      store_id: s.product.store_id,
      store_name: s.product.store_name,
      logo: s.product.logo,
      rating: Number(s.product.rating_avg || 0),
      color: (colorNameOf(String(s.product.attributes?.color || '')) || colorNameOf(String(s.product.name || '')))?.name || '',
    })),
    alternates: Object.fromEntries(Object.entries(alternates).map(([role, list]) => [role, list.map((c) => ({
      role,
      id: c.id,
      name: c.name,
      image: c.image,
      price: Number(c.offer_price || c.price),
      store_id: c.store_id,
      store_name: c.store_name,
      logo: c.logo,
      rating: Number(c.rating_avg || 0),
      color: (colorNameOf(String(c.attributes?.color || '')) || colorNameOf(String(c.name || '')))?.name || '',
    }))])),
    total,
    fit: Math.min(99, Math.round(fitScore * 0.6 + colorFit * 0.4)),
  };
}
