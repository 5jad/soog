import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { q, one } from '../db.js';
import { demoCond } from '../demo.js';
import { auth } from '../middleware.js';

const r = Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── نسخة التطبيق الحالية (الزبون يقارنها ويحمّل الأحدث من الموقع) ──
r.get('/app/version', (_req, res) => {
  try {
    const v = JSON.parse(fs.readFileSync(path.join(__dirname, '../app-version.json'), 'utf8'));
    res.json(v);
  } catch (_) {
    res.json({ version: '1.0.0', build: 1, download_url: '/download' });
  }
});

// ── المحافظات والأحياء ──
r.get('/governorates', async (_req, res) => {
  const rows = await q('SELECT * FROM governorates WHERE is_active ORDER BY sort, id');
  const districts = await q('SELECT id, governorate_id, name FROM districts ORDER BY sort, id');
  res.json({ governorates: rows.map(g => ({ ...g, districts: districts.filter(d => d.governorate_id === g.id) })) });
});

// ── الأقسام ──
r.get('/categories', async (_req, res) => {
  res.json({ categories: await q('SELECT * FROM categories WHERE is_active ORDER BY sort, id'), attrs: await q('SELECT * FROM category_attrs ORDER BY category_id, sort, id') });
});

// ── المتاجر ──
r.get('/stores', async (req, res) => {
  const { district_id, category_id, q: query, governorate_id } = req.query;
  const w = [];
  const p = [];
  if (district_id) { p.push(district_id); w.push(`s.district_id=$${p.length}`); }
  if (category_id) { p.push(category_id); w.push(`s.category_id=$${p.length}`); }
  if (governorate_id) { p.push(governorate_id); w.push(`s.governorate_id=$${p.length}`); }
  if (query) { p.push(`%${query}%`); w.push(`(s.name ILIKE $${p.length} OR s.description ILIKE $${p.length})`); }
  w.push(`s.status='approved'`);
  const dStore = await demoCond('stores');
  if (dStore) w.push(dStore);
  const sql = `SELECT s.*, s.rating_avg AS rating, s.rating_count AS reviews_count, c.name AS category_name, c.icon AS category_icon, g.name AS governorate_name, d.name AS district_name
    FROM stores s
    LEFT JOIN categories c ON c.id=s.category_id
    LEFT JOIN governorates g ON g.id=s.governorate_id
    LEFT JOIN districts d ON d.id=s.district_id
    WHERE ${w.join(' AND ')} ORDER BY s.rating_avg DESC, s.id`;
  res.json({ stores: await q(sql, p) });
});

r.get('/stores/:id', async (req, res) => {
  const s = await one(`SELECT s.*, s.rating_avg AS rating, s.rating_count AS reviews_count, c.name AS category_name, c.icon AS category_icon, g.name AS governorate_name, d.name AS district_name
    FROM stores s
    LEFT JOIN categories c ON c.id=s.category_id
    LEFT JOIN governorates g ON g.id=s.governorate_id
    LEFT JOIN districts d ON d.id=s.district_id
    WHERE s.id=$1`, [req.params.id]);
  if (!s) return res.status(404).json({ error: 'المحل غير موجود' });
  const dStore = await demoCond('stores');
  if (dStore && s.name?.startsWith('[وهمي]')) return res.status(404).json({ error: 'المحل غير موجود' });
  const products = await q(`SELECT p.*, pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true WHERE p.store_id=$1 ORDER BY p.id`, [s.id]);
  const variants = await q(`SELECT v.* FROM product_variants v JOIN products p ON p.id=v.product_id WHERE p.store_id=$1`, [s.id]);
  const reviews = await q(`SELECT rev.*, u.name AS user_name, u.avatar FROM reviews rev JOIN users u ON u.id=rev.user_id WHERE rev.store_id=$1 ORDER BY rev.id DESC LIMIT 50`, [s.id]);
  // كوبونات المتجر النشطة (ساكنة رخيصة)
  const coupons = await q(`SELECT id, code, percent, flat, min_total, max_discount, expires_at FROM coupons
    WHERE store_id=$1 AND active=true AND (expires_at IS NULL OR expires_at > now()) ORDER BY id DESC LIMIT 5`, [s.id]);
  // توزيع التقييمات 1..5
  const ratingBreakdown = (await q(`SELECT rating, count(*)::int AS n FROM reviews WHERE store_id=$1 GROUP BY rating`, [s.id]));
  const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  for (const r of ratingBreakdown) if (r.rating) breakdown[r.rating] = r.n;
  res.json({ store: s, products, variants, reviews, coupons, rating_breakdown: breakdown });
});

// ── المنتجات ──
r.get('/products', async (req, res) => {
  const { store_id, category_id, q: query, offer, sort, min_price, max_price, colors, sizes, limit, offset } = req.query;
  const w = [];
  const p = [];
  if (store_id) { p.push(store_id); w.push(`p.store_id=$${p.length}`); }
  if (category_id) {
    // فئات متعددة: category_id=3,7 (يرجع منتجات كل الفئات المختارة)
    const list = String(category_id).split(',').map(Number).filter((n) => n > 0);
    if (list.length === 1) {
      p.push(list[0]);
      w.push(`p.category_id=$${p.length}`);
    } else if (list.length > 1) {
      p.push(list);
      w.push(`p.category_id = ANY($${p.length}::int[])`);
    }
  }
  if (query) { p.push(`%${query}%`); w.push(`(p.name ILIKE $${p.length} OR p.description ILIKE $${p.length})`); }
  if (offer === 'true') w.push(`pr.active=true AND pr.percent>0`);
  // الفلترة على السعر الفعلي (بعد الخصم)
  if (min_price !== undefined && min_price !== '') { p.push(Number(min_price)); w.push(`(p.price*(1-COALESCE(pr.percent,0)/100.0)) >= $${p.length}`); }
  if (max_price !== undefined && max_price !== '') { p.push(Number(max_price)); w.push(`(p.price*(1-COALESCE(pr.percent,0)/100.0)) <= $${p.length}`); }
  // الفلترة بالألوان (تركيبات بمخزون)
  if (colors) {
    const list = colors.split(',').map((s) => s.trim()).filter(Boolean);
    p.push(list); w.push(`EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id=p.id AND pv.color=ANY($${p.length}) AND pv.stock>0)`);
  }
  // الفلترة بالمقاسات (اسم التركيبة)
  if (sizes) {
    const list = sizes.split(',').map((s) => s.trim()).filter(Boolean);
    p.push(list); w.push(`EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id=p.id AND pv.name=ANY($${p.length}) AND pv.stock>0)`);
  }
  const dProduct = await demoCond('products', { o: 'p' });
  if (dProduct) w.push(dProduct);
  const eff = `(p.price*(1-COALESCE(pr.percent,0)/100.0))`;
  const orderBy = sort === 'price_asc' ? `ORDER BY ${eff} ASC, p.id DESC`
    : sort === 'price_desc' ? `ORDER BY ${eff} DESC, p.id DESC`
    : sort === 'discount' ? `ORDER BY COALESCE(pr.percent,0) DESC, p.id DESC`
    : sort === 'best' || req.query.best === 'true' ? 'ORDER BY s.rating_avg DESC, p.id DESC'
    : 'ORDER BY p.id DESC';
  const rowLimit = Math.max(1, Math.min(100, Number(limit) || 100));
  const rowOffset = Math.max(0, Number(offset) || 0);
  // عدّاد إجمالي لنفس الفلتر — يدعم pagination (load-more) في التطبيق
  const totalRow = await one(`SELECT count(*)::int AS n FROM products p
    JOIN stores s ON s.id=p.store_id AND s.status='approved'
    LEFT JOIN offers pr ON pr.product_id=p.id
    WHERE ${w.join(' AND ') || 'true'}`, p);
  const sql = `SELECT p.*, s.id AS store_id, s.name AS store_name, s.logo AS store_logo, s.delivery_fee,
      pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(${eff}) AS offer_price
    FROM products p
    JOIN stores s ON s.id=p.store_id AND s.status='approved'
    LEFT JOIN offers pr ON pr.product_id=p.id
    WHERE ${w.join(' AND ') || 'true'} ${orderBy} LIMIT $${p.length + 1} OFFSET $${p.length + 2}`;
  p.push(rowLimit, rowOffset);
  const products = await q(sql, p);
  const ids = products.map((x) => x.id);
  if (ids.length) {
    const vars = await q(`SELECT v.* FROM product_variants v WHERE v.product_id = ANY($1::int[]) ORDER BY v.id`, [ids]);
    for (const prod of products) prod.variants = vars.filter((v) => v.product_id === prod.id);
  }
  res.json({ products, total: totalRow.n });
});

// ── ألوان ومقاسات متوفرة للفلترة (شي إن/إيباي) ──
r.get('/products/meta', async (req, res) => {
  const { store_id, category_id } = req.query;
  const w = [];
  const p = [];
  if (store_id) { p.push(store_id); w.push(`p.store_id=$${p.length}`); }
  if (category_id) {
    const list = String(category_id).split(',').map(Number).filter((n) => n > 0);
    if (list.length === 1) {
      p.push(list[0]);
      w.push(`p.category_id=$${p.length}`);
    } else if (list.length > 1) {
      p.push(list);
      w.push(`p.category_id = ANY($${p.length}::int[])`);
    }
  }
  const ww = w.join(' AND ') || 'true';
  const colors = await q(`SELECT DISTINCT pv.color FROM product_variants pv JOIN products p ON p.id=pv.product_id
    JOIN stores s ON s.id=p.store_id AND s.status='approved'
    WHERE pv.stock>0 AND pv.color<>'' AND ${ww} ORDER BY pv.color`, p);
  const sizes = await q(`SELECT DISTINCT pv.name FROM product_variants pv JOIN products p ON p.id=pv.product_id
    JOIN stores s ON s.id=p.store_id AND s.status='approved'
    WHERE pv.stock>0 AND ${ww} ORDER BY pv.name`, p);
  res.json({ colors: colors.map((c) => c.color), sizes: sizes.map((s) => s.name) });
});

r.get('/products/:id', async (req, res) => {
  const p = await one(`SELECT p.*, s.name AS store_name, s.logo AS store_logo, s.id AS store_id, s.delivery_fee, s.is_open, s.verified,
      pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p JOIN stores s ON s.id=p.store_id LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE p.id=$1`, [req.params.id]);
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  p.variants = await q('SELECT * FROM product_variants WHERE product_id=$1 ORDER BY id', [p.id]);
  res.json({ product: p });
});

// ═══════════ محرك التنسيق الذكي «نسّق لي» — إطلالة كاملة حول أي منتج ═══════════
// ── إطلالات تلقائية من مشتريات الزبون الفعلية ──
r.get('/outfit/for-me', auth, async (req, res) => {
  const { buildOutfit } = await import('../outfit.js');
  const bought = await q(`SELECT DISTINCT oi.product_id
    FROM order_items oi JOIN orders o ON o.id=oi.order_id
    WHERE o.user_id=$1 AND o.status IN ('delivered','preparing','accepted','new','ready','picked','delivering')
      AND oi.product_id IS NOT NULL
    ORDER BY oi.product_id DESC LIMIT 4`, [req.user.id]);
  let ids = bought.map((r) => r.product_id);
  if (ids.length < 2) {
    const favs = await q(`SELECT product_id FROM favorites WHERE user_id=$1
      ORDER BY id DESC LIMIT ${4 - ids.length}`, [req.user.id]);
    ids = ids.concat(favs.map((r) => r.product_id));
  }
  if (!ids.length) return res.json({ outfits: [] });
  const seeds = await q(`SELECT p.*, s.name AS store_name, s.logo AS store_logo, s.id AS store_id,
      (pr.active AND pr.percent>0) AS has_offer,
      ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p JOIN stores s ON s.id=p.store_id
    LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE p.id = ANY($1::int[]) AND p.is_available`, [ids]);
  const outfits = [];
  for (const seed of seeds) {
    const outfit = await buildOutfit(seed, { occasion: 'casual' });
    if (outfit.slots.length >= 2) {
      outfits.push({ seed: { id: seed.id, name: seed.name, image: seed.image }, outfit });
    }
  }
  res.json({ outfits });
});

r.get('/outfit/:id', async (req, res) => {
  const seed = await one(`SELECT p.*, s.name AS store_name, s.logo AS store_logo, s.id AS store_id,
      (pr.active AND pr.percent>0) AS has_offer,
      ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p JOIN stores s ON s.id=p.store_id
    LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE p.id=$1 AND p.is_available`, [req.params.id]);
  if (!seed) return res.status(404).json({ error: 'المنتج غير موجود' });
  const { buildOutfit, qualityOf } = await import('../outfit.js');
  const outfit = await buildOutfit(seed, {
    budget: req.query.budget ? Number(req.query.budget) : 0,
    occasion: String(req.query.occasion || 'casual'),
    color: String(req.query.color || ''),
  });
  const quality = await qualityOf(seed);
  res.json({ seed: { id: seed.id, name: seed.name, image: seed.image, price: seed.price }, outfit, quality });
});

// ── الإعلانات النشطة ──
r.get('/ads', async (_req, res) => {
  const dAds = await demoCond('ads');
  res.json({ ads: await q(`SELECT a.*, s.name AS store_name, s.cover AS store_cover, s.logo AS store_logo FROM ad_requests a JOIN stores s ON s.id=a.store_id ${dAds ? `WHERE a.status='active' AND ${dAds.replaceAll('o.','a.')}` : `WHERE a.status='active'`} ORDER BY a.sort, a.id`) });
});

// ── العروض ──
r.get('/offers', async (_req, res) => {
  const dProduct = await demoCond('products', { o: 'p' });
  res.json({ products: await q(`SELECT p.*, s.name AS store_name, s.logo AS store_logo, pr.percent AS offer_percent,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM offers pr JOIN products p ON p.id=pr.product_id JOIN stores s ON s.id=p.store_id AND s.status='approved'
    ${dProduct ? `WHERE pr.active=true AND pr.percent>0 AND ${dProduct}` : `WHERE pr.active=true AND pr.percent>0`} ORDER BY p.id LIMIT 50`) });
});

// ── الإعدادات العامة ──
r.get('/settings', async (_req, res) => {
  const rows = await q('SELECT * FROM settings');
  res.json({ settings: Object.fromEntries(rows.map(x => [x.key, x.value])) });
});

export default r;
