import { Router } from 'express';
import { q, one, tx } from '../db.js';
import { auth, roles } from '../middleware.js';
import { isOpenNow, parseHour } from '../hours.js';

const r = Router();
r.use(auth, roles('vendor'));

const myStore = async (req) => one('SELECT * FROM stores WHERE owner_id=$1', [req.user.id]);

// تعقيم حقول العرض النصية (شعار/غلاف/فن/صورة إعلان) — يرفض وسوم HTML وعلامات التنصيص
const displayText = (v, max = 255) => {
  v = String(v ?? '').trim().slice(0, max);
  return /[<>"'`]/.test(v) ? null : v;
};
// تدرج ألوان CSS آمن: حروف وأرقام وألوان فقط
const cssSafe = (v, max = 500) => {
  v = String(v ?? '').trim().slice(0, max);
  if (!v) return v;
  return /^[\w\s#%(),.\-]+$/.test(v) ? v : null;
};

// ═══════════ المحل ═══════════
r.get('/store', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ store: null });
  s.is_open = isOpenNow(s);
  s.documents = await q('SELECT * FROM store_documents WHERE store_id=$1', [s.id]);
  s.products = await q(`SELECT p.*, pr.percent AS offer_percent, pr.active AS offer_active,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price,
      (SELECT COALESCE(sum(v.stock),0)::int FROM product_variants v WHERE v.product_id=p.id) AS variants_stock
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
  const logo = b.logo === undefined || b.logo === '' ? '🏪' : displayText(b.logo, 255);
  const cover = b.cover === undefined || b.cover === '' ? '' : displayText(b.cover, 2000);
  if (logo === null) return res.status(400).json({ error: 'الشعار غير صالح — نص فقط بدون وسوم HTML' });
  if (cover === null) return res.status(400).json({ error: 'الغلاف غير صالح — نص فقط بدون وسوم HTML' });
  const ns = (await q(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, cover, description, address, lat, lng, location_url, phone, delivery_fee, free_delivery_min, open_time, close_time, status)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,'pending') RETURNING *`,
    [req.user.id, gov.id, b.district_id || null, b.name, b.category_id || null, logo, cover,
    b.description || '', b.address || '', b.lat || null, b.lng || null, b.location_url || '', b.phone || '', 2000, 50000,
    b.open_time || '9ص', b.close_time || '11ل']))[0];
  await q(`INSERT INTO wallets (store_id) VALUES ($1)`, [ns.id]);
  await q(`INSERT INTO notifications (role, type, title, body, data) VALUES ('admin','store','محل جديد ينتظر التوثيق 🏪',$1, jsonb_build_object('store_id',$2::int))`, [ns.name, ns.id]);
  res.status(201).json({ store: ns });
});

r.patch('/store', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const b = req.body;
  const allowed = ['name', 'logo', 'cover', 'description', 'address', 'phone', 'open_time', 'close_time', 'is_open', 'category_id', 'district_id', 'lat', 'lng', 'location_url', 'on_vacation', 'warranty_days', 'work_hours'];
  const sets = [], p = [];
  for (const k of allowed) if (b[k] !== undefined) {
    // الدوام التلقائي: تحقق صارم من {enabled, open, close}
    if (k === 'work_hours') {
      const wh = b[k];
      const open = parseHour(wh?.open);
      const close = parseHour(wh?.close);
      if (!wh || typeof wh !== 'object' ||
          (wh.enabled !== undefined && typeof wh.enabled !== 'boolean') ||
          (wh.enabled && (open == null || close == null)))
        return res.status(400).json({ error: 'أوقات الدوام غير صحيحة — استخدم صيغة HH:MM (مثال 09:00)' });
      b[k] = JSON.stringify({ enabled: wh.enabled === true, open: open == null ? '' : wh.open, close: close == null ? '' : wh.close });
      sets.push(`work_hours=$${p.length + 1}::jsonb`);
      p.push(b[k]);
      continue;
    }
    if (k === 'logo' || k === 'cover') {
      const sv = displayText(b[k], k === 'cover' ? 2000 : 255);
      if (sv === null) return res.status(400).json({ error: k === 'logo' ? 'الشعار غير صالح — نص فقط بدون وسوم HTML' : 'الغلاف غير صالح — نص فقط بدون وسوم HTML' });
      b[k] = sv;
    }
    p.push(b[k]); sets.push(`${k}=$${p.length}`);
  }
  if (!sets.length) return res.json({ store: s });
  const ns = (await q(`UPDATE stores SET ${sets.join(', ')} WHERE id=$${p.length + 1} RETURNING *`, [...p, s.id]))[0];
  ns.is_open = isOpenNow(ns);
  res.json({ store: ns });
});

// ── مستندات التوثيق ──
const DOC_TYPES = ['national_id', 'store_license', 'other'];
r.post('/store/documents', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const { type, title, file_url = '' } = req.body;
  if (!DOC_TYPES.includes(type)) return res.status(400).json({ error: 'نوع المستند غير صحيح' });
  if (type === 'national_id' && !String(file_url).startsWith('/uploads/'))
    return res.status(400).json({ error: 'ارفع صورة البطاقة الوطنية عبر مسار الرفع أولاً' });
  const d = (await q(`INSERT INTO store_documents (store_id, type, title, file_url) VALUES ($1,$2,$3,$4) RETURNING *`,
    [s.id, type, title, file_url]))[0];
  await q(`INSERT INTO notifications (role, type, title, body) VALUES ('admin','store','مستند توثيق جديد',$1)`, [`${s.name}: ${title}`]);
  res.status(201).json({ document: d });
});

// ═══════════ الطلبات ═══════════
r.get('/orders', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ orders: [], total: 0 });
  const { status } = req.query;
  const limit = Math.max(1, Math.min(100, Number(req.query.limit) || 50));
  const offset = Math.max(0, Number(req.query.offset) || 0);
  const w = [`o.store_id=${s.id}`];
  const p = [];
  if (status && status !== 'all') { p.push(status); w.push(`o.status=$${p.length}`); }
  const total = (await one(`SELECT count(*)::int AS n FROM orders o WHERE ${w.join(' AND ')}`, p)).n;
  const orders = await q(`SELECT o.*, u.name AS user_name, u.phone AS user_phone FROM orders o
    LEFT JOIN users u ON u.id=o.user_id WHERE ${w.join(' AND ')} ORDER BY o.id DESC LIMIT $${p.length + 1} OFFSET $${p.length + 2}`, [...p, limit, offset]);
  // تفاصيل الأصناف كاملة: الصورة والسمات من جدول المنتجات (للقراءة من التاجر)
  const items = await q(`SELECT oi.*, o.id AS order_id, p.image, p.images, p.attributes
    FROM order_items oi JOIN orders o ON o.id=oi.order_id LEFT JOIN products p ON p.id=oi.product_id
    WHERE o.store_id=$1 AND o.id = ANY($2::int[])`, [s.id, orders.map(o => o.id)]);
  const returns = await q(`SELECT rf.*, o.code, o.total, u.name AS user_name FROM refund_requests rf
    JOIN orders o ON o.id=rf.order_id JOIN users u ON u.id=o.user_id WHERE o.store_id=$1 ORDER BY rf.id DESC`, [s.id]);
  res.json({ orders: orders.map(o => ({ ...o, items: items.filter(i => i.order_id === o.id) })), refunds: returns, total });
});

r.get('/orders/:id', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.status(404).json({ error: 'سجل محلك أول' });
  const o = await one(`SELECT o.*, u.name AS user_name, u.phone AS user_phone, c.name AS courier_name
    FROM orders o LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users c ON c.id=o.courier_id
    WHERE o.id=$1 AND o.store_id=$2`, [req.params.id, s.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  o.items = await q(`SELECT oi.*, p.image, p.images, p.attributes
    FROM order_items oi LEFT JOIN products p ON p.id=oi.product_id WHERE oi.order_id=$1`, [o.id]);
  o.history = await q('SELECT * FROM order_status_history WHERE order_id=$1 ORDER BY id', [o.id]);
  res.json({ order: o });
});

// ═══ تغيير حالة الطلب — يقبل PATCH (الصحيح) و POST (توافق مع النسخ المثبتة حالياً من التطبيق) ═══
const handleOrderStatus = async (req, res) => {
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
};
r.route('/orders/:id/status').patch(handleOrderStatus).post(handleOrderStatus);

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
  if (!b.name || !String(b.name).trim()) return res.status(400).json({ error: 'اكتب اسم المنتج' });
  // الأرقام العربية (٠-٩ / ۰-۹) → لاتينية، والكسور تُقرّب لأقرب دينار
  const norm = (v) => String(v ?? '').replace(/[٠-٩۰-۹]/g, (d) => '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'.indexOf(d) % 10).replace(/,/g, '.');
  const price = Math.round(Number(norm(b.price)));
  if (!isFinite(price) || price <= 0) return res.status(400).json({ error: 'اكتب سعر صحيح (أرقام فقط)' });
  const stock = Math.round(Number(norm(b.stock))) || 0;
  if (stock < 0) return res.status(400).json({ error: 'الكمية ما تكدر تكون سالبة' });
  const images = Array.isArray(b.images) ? b.images.filter((x) => typeof x === 'string' && x.trim() && x.startsWith('/uploads/')).slice(0, 8) : [];
  // إن أرسل المتجر base64 خام مو عبر مسار الرفع — نرفض قبل التخزين (لا نتآمن بسورس العميل)
  const rawImage = typeof b.image === 'string' && b.image.trim().startsWith('data:');
  const rawImages = Array.isArray(b.images) && b.images.some((x) => typeof x === 'string' && x.trim().startsWith('data:'));
  if (rawImage || rawImages) return res.status(400).json({ error: 'الصور لازم تُرفع عبر مسار الرفع أولاً (/api/uploads/upload)' });
  const image = (typeof b.image === 'string' && b.image.trim().startsWith('/uploads/')) ? b.image : (images[0] || '📦');
  const p = (await q(`INSERT INTO products (store_id, category_id, name, description, price, old_price, image, images, attributes, stock)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
    [s.id, b.category_id || null, String(b.name).trim(), b.description || '', price, b.old_price || null, image, images, b.attributes || {}, stock]))[0];
  if (Array.isArray(b.variants))
    for (const v of b.variants)
      await q(`INSERT INTO product_variants (product_id, vgroup, color, name, stock) VALUES ($1,$2,$3,$4,$5)`,
        [p.id, v.vgroup || 'قياس', v.color || '', v.name || 'قياسي', Math.round(Number(norm(v.stock))) || 0]);
  // عرض فوري عند الإضافة
  const ofp = Number(norm(b.offer_price));
  if (isFinite(ofp) && ofp > 0 && ofp < price) {
    const percent = Math.max(1, Math.min(95, Math.round((1 - ofp / price) * 100)));
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
  const norm = (v) => String(v ?? '').replace(/[٠-٩۰-۹]/g, (d) => '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'.indexOf(d) % 10).replace(/,/g, '.');
  if (b.price !== undefined) {
    const px = Math.round(Number(norm(b.price)));
    if (!isFinite(px) || px <= 0) return res.status(400).json({ error: 'اكتب سعر صحيح (أرقام فقط)' });
    b.price = px;
  }
  if (b.stock !== undefined) b.stock = Math.round(Number(norm(b.stock))) || 0;
  const allowed = ['name', 'description', 'price', 'old_price', 'image', 'images', 'is_available', 'category_id', 'attributes', 'stock'];
  const sets = [], pp = [];
  for (const k of allowed)
    if (b[k] !== undefined) {
      // رفض base64 خام يمر خارج مسار الرفع — المتاجر ترفع أولاً عبر /api/uploads/upload
      if (k === 'images' || k === 'image') {
        const v = k === 'images' ? b.images : [b.image];
        if (Array.isArray(v) && v.some((x) => typeof x === 'string' && x.trim().startsWith('data:')))
          return res.status(400).json({ error: 'الصور لازم تُرفع عبر مسار الرفع أولاً (/api/uploads/upload)' });
      }
      pp.push(k === 'images'
        ? (Array.isArray(b.images) ? b.images.filter((x) => typeof x === 'string' && x.trim() && x.startsWith('/uploads/')).slice(0, 8) : b.images)
        : k === 'image'
          ? (typeof b.image === 'string' && b.image.trim().startsWith('/uploads/') ? b.image : (b.image === undefined ? undefined : '📦'))
          : b[k]);
      sets.push(`${k}=$${pp.length}`);
    }
  if (sets.length) await q(`UPDATE products SET ${sets.join(', ')} WHERE id=$${pp.length + 1}`, [...pp, p.id]);
  // مزامنة الغلاف مع الصور — إذا انحذف الغلاف من المصفوفة يصير أول صورة هو الغلاف
  if (b.images !== undefined && Array.isArray(b.images) && b.images.length && !b.images.includes(p.image)) {
    await q(`UPDATE products SET image=$2 WHERE id=$1`, [p.id, b.images[0]]);
  }
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
  const { active = true } = req.body;
  const pct = Number(req.body.percent ?? 0);
  // نسبة الخصم: 0 لإيقاف العرض، وإلا بين 1 و 90 — يمنع عروض بأسعار سالبة
  if (!Number.isFinite(pct) || pct < 0 || pct > 90)
    return res.status(400).json({ error: 'نسبة الخصم بين 1% و 90% فقط — و 0 لإيقاف العرض' });
  const on = pct > 0 && !!active;
  await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,$3)
    ON CONFLICT (product_id) DO UPDATE SET percent=EXCLUDED.percent, active=EXCLUDED.active`, [p.id, pct, on]);
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
  const amount = Number(req.body.amount);
  if (!Number.isInteger(amount) || amount <= 0) return res.status(400).json({ error: 'المبلغ غلط' });
  if (amount > 25000000) return res.status(400).json({ error: 'المبلغ أكبر من المسموح بالسحب' });
  try {
    await tx(async (c) => {
      // قفل صف المحفظة — يمنع سحبين متزامنين لنفس الرصيد
      const w = (await c.query(`SELECT available FROM wallets WHERE store_id=$1 FOR UPDATE`, [s.id])).rows[0];
      if (!w || amount > w.available) throw Object.assign(new Error('الرصيد غير كافي'), { status: 400 });
      await c.query(`UPDATE wallets SET available=available-$1, updated_at=now() WHERE store_id=$2`, [amount, s.id]);
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'withdraw',$2,'استلام نقدي')`, [s.id, -amount]);
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message || 'خطأ بالسيرفر' });
  }
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
  const { title, art = '🖼', gradient = '', image = '', package_id, product_id, note = '' } = req.body;
  const artSafe = displayText(art, 255);
  const gradSafe = cssSafe(gradient);
  const imgSafe = displayText(image, 2000);
  const noteSafe = String(note || '').slice(0, 500);
  if (artSafe === null) return res.status(400).json({ error: 'فن الإعلان غير صالح — نص فقط بدون وسوم HTML' });
  if (gradSafe === null) return res.status(400).json({ error: 'تدرج الألوان غير صالح' });
  if (imgSafe === null) return res.status(400).json({ error: 'صورة الإعلان غير صالحة' });
  const t = (title || '').toString().trim();
  if (!t) return res.status(400).json({ error: 'نص الإعلان مطلوب' });
  if (t.length > 60) return res.status(400).json({ error: 'نص الإعلان أكثر من 60 حرف — خصره لحد 60' });
  if (!package_id) return res.status(400).json({ error: 'اختر باقة الإعلان' });
  if (product_id) {
    const p = await one('SELECT id FROM products WHERE id=$1 AND store_id=$2', [product_id, s.id]);
    if (!p) return res.status(400).json({ error: 'المنتج المختار ما يخص محلك' });
  }
  const pkg = await one('SELECT * FROM ad_packages WHERE id=$1 AND active=true', [package_id]);
  if (!pkg) return res.status(404).json({ error: 'الباقة غير متاحة' });

  let ad;
  try {
    await tx(async (c) => {
      // فحص الرصيد داخل المعاملة مع قفل — يمنع رصيد سالب وحجز إعلان برصيد وهمي
      const w = (await c.query(`SELECT available FROM wallets WHERE store_id=$1 FOR UPDATE`, [s.id])).rows[0];
      if (!w || (w.available ?? 0) < pkg.price)
        throw Object.assign(new Error('الرصيد غير كافي لحجز الإعلان — اشحن محفظتك'), { status: 400 });
      // طلب بانتظار موافقة الأدمن — الرصيد يُحجز فوراً ويُرجع لو انرفض
      ad = (await c.query(`INSERT INTO ad_requests (store_id, title, art, image, duration_days, price, gradient, status, sort, starts_at, ends_at, note, product_id)
        VALUES ($1,$2,$3,$4,$5,$6,$7,'pending',0,NULL,NULL,$8,$9) RETURNING *`,
        [s.id, t, artSafe, imgSafe, pkg.days, pkg.price, gradSafe, noteSafe, product_id || null])).rows[0];

      await c.query(`UPDATE wallets SET available=available-$1, updated_at=now() WHERE store_id=$2`, [pkg.price, s.id]);
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'ad',$2,$3)`, [s.id, -pkg.price, `حجز إعلان (بانتظار الموافقة): ${t}`]);
    });
  } catch (e) {
    return res.status(e.status || 500).json({ error: e.message || 'خطأ بالسيرفر' });
  }

  await q(`INSERT INTO notifications (role, type, title, body, data) VALUES ('admin','ad','طلب إعلان جديد بانتظارك 🖼',$1, jsonb_build_object('ad_id',$2::int))`,
    [`${t} — ${pkg.days} أيام — ${pkg.price.toLocaleString()} د.ع`, ad.id]);
  res.status(201).json({ ad });
});

// ── الإحصائيات السريعة للتاجر ──
r.get('/stats', async (req, res) => {
  const s = await myStore(req);
  if (!s) return res.json({ stats: null });
  const today = (await one(`SELECT count(*)::int AS orders, COALESCE(sum(total),0)::int AS sales FROM orders WHERE store_id=$1 AND created_at::date=CURRENT_DATE AND status NOT IN ('cancelled')`, [s.id]));
  const month = (await one(`SELECT count(*)::int AS orders, COALESCE(sum(total),0)::int AS sales FROM orders WHERE store_id=$1 AND created_at >= date_trunc('month', now()) AND status NOT IN ('cancelled')`, [s.id]));
  const fresh = (await one(`SELECT count(*)::int AS n FROM orders WHERE store_id=$1 AND status='new'`, [s.id]));
  res.json({ stats: { today_orders: today.orders, today_sales: today.sales, month_orders: month.orders, month_sales: month.sales, new_orders: fresh.n } });
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
  const clean = String(code || '').trim().toUpperCase().slice(0, 30);
  if (!clean) return res.status(400).json({ error: 'كود الكوبون مطلوب' });
  const pct = Number(percent || 0);
  const fl = Number(flat || 0);
  const minT = Number(min_total || 0);
  const maxD = Number(max_discount || 0);
  const usesL = Number(uses_limit || 0);
  // تحقق صارم: النسبة 1..100 أو المبلغ 1..999999، وكل الحدود غير سالبة
  if (pct < 0 || pct > 100 || fl < 0 || fl > 999999 || minT < 0 || maxD < 0 || usesL < 0)
    return res.status(400).json({ error: 'قيم الكوبون غير صالحة — راجع النسبة/المبلغ والحدود' });
  if (!pct && !fl) return res.status(400).json({ error: 'حدد نسبة % أو مبلغ خصم' });
  const c = (await q(`INSERT INTO coupons (store_id, code, percent, flat, min_total, max_discount, expires_at, uses_left, active)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [s.id, clean, pct || null, fl || null, minT, maxD, expires_at || null, usesL, active]))[0];
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
    WHERE store_id=$1 AND status='delivered' AND updated_at >= now() - interval '7 days'
  `, [s.id, s.commission_rate]);
  res.json(row);
});

export default r;
