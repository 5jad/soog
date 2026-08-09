import { Router } from 'express';
import { q, one, tx } from '../db.js';
import { auth, roles } from '../middleware.js';

const r = Router();
r.use(auth, roles('vendor'));

const myStore = async (req) => one('SELECT * FROM stores WHERE owner_id=$1', [req.user.id]);

// ═══════════ المحل ═══════════
r.get('/store', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ store: null });
  s.documents = await q('SELECT * FROM store_documents WHERE store_id=$1', [s.id]);
  s.products = await q(`SELECT p.*, pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p LEFT JOIN offers pr ON pr.product_id=p.id WHERE p.store_id=$1 ORDER BY p.id`, [s.id]);
  s.refunds = await q(`SELECT rf.*, o.code, o.total, o.status AS order_status, u.name AS user_name FROM refund_requests rf
    JOIN orders o ON o.id=rf.order_id JOIN users u ON u.id=o.user_id WHERE o.store_id=$1 ORDER BY rf.id DESC LIMIT 30`, [s.id]);
  res.json({ store: s });
});

r.post('/store', async (req, res) => {
  const b = req.body;
  if (!b.name) return res.status(400).json({ error: 'اسم المحل مطلوب' });
  const s = await myStore(req);
  if (s) return res.status(400).json({ error: 'عندك محل مسجل — كلش ثاني مو مسموح' });
  const gov = await one('SELECT id FROM governorates WHERE is_active ORDER BY id LIMIT 1');
  const ns = (await q(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, cover, description, address, lat, lng, location_url, phone, delivery_fee, free_delivery_min, open_time, close_time, status)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,'pending') RETURNING *`,
    [req.user.id, gov.id, b.district_id || null, b.name, b.category_id || null, b.logo || '🏪', b.cover || '',
    b.description || '', b.address || '', b.lat || null, b.lng || null, b.location_url || '', b.phone || '', b.delivery_fee || 2000, b.free_delivery_min || 50000,
    b.open_time || '9ص', b.close_time || '11ل']))[0];
  await q(`INSERT INTO wallets (store_id) VALUES ($1)`, [ns.id]);
  await q(`INSERT INTO notifications (role, type, title, body, data) VALUES ('admin','store','محل جديد ينتظر التوثيق 🏪',$1, jsonb_build_object('store_id',$2::int))`, [ns.name, ns.id]);
  res.status(201).json({ store: ns });
});

r.patch('/store', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const b = req.body;
  const allowed = ['name', 'logo', 'cover', 'description', 'address', 'phone', 'delivery_fee', 'free_delivery_min', 'open_time', 'close_time', 'is_open', 'category_id', 'district_id', 'lat', 'lng', 'location_url', 'on_vacation', 'warranty_days'];
  const sets = [], p = [];
  for (const k of allowed) if (b[k] !== undefined) { p.push(b[k]); sets.push(`${k}=$${p.length}`); }
  if (!sets.length) return res.json({ store: s });
  const ns = (await q(`UPDATE stores SET ${sets.join(', ')} WHERE id=$${p.length + 1} RETURNING *`, [...p, s.id]))[0];
  res.json({ store: ns });
});

// ── مستندات التوثيق ──
r.post('/store/documents', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { type, title, file_url = '' } = req.body;
  const d = (await q(`INSERT INTO store_documents (store_id, type, title, file_url) VALUES ($1,$2,$3,$4) RETURNING *`,
    [s.id, type, title, file_url]))[0];
  await q(`INSERT INTO notifications (role, type, title, body) VALUES ('admin','store','مستند توثيق جديد',$1)`, [`${s.name}: ${title}`]);
  res.status(201).json({ document: d });
});

// ═══════════ الطلبات ═══════════
r.get('/orders', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ orders: [] });
  const { status } = req.query;
  const w = [`o.store_id=${s.id}`];
  const p = [];
  if (status && status !== 'all') { p.push(status); w.push(`o.status=$${p.length}`); }
  const orders = await q(`SELECT o.*, u.name AS user_name, u.phone AS user_phone FROM orders o
    LEFT JOIN users u ON u.id=o.user_id WHERE ${w.join(' AND ')} ORDER BY o.id DESC LIMIT 50`, p);
  const items = await q(`SELECT oi.*, o.id AS order_id FROM order_items oi JOIN orders o ON o.id=oi.order_id WHERE o.store_id=$1`, [s.id]);
  const returns = await q(`SELECT rf.*, o.code, o.total, u.name AS user_name FROM refund_requests rf
    JOIN orders o ON o.id=rf.order_id JOIN users u ON u.id=o.user_id WHERE o.store_id=$1 ORDER BY rf.id DESC`, [s.id]);
  res.json({ orders: orders.map(o => ({ ...o, items: items.filter(i => i.order_id === o.id) })), refunds: returns });
});

r.get('/orders/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const o = await one(`SELECT o.*, u.name AS user_name, u.phone AS user_phone, c.name AS courier_name
    FROM orders o LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users c ON c.id=o.courier_id
    WHERE o.id=$1 AND o.store_id=$2`, [req.params.id, s.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  o.items = await q('SELECT * FROM order_items WHERE order_id=$1', [o.id]);
  o.history = await q('SELECT * FROM order_status_history WHERE order_id=$1 ORDER BY id', [o.id]);
  res.json({ order: o });
});

r.patch('/orders/:id/status', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { status, reason = '' } = req.body;
  const o = await one('SELECT * FROM orders WHERE id=$1 AND store_id=$2', [req.params.id, s.id]);
  if (!o) return res.status(404).json({ error: 'الطلب مو تابع لمحلك' });
  const allowed = { accept: ['new', 'preparing'], reject: ['new'], ready: ['preparing'] };
  const map = { accept: 'preparing', reject: 'cancelled', ready: 'ready' };
  if (!allowed[status] || !allowed[status].includes(o.status))
    return res.status(400).json({ error: `الحالة الحالية ${o.status} — ما تنفع` });
  await tx(async (c) => {
    await c.query(`UPDATE orders SET status=$1, updated_at=now() WHERE id=$2`, [map[status], o.id]);
    await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role, note) VALUES ($1,$2,$3,'vendor',$4)`,
      [o.id, o.status, map[status], reason]);
    if (status === 'reject')
      await c.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'order','طلبك انرفض من المحل',$2)`, [o.user_id, reason || 'السبب وصل بجوالك']);
    if (status === 'ready')
      await c.query(`INSERT INTO notifications (role, type, title, body, data) VALUES ('delivery','order','طلب جاهز للاستلام 🛵',$1, jsonb_build_object('order_id',$2::int))`, [`${s.name} — ${o.total.toLocaleString()} د.ع`, o.id]);
  });
  res.json({ ok: true, status: map[status] });
});

// ── الإرجاعات / الاستبدالات ──
r.patch('/refunds/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { status, reason = '' } = req.body;
  const rf = await one(`SELECT rf.*, o.user_id, o.status AS order_status FROM refund_requests rf JOIN orders o ON o.id=rf.order_id WHERE rf.id=$1 AND o.store_id=$2`, [req.params.id, s.id]);
  if (!rf) return res.status(404).json({ error: 'الطلب غير موجود' });
  if (rf.status !== 'pending') return res.status(400).json({ error: 'الطلب انحسم مسبقاً' });
  const accepted = status === 'accepted';
  await tx(async (c) => {
    await c.query(`UPDATE refund_requests SET status=$1, resolved_at=now() WHERE id=$2`, [status, rf.id]);
    if (accepted) {
      // الطلب المكتمل يُغلق بحالة returned + يُسجَّل بالتاريخ
      if (!['returned', 'cancelled'].includes(rf.order_status))
        await c.query(`UPDATE orders SET status='returned', updated_at=now() WHERE id=$1`, [rf.order_id]);
      await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role, note) VALUES ($1,$2,'returned','vendor',$3)`,
        [rf.order_id, rf.order_status, accepted ? 'تم الإرجاع' : reason || '']);
      // إرجاع المخزون لصفوف الطلب
      await c.query(`UPDATE product_variants v SET stock = v.stock + oi.qty
        FROM order_items oi WHERE oi.order_id=$1 AND oi.variant_id IS NOT NULL AND v.id=oi.variant_id`, [rf.order_id]);
      await c.query(`INSERT INTO notifications (user_id, type, title, body, data) VALUES ($1,'refund',
        CASE WHEN $2='exchange' THEN 'قبلنا استبدالك 🔁' ELSE 'قبلنا إرجاعك ✓' END,$3, jsonb_build_object('order_id',$4::int))`,
        [rf.user_id, rf.type, rf.type === 'exchange'
          ? `البديل «${rf.desired}» جاهز — تعال المحل للاستبدال${reason ? ` (${reason})` : ''}`
          : `استلمنا طلبك — تعال المحل نكمل معاك${reason ? ` (${reason})` : ''}`, rf.order_id]);
    } else {
      await c.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'refund','مرفوض ${rf.type === 'exchange' ? 'الاستبدال' : 'الإرجاع'}',$2)`,
        [rf.user_id, reason || '']);
    }
  });
  res.json({ ok: true, status });
});

// ═══════════ المنتجات ═══════════
r.get('/products', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ products: [] });
  const products = await q(`SELECT p.*, pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM products p LEFT JOIN offers pr ON pr.product_id=p.id WHERE p.store_id=$1 ORDER BY p.id`, [s.id]);
  const variants = await q(`SELECT v.* FROM product_variants v JOIN products p ON p.id=v.product_id WHERE p.store_id=$1`, [s.id]);
  res.json({ products: products.map(p => ({ ...p, variants: variants.filter(v => v.product_id === p.id) })) });
});

r.post('/products', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const b = req.body;
  if (!b.name || !b.price) return res.status(400).json({ error: 'الاسم والسعر مطلوبين' });
  const images = Array.isArray(b.images) ? b.images.filter((x) => typeof x === 'string' && x.trim()).slice(0, 8) : [];
  const image = b.image || images[0] || '📦';
  const p = (await q(`INSERT INTO products (store_id, category_id, name, description, price, old_price, image, images, attributes, stock)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
    [s.id, b.category_id || null, b.name, b.description || '', b.price, b.old_price || null, image, images, b.attributes || {}, b.stock ?? 0]))[0];
  if (Array.isArray(b.variants))
    for (const v of b.variants)
      await q(`INSERT INTO product_variants (product_id, vgroup, color, name, stock) VALUES ($1,$2,$3,$4,$5)`,
        [p.id, v.vgroup || 'قياس', v.color || '', v.name || 'قياسي', v.stock || 0]);
  // عرض فوري عند الإضافة
  if (b.offer_price && Number(b.offer_price) > 0 && Number(b.offer_price) < Number(p.price)) {
    const percent = Math.max(1, Math.min(95, Math.round((1 - Number(b.offer_price) / Number(p.price)) * 100)));
    await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,true)
      ON CONFLICT (product_id) DO UPDATE SET percent=EXCLUDED.percent, active=true`, [p.id, percent]);
  }
  res.status(201).json({ product: p });
});

r.patch('/products/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const p = await one('SELECT * FROM products WHERE id=$1 AND store_id=$2', [req.params.id, s.id]);
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  const b = req.body;
  const allowed = ['name', 'description', 'price', 'old_price', 'image', 'images', 'is_available', 'category_id', 'attributes', 'stock'];
  const sets = [], pp = [];
  for (const k of allowed)
    if (b[k] !== undefined) {
      pp.push(k === 'images' ? (Array.isArray(b.images) ? b.images.filter((x) => typeof x === 'string' && x.trim()).slice(0, 8) : b.images) : b[k]);
      sets.push(`${k}=$${pp.length}`);
    }
  if (sets.length) await q(`UPDATE products SET ${sets.join(', ')} WHERE id=$1`, [...pp, p.id]);
  // العرض: offer_price/offer_percent أو has_offer=false يلغي العرض
  if (b.has_offer !== undefined || b.offer_price !== undefined) {
    const px = Number(b.offer_price);
    if (b.has_offer === false || b.has_offer === 0 || (px > 0 && px >= Number(p.price))) {
      await q(`UPDATE offers SET active=false WHERE product_id=$1`, [p.id]);
    } else {
      const percent = px > 0 ? Math.max(1, Math.min(95, Math.round((1 - px / Number(p.price)) * 100))) : 0;
      await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,true)
        ON CONFLICT (product_id) DO UPDATE SET percent=EXCLUDED.percent, active=true`, [p.id, percent]);
    }
    const np = (await one('SELECT * FROM products WHERE id=$1', [p.id])) || p;
    // إعادة حساب العرض الجديد إن تغيّر السعر
    p.price = np.price;
  }
  // إدارة العرض: offer_percent مباشرة (0 = إلغاء)
  if (b.offer_percent !== undefined) {
    const per = Number(b.offer_percent);
    if (per > 0) await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,true)
        ON CONFLICT (product_id) DO UPDATE SET percent=EXCLUDED.percent, active=true`, [p.id, Math.max(1, Math.min(95, per))]);
    else await q(`UPDATE offers SET active=false WHERE product_id=$1`, [p.id]);
  }
  if (Array.isArray(b.variants)) {
    const ids = b.variants.map((v) => v.id).filter((x) => x != null && x !== '');
    await q(`DELETE FROM product_variants WHERE product_id=$1${ids.length ? ` AND NOT (id = ANY($2::int[]))` : ''}`, ids.length ? [p.id, ids] : [p.id]);
    for (const v of b.variants) {
      if (v.id) await q(`UPDATE product_variants SET vgroup=$1, color=$2, name=$3, stock=$4 WHERE id=$5 AND product_id=$6`, [v.vgroup || 'قياس', v.color || '', v.name || 'قياسي', v.stock || 0, v.id, p.id]);
      else await q(`INSERT INTO product_variants (product_id, vgroup, color, name, stock) VALUES ($1,$2,$3,$4,$5)`, [p.id, v.vgroup || 'قياس', v.color || '', v.name || 'قياسي', v.stock || 0]);
    }
  }
  res.json({ ok: true });
});

r.delete('/products/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  await q(`DELETE FROM products WHERE id=$1 AND store_id=$2`, [req.params.id, s.id]);
  res.json({ ok: true });
});

// ── العروض ──
r.post('/products/:id/offer', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const p = await one('SELECT * FROM products WHERE id=$1 AND store_id=$2', [req.params.id, s.id]);
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  const { percent = 0, active = true } = req.body;
  await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,$3)
    ON CONFLICT DO UPDATE SET percent=EXCLUDED.percent, active=EXCLUDED.active`, [p.id, percent, active]);
  res.json({ ok: true });
});

// ═══════════ المحفظة ═══════════
r.get('/wallet', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ wallet: null });
  const w = await one('SELECT * FROM wallets WHERE store_id=$1', [s.id]);
  const transactions = await q('SELECT * FROM wallet_transactions WHERE store_id=$1 ORDER BY id DESC LIMIT 30', [s.id]);
  if (w) w.balance = w.available;
  res.json({ wallet: w, transactions });
});

r.post('/wallet/withdraw', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { amount } = req.body;
  if (!amount || amount <= 0) return res.status(400).json({ error: 'المبلغ غلط' });
  const w = await one('SELECT * FROM wallets WHERE store_id=$1', [s.id]);
  if (amount > w.available) return res.status(400).json({ error: 'الرصيد غير كافي' });
  await tx(async (c) => {
    await c.query(`UPDATE wallets SET available=available-$1, updated_at=now() WHERE store_id=$2`, [amount, s.id]);
    await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'withdraw',$2,'استلام نقدي')`, [s.id, -amount]);
  });
  res.json({ ok: true });
});

// ═══════════ الإعلانات ═══════════
r.get('/ad-packages', async (req, res) => {
  res.json({ packages: await q("SELECT * FROM ad_packages WHERE active=true ORDER BY days") });
});

r.get('/ads', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ ads: [] });
  res.json({ ads: await q(`SELECT * FROM ad_requests WHERE store_id=$1 ORDER BY id DESC`, [s.id]) });
});

r.post('/ads', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { title, art = '🖼', gradient = '', package_id } = req.body;
  if (!title || !package_id) return res.status(400).json({ error: 'العنوان والباقة مطلوبين' });

  const pkg = await one('SELECT * FROM ad_packages WHERE id=$1 AND active=true', [package_id]);
  if (!pkg) return res.status(404).json({ error: 'الباقة غير متاحة' });

  let ad;
  await tx(async (c) => {
    ad = (await c.query(`INSERT INTO ad_requests (store_id, title, art, duration_days, price, gradient, status, starts_at, ends_at, sort) 
      VALUES ($1,$2,$3,$4,$5,$6,'active',now(),now()+interval '1 day' * $4, COALESCE((SELECT max(sort) FROM ad_requests WHERE status='active'),0)+1) RETURNING *`,
      [s.id, title, art, pkg.days, pkg.price, gradient])).rows[0];

    await c.query(`UPDATE wallets SET available=available-$1, updated_at=now() WHERE store_id=$2`, [pkg.price, s.id]);
    await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'ad',$2,$3)`, [s.id, -pkg.price, `ترويج منتج: ${title}`]);
  });

  await q(`INSERT INTO notifications (role, type, title, body, data) VALUES ('admin','ad','إعلان تفعل فوراً 🖼',$1, jsonb_build_object('ad_id',$2::int))`, [`${title} — ${pkg.days} أيام — ${pkg.price.toLocaleString()} د.ع`, ad.id]);
  res.status(201).json({ ad });
});

// ── الإحصائيات السريعة للتاجر ──
r.get('/stats', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ stats: null });
  const today = (await one(`SELECT count(*)::int AS orders, COALESCE(sum(total),0)::int AS sales FROM orders WHERE store_id=$1 AND created_at::date=CURRENT_DATE AND status NOT IN ('cancelled')`, [s.id]));
  const fresh = (await one(`SELECT count(*)::int AS n FROM orders WHERE store_id=$1 AND status='new'`, [s.id]));
  res.json({ stats: { today_orders: today.orders, today_sales: today.sales, new_orders: fresh.n } });
});

// ── إجازة المتجر ──
r.post('/store/vacation', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const on = !!req.body.on_vacation;
  await q(`UPDATE stores SET on_vacation=$1 WHERE id=$2`, [on, s.id]);
  res.json({ ok: true, on_vacation: on });
});

// ═══════════ الكوبونات ═══════════
r.get('/coupons', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ coupons: [] });
  res.json({ coupons: await q(`SELECT * FROM coupons WHERE store_id=$1 OR store_id IS NULL ORDER BY id DESC`, [s.id]) });
});

r.post('/coupons', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { code, percent, flat, min_total = 0, max_discount = 0, expires_at, uses_limit = 0, active = true } = req.body;
  const clean = String(code || '').trim().toUpperCase();
  if (!clean) return res.status(400).json({ error: 'كود الكوبون مطلوب' });
  if (!percent && !flat) return res.status(400).json({ error: 'حدد نسبة % أو مبلغ خصم' });
  const c = (await q(`INSERT INTO coupons (store_id, code, percent, flat, min_total, max_discount, expires_at, uses_left, active)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [s.id, clean, percent || null, flat || null, min_total, max_discount, expires_at || null, uses_limit, active]))[0];
  res.status(201).json({ coupon: c });
});

r.delete('/coupons/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  await q(`DELETE FROM coupons WHERE id=$1 AND store_id=$2`, [req.params.id, s.id]);
  res.json({ ok: true });
});

// ═══════════ أسئلة المنتجات (Q&A) ═══════════
r.get('/questions', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ questions: [] });
  res.json({ questions: await q(`SELECT pq.*, p.name AS product_name, u.name AS user_name FROM product_questions pq
    JOIN products p ON p.id=pq.product_id JOIN users u ON u.id=pq.user_id
    WHERE pq.store_id=$1 AND pq.answer IS NULL ORDER BY pq.id DESC LIMIT 50`, [s.id]) });
});

r.post('/questions/:id/answer', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const qrow = await one(`SELECT pq.* FROM product_questions pq JOIN products p ON p.id=pq.product_id WHERE pq.id=$1 AND p.store_id=$2`, [req.params.id, s.id]);
  if (!qrow) return res.status(404).json({ error: 'السؤال غير موجود' });
  await q(`UPDATE product_questions SET answer=$1, answered_at=now() WHERE id=$2`, [String(req.body.answer || '').slice(0, 500), qrow.id]);
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'qa','جاوبنا سؤالك 📩',$2)`, [qrow.user_id, String(req.body.answer || '').slice(0, 80)]);
  res.json({ ok: true });
});

// ═══════════ محادثات التاجر مع الزبائن ═══════════
r.get('/conversations', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ conversations: [] });
  const rows = await q(`SELECT cv.*, u.name AS user_name, 
      (SELECT body FROM messages m WHERE m.conversation_id=cv.id ORDER BY m.id DESC LIMIT 1) AS last_message,
      EXISTS(SELECT 1 FROM messages m WHERE m.conversation_id=cv.id AND m.sender_role='customer' AND m.read_at IS NULL) AS has_unread
    FROM conversations cv JOIN users u ON u.id=cv.user_id
    WHERE cv.store_id=$1 ORDER BY cv.last_message_at DESC`, [s.id]);
  res.json({ conversations: rows });
});

r.get('/conversations/:id/messages', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND store_id=$2', [req.params.id, s.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  const msgs = await q(`SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id=m.sender_id
    WHERE m.conversation_id=$1 ORDER BY m.id`, [cv.id]);
  await q(`UPDATE messages SET read_at=now() WHERE conversation_id=$1 AND sender_role='customer' AND read_at IS NULL`, [cv.id]);
  res.json({ conversation: cv, messages: msgs });
});

r.post('/conversations/:id/messages', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND store_id=$2', [req.params.id, s.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  const body = String(req.body.body || '').slice(0, 1000);
  const m = (await q(`INSERT INTO messages (conversation_id, sender_id, sender_role, body) VALUES ($1,$2,'vendor',$3) RETURNING *`, [cv.id, req.user.id, body]))[0];
  await q(`UPDATE conversations SET last_message_at=now() WHERE id=$1`, [cv.id]);
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'chat','ردّ من المحل 💬',$2)`, [cv.user_id, body.slice(0, 60)]);
  res.status(201).json({ message: m });
});

// ── بدء محادثة من طلب ──
r.post('/orders/:id/conversation', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const o = await one(`SELECT * FROM orders WHERE id=$1 AND store_id=$2`, [req.params.id, s.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  let cv = await one(`SELECT * FROM conversations WHERE user_id=$1 AND store_id=$2`, [o.user_id, s.id]);
  if (!cv) cv = (await q(`INSERT INTO conversations (user_id, store_id) VALUES ($1,$2) RETURNING *`, [o.user_id, s.id]))[0];
  res.json({ conversation: cv });
});

// ═══════════ تصدير CSV ═══════════
r.get('/export/products.csv', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const rows = await q(`SELECT p.name, p.price, COALESCE(p.old_price,0) AS old_price, p.stock, p.is_available FROM products p WHERE p.store_id=$1 ORDER BY p.id`, [s.id]);
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const csv = ['name,price,old_price,stock,is_available', ...rows.map(r => [r.name, r.price, r.old_price, r.stock, r.is_available].map(esc).join(','))].join('\n');
  res.header('Content-Type', 'text/csv; charset=utf-8').header('Content-Disposition', `attachment; filename="products.csv"`).send(csv);
});

r.get('/export/orders.csv', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const rows = await q(`SELECT o.code, o.total, o.status, o.created_at, u.name AS customer FROM orders o JOIN users u ON u.id=o.user_id WHERE o.store_id=$1 ORDER BY o.id`, [s.id]);
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  res.header('Content-Type', 'text/csv; charset=utf-8').header('Content-Disposition', `attachment; filename="orders.csv"`).send(['code,total,status,created_at,customer', ...rows.map(r => [r.code, r.total, r.status, r.created_at, r.customer].map(esc).join(','))].join('\n'));
});

// ── مستحقات التاجر هذا الأسبوع (بعد العمولة فقط) ──
r.get('/week-earnings', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ gross: 0, commission_due: 0, net_due: 0 });
  const row = await one(`
    SELECT
      COALESCE(SUM(total), 0)::int AS gross,
      ROUND(COALESCE(SUM(total), 0) * $2 / 100)::int AS commission_due,
      ROUND(COALESCE(SUM(total), 0) * (1 - $2 / 100))::int AS net_due
    FROM orders
    WHERE store_id=$1 AND status NOT IN ('cancelled') AND created_at >= now() - interval '7 days'
  `, [s.id, s.commission_rate]);
  res.json(row);
});

export default r;
