/* ═══ بيانات وهمية ثابتة لاعتراض /api/* — goldens حتمية بدون سيرفر ═══ */

const PRODS = [
  { id: 1, name: 'شاي أحمر فاخر 500غ', subtitle: 'أوراق كاملة — طعم عريق', price: 6500, old_price: 8000, has_offer: true, offer_percent: 19, offer_price: 6500, image: null, images: null, stock: 40, available: true, rating: 4.6, reviews_count: 128, store_id: 1, store_name: 'بقالة العمارة', store_logo: null, category_id: 1, warranty_days: 3, desc: 'شاي أحمر عراقي أصلي، يعطي لون قوي ونكهة غنية، مثالي للضحى والصبح.' },
  { id: 2, name: 'رز عنبر عنبر 10كغ', price: 42500, old_price: null, has_offer: false, offer_percent: 0, offer_price: null, image: null, images: null, stock: 5, available: true, rating: 4.9, reviews_count: 302, store_id: 1, store_name: 'بقالة العمارة', store_logo: null, category_id: 1, warranty_days: 3, desc: 'رز عنبر درجة أولى — حبة طويلة وطعم مميز.' },
  { id: 3, name: 'عسل سدر جبلي 1كغ', price: 28000, old_price: 34000, has_offer: true, offer_percent: 18, offer_price: 28000, image: null, images: null, stock: 0, available: false, rating: 5.0, reviews_count: 87, store_id: 2, store_name: 'زهرة الفرات', store_logo: null, category_id: 2, warranty_days: 7, desc: 'عسل سدر أصلي من جبال إيران — مضمون 100%.' },
  { id: 4, name: 'حلاوة رأس العبد بالصنوبر', price: 9500, old_price: null, has_offer: false, offer_percent: 0, offer_price: null, image: null, images: null, stock: 2, available: true, rating: 4.4, reviews_count: 54, store_id: 2, store_name: 'زهرة الفرات', store_logo: null, category_id: 2, warranty_days: 3, desc: 'حلاوة تقليدية بالمكسرات.' },
  { id: 5, name: 'زيت زيتون بكر ممتاز 2لتر', price: 18500, old_price: 22000, has_offer: true, offer_percent: 16, offer_price: 18500, image: null, images: null, stock: 18, available: true, rating: 4.7, reviews_count: 143, store_id: 3, store_name: 'معامل الكوت', store_logo: null, category_id: 3, warranty_days: 5, desc: 'زيت زيتون بكر — عصر أول.' },
  { id: 6, name: 'معجون طماطم 800غ', price: 4200, old_price: null, has_offer: false, offer_percent: 0, offer_price: null, image: null, images: null, stock: 60, available: true, rating: 4.2, reviews_count: 96, store_id: 3, store_name: 'معامل الكوت', store_logo: null, category_id: 3, warranty_days: 3, desc: 'معجون طماطم مركّز صناعة محلية.' },
  { id: 7, name: 'قهوة عربية مطحونة 400غ', price: 9800, old_price: 12000, has_offer: true, offer_percent: 18, offer_price: 9800, image: null, images: null, stock: 12, available: true, rating: 4.8, reviews_count: 211, store_id: 1, store_name: 'بقالة العمارة', store_logo: null, category_id: 1, warranty_days: 3, desc: 'قهوة عربية بهيل وقرنفل.' },
  { id: 8, name: 'براوني شوكولاتة فاخر', price: 12500, old_price: null, has_offer: false, offer_percent: 0, offer_price: null, image: null, images: null, stock: 9, available: true, rating: 4.5, reviews_count: 67, store_id: 2, store_name: 'زهرة الفرات', store_logo: null, category_id: 2, warranty_days: 2, desc: 'براوني طازج بالشوكولاتة البلجيكية.' },
];

const STORES = [
  { id: 1, name: 'بقالة العمارة', logo: null, cover: null, category_id: 1, category_name: 'مواد غذائية', governorate_name: 'واسط', district_name: 'حي العمارة', rating: 4.7, reviews_count: 312, delivery_fee: 2000, free_delivery_min: 30000, is_open: true, on_vacation: false, verified: true, open_time: '08:00', close_time: '23:00', phone: '07701234567', location_url: null, warranty_days: 3 },
  { id: 2, name: 'زهرة الفرات للحلويات', logo: null, cover: null, category_id: 2, category_name: 'حلويات', governorate_name: 'واسط', district_name: 'شارع الجزائر', rating: 4.9, reviews_count: 520, delivery_fee: 2500, free_delivery_min: 40000, is_open: true, on_vacation: false, verified: true, open_time: '09:00', close_time: '23:30', phone: '07707654321', location_url: null, warranty_days: 3 },
  { id: 3, name: 'معامل الكوت للأغذية', logo: null, cover: null, category_id: 3, category_name: 'منتجات محلية', governorate_name: 'واسط', district_name: 'الصالحية', rating: 4.5, reviews_count: 178, delivery_fee: 3000, free_delivery_min: 50000, is_open: false, on_vacation: false, verified: false, open_time: '08:30', close_time: '20:00', phone: '07706543210', location_url: null, warranty_days: 5 },
];

const CATS = [
  { id: 1, name: 'مواد غذائية', icon: '🛒' },
  { id: 2, name: 'حلويات', icon: '🍰' },
  { id: 3, name: 'منتجات محلية', icon: '🏺' },
];

export const PROD = { ...PRODS[0], images: null, selected_variants: {}, variants: [{ name: 'اللون', type: 'color', hex: { أحمر: '#C0392B', أسود: '#2C3E50' }, values: ['أحمر', 'أسود'] }, { name: 'الحجم', type: 'size', values: ['500غ', '1كغ'] }] };

const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const unauth = () => json({ error: 'سجّل دخولك أولاً' }, 401);

export async function mockApi(page) {
  await page.route('**/api/**', (route) => {
    const url = new URL(route.request().url());
    const p = url.pathname;
    if (p === '/api/products/meta') return route.fulfill({ response: json({ colors: ['أحمر', 'أسود', 'أزرق', 'ذهبي'], sizes: ['S', 'M', 'L', 'XL'] }) });
    if (p === '/api/products') return route.fulfill({ response: json({ products: PRODS }) });
    if (p.startsWith('/api/products/')) return route.fulfill({ response: json({ product: PROD }) });
    if (p === '/api/stores') return route.fulfill({ response: json({ stores: STORES }) });
    if (p.startsWith('/api/stores/')) return route.fulfill({ response: json({ store: { ...STORES[0], reviews: [], rating_breakdown: { 5: 9, 4: 2, 3: 1 }, coupons: [] } }) });
    if (p === '/api/categories') return route.fulfill({ response: json({ categories: CATS }) });
    if (p === '/api/offers') return route.fulfill({ response: json({ offers: PRODS.slice(0, 4) }) });
    if (p === '/api/ads') return route.fulfill({ response: json({ ads: [] }) });
    if (p === '/api/governorates') return route.fulfill({ response: json({ governorates: [{ id: 1, name: 'واسط', districts: [{ id: 1, name: 'حي العمارة' }, { id: 2, name: 'الصالحية' }] }] }) });
    if (p === '/api/routing/districts') return route.fulfill({ response: json({ districts: ['حي العمارة', 'الصالحية'] }) });
    if (p === '/api/auth/login') return route.fulfill({ response: json({ error: 'بيانات غير صحيحة' }, 400) });
    if (p.startsWith('/api/customer') || p.startsWith('/api/vendor') || p.startsWith('/api/delivery')) return route.fulfill({ response: unauth() });
    return route.fulfill({ response: json({ error: 'ماكو' }, 404) });
  });
}

/* ═══ المسارات — بـ HashRouter (التطبيق كله #/...) مثل التشغيل الفعلي ═══ */
export const ROUTES = [
  ['home', '/'],
  ['cart', '/#/cart'],
  ['product', '/#/product/1'],
  ['stores', '/#/stores'],
  ['store', '/#/stores/1'],
  ['prods', '/#/prods'],
  ['cat', '/#/cat/1'],
  ['search', '/#/search?q=' + encodeURIComponent('شاي')],
  ['offers', '/#/offers'],
  ['checkout', '/#/checkout'],
  ['orders', '/#/orders'],
  ['order-detail', '/#/orders/1'],
  ['track', '/#/orders/1/track'],
  ['chat', '/#/chat'],
  ['points', '/#/points'],
  ['notifications', '/#/notifications'],
  ['fav', '/#/fav'],
  ['account', '/#/account'],
  ['vendor', '/#/vendor'],
  ['delivery', '/#/delivery'],
];

/* /admin يعيد توجيه (window.location) → خارج نطاق اللقطات؛ /logout يحوّل للرئيسية */