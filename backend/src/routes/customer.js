import { Router } from 'express';
import { q, one, tx } from '../db.js';
import { auth } from '../middleware.js';
import { calculateDeliveryPrice } from '../pricing/delivery.js';
import { isOpenNow } from '../hours.js';

const r = Router();
r.use(auth);

// ═══════════ السلة ═══════════
r.get('/cart', async (req, res) => {
  const items = await q(`SELECT c.id, c.qty, p.id AS product_id, p.name, p.price, p.image, p.old_price,
      v.id AS variant_id, COALESCE(c.variant_label, CASE WHEN v.color <> '' THEN v.color || ' · ' || v.name ELSE v.name END) AS variant, v.stock, s.id AS store_id, s.name AS store_name, s.logo, s.delivery_fee, s.free_delivery_min,
      (pr.active AND pr.percent>0) AS has_offer, pr.percent AS offer_percent,
      ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM cart_items c
    JOIN products p ON p.id=c.product_id
    JOIN stores s ON s.id=p.store_id
    LEFT JOIN product_variants v ON v.id=c.variant_id
    LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE c.user_id=$1 ORDER BY c.id`, [req.user.id]);
  res.json({ items, cart: items });
});

r.post('/cart', async (req, res) => {
  const { product_id, variant_id = null, variant = null, variant_label = null } = req.body;
  const qty = Number(req.body.qty ?? 1);
  if (!Number.isInteger(qty) || qty < 1) return res.status(400).json({ error: 'الكمية غير صالحة — اكتب رقماً موجباً' });
  if (qty > 99) return res.status(400).json({ error: 'الكمية أكبر من المسموح (99)' });
  const p = await one('SELECT * FROM products WHERE id=$1 AND is_available', [product_id]);
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  let vid = variant_id;
  if (variant && !vid) {
    const v = await one('SELECT id FROM product_variants WHERE product_id=$1 AND name=$2', [product_id, variant]);
    vid = v?.id ?? null;
  }
  if (vid) {
    const v = await one('SELECT * FROM product_variants WHERE id=$1 AND product_id=$2', [vid, product_id]);
    if (!v) return res.status(404).json({ error: 'المقاس غير موجود' });
    if (v.stock === 0) return res.status(400).json({ error: 'هذا المقاس نفد — جرب غيره' });
  }
  const label = String(variant_label || '').trim();
  if (vid) {
    await q(`INSERT INTO cart_items (user_id, product_id, variant_id, qty) VALUES ($1,$2,$3,$4)
      ON CONFLICT (user_id, product_id, variant_id) DO UPDATE SET qty = cart_items.qty + $4`,
      [req.user.id, product_id, vid, qty]);
  } else if (label) {
    const row = await one(`SELECT id FROM cart_items WHERE user_id=$1 AND product_id=$2 AND variant_id IS NULL AND variant_label=$3`,
      [req.user.id, product_id, label]);
    if (row) await q(`UPDATE cart_items SET qty = qty + $1 WHERE id=$2`, [qty, row.id]);
    else await q(`INSERT INTO cart_items (user_id, product_id, variant_label, qty) VALUES ($1,$2,$3,$4)`,
      [req.user.id, product_id, label, qty]);
  } else {
    const existing = await one(`SELECT id FROM cart_items WHERE user_id=$1 AND product_id=$2 AND variant_id IS NULL AND variant_label=''`,
      [req.user.id, product_id]);
    if (existing) await q(`UPDATE cart_items SET qty = qty + $1 WHERE id=$2`, [qty, existing.id]);
    else await q(`INSERT INTO cart_items (user_id, product_id, variant_id, qty) VALUES ($1,$2,NULL,$3)`,
      [req.user.id, product_id, qty]);
  }
  const items = await q('SELECT * FROM cart_items WHERE user_id=$1', [req.user.id]);
  res.json({ ok: true, count: items.reduce((a, b) => a + b.qty, 0) });
});

async function patchQty(item, qtyRaw, res) {
  const qty = Number(qtyRaw);
  if (!Number.isFinite(qty)) return res.status(400).json({ error: 'الكمية غير صالحة' });
  if (qty <= 0) await q('DELETE FROM cart_items WHERE id=$1', [item.id]);
  else {
    if (qty > 99) return res.status(400).json({ error: 'الكمية أكبر من المسموح (99)' });
    await q('UPDATE cart_items SET qty=$1 WHERE id=$2', [qty, item.id]);
  }
  res.json({ ok: true });
}

r.patch('/cart', async (req, res) => {
  const { item_id } = req.body;
  const item = await one('SELECT * FROM cart_items WHERE id=$1 AND user_id=$2', [item_id, req.user.id]);
  if (!item) return res.status(404).json({ error: 'المنتج مو بالسلة' });
  return patchQty(item, req.body.qty, res);
});

r.patch('/cart/:id', async (req, res) => {
  const item = await one('SELECT * FROM cart_items WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  if (!item) return res.status(404).json({ error: 'المنتج مو بالسلة' });
  return patchQty(item, req.body.qty, res);
});

r.delete('/cart/:id', async (req, res) => {
  await q('DELETE FROM cart_items WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  res.json({ ok: true });
});

// ═══════════ العناوين ═══════════
r.get('/addresses', async (req, res) => {
  const rows = await q('SELECT * FROM addresses WHERE user_id=$1 ORDER BY is_default DESC, id', [req.user.id]);
  res.json({ addresses: rows.map(a => ({ ...a, address: `${a.label || ''}${a.details ? ' — ' + a.details : ''}` })) });
});
r.post('/addresses', async (req, res) => {
  const { district_id, details, label = 'الرئيسي', lat = null, lng = null } = req.body;
  const a = (await q(`INSERT INTO addresses (user_id, district_id, label, details, lat, lng) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.user.id, district_id || null, label, details, lat, lng]))[0];
  res.json({ address: a });
});
r.delete('/addresses/:id', async (req, res) => {
  await q('DELETE FROM addresses WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  res.json({ ok: true });
});

// ═══════════ الطلبات ═══════════
r.get('/orders', async (req, res) => {
  const limit = Math.max(1, Math.min(100, Number(req.query.limit) || 30));
  const offset = Math.max(0, Number(req.query.offset) || 0);
  const total = (await one(`SELECT count(*)::int AS n FROM orders WHERE user_id=$1`, [req.user.id])).n;
  const orders = await q(`SELECT o.*, s.name AS store_name, s.logo AS store_logo,
      c.name AS courier_name, u.name AS user_name
    FROM orders o
    JOIN stores s ON s.id=o.store_id
    LEFT JOIN users c ON c.id=o.courier_id
    LEFT JOIN users u ON u.id=o.user_id
    WHERE o.user_id=$1 ORDER BY o.id DESC LIMIT $2 OFFSET $3`, [req.user.id, limit, offset]);
  const items = await q(`SELECT oi.*, o.id AS order_id FROM order_items oi JOIN orders o ON o.id=oi.order_id WHERE o.user_id=$1 AND o.id = ANY($2::int[])`, [req.user.id, orders.map(o => o.id)]);
  res.json({ orders: orders.map(o => ({ ...o, items: items.filter(i => i.order_id === o.id) })), total });
});

r.get('/orders/:id', async (req, res) => {
  const o = await one(`SELECT o.*, s.name AS store_name, s.logo AS store_logo, s.address AS store_address, s.phone AS store_phone,
c.id AS courier_id, c.name AS courier_name, c.phone AS courier_phone
    FROM orders o JOIN stores s ON s.id=o.store_id LEFT JOIN users c ON c.id=o.courier_id WHERE o.id=$1 AND o.user_id=$2`,
    [req.params.id, req.user.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  o.items = await q('SELECT * FROM order_items WHERE order_id=$1', [o.id]);
  // متغيرات كل منتج بالطلب — لاختيار البديل (استبدال)
  for (const it of o.items) {
    it.variants = await q(`SELECT id, color, name, stock FROM product_variants WHERE product_id=$1 ORDER BY id`, [it.product_id]);
  }
  o.history = await q('SELECT * FROM order_status_history WHERE order_id=$1 ORDER BY id', [o.id]);
  // آخر مهلة للاسترجاع/الاستبدال = وقت التسليم + أيام الضمان
  const del = await one(`SELECT created_at FROM order_status_history WHERE order_id=$1 AND to_status='delivered' ORDER BY id DESC LIMIT 1`, [o.id]);
  if (del) {
    o.deadline = new Date(new Date(del.created_at).getTime() + (o.warranty_days ?? 3) * 86400000).toISOString();
    o.withdrawn = o.deadline ? Date.now() > new Date(o.deadline).getTime() : false;
  }
  o.refund = await one('SELECT * FROM refund_requests WHERE order_id=$1 ORDER BY id DESC LIMIT 1', [o.id]) ?? null;
  res.json({ order: o });
});

// ── تتبع حي: موقع المندوب على الخريطة ──
r.get('/orders/:id/track', async (req, res) => {
  const o = await one(`SELECT o.id, o.code, o.status, o.courier_id, o.group_id, c.name AS courier_name, c.phone AS courier_phone,
      t.lat AS courier_lat, t.lng AS courier_lng, t.location_updated_at,
      s.lat AS store_lat, s.lng AS store_lng, s.name AS store_name,
      a.lat AS user_lat, a.lng AS user_lng
    FROM orders o LEFT JOIN users c ON c.id=o.courier_id
    LEFT JOIN delivery_trips t ON t.id=(SELECT trip_id FROM trip_orders tr WHERE tr.order_id=o.id LIMIT 1) AND t.courier_id=o.courier_id
    LEFT JOIN stores s ON s.id=o.store_id LEFT JOIN addresses a ON a.id=o.address_id
    WHERE o.id=$1 AND o.user_id=$2`, [req.params.id, req.user.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  // إذا الطلب من مجموعة (أكثر من محل) — نرجع محلات كل طلبات المجموعة ليطلع مسار واحد يمر بها كلها
  if (o.group_id) {
    o.group_stores = await q(`SELECT s.id, s.name, s.lat, s.lng FROM orders o2 JOIN stores s ON s.id=o2.store_id
      WHERE o2.group_id=$1 AND o2.user_id=$2 ORDER BY o2.id`, [o.group_id, req.user.id]);
  }
  o.path = await q(`SELECT l.lat, l.lng FROM delivery_track_log l JOIN delivery_trips t ON t.id=l.trip_id
    WHERE t.id IN (SELECT trip_id FROM trip_orders WHERE order_id=$1) ORDER BY l.id`, [o.id]);
  res.json({ tracking: o });
});

// ── قواعد التحقق: من جدول settings (الأدمن يعدّلها) مع fallback افتراضي ──
async function smartRule(key, def) {
  const row = await one(`SELECT value FROM settings WHERE key=$1`, [key]);
  return row && row.value !== '' ? parseInt(row.value, 10) : def;
}
// هل يحتاج هذا الطلب تحققاً جديداً؟ (أول طلب / سلة كبيرة / رفض سابق)
async function phoneVerifyNeeded(userId, subtotal) {
  const threshold = await smartRule('verify_order_threshold', 30000);
  const refuseRule = await smartRule('verify_refused_rule', 1);
  if (subtotal >= threshold) return true;
  const previous = await one('SELECT id FROM orders WHERE user_id=$1 LIMIT 1', [userId]);
  if (!previous) return true;
  if (refuseRule) {
    const refused = await one(`SELECT id FROM orders WHERE user_id=$1 AND status='returned' LIMIT 1`, [userId]);
    if (refused) return true;
  }
  return false;
}
// هل يوجد تحقق حديث ناجح (ضمن النافذة)؟
async function freshVerification(userId, windowMin) {
  const w = Math.max(1, Math.min(parseInt(windowMin, 10) || 10, 120));
  return one(`SELECT 1 FROM phone_verifications
              WHERE user_id=$1 AND status='verified' AND verified_at > now() - ('${w} minutes')::INTERVAL LIMIT 1`,
             [userId]);
}

r.post('/orders', async (req, res) => {
  const { store_id, address_id, note = '', address, coupon_code, redeem_points = 0, scheduled_at, group_id, payment_method = 'cod' } = req.body;
  const items = await q(`SELECT c.*, p.name, p.price, p.image, p.store_id, c.product_id,
      COALESCE(c.variant_label, v.name) AS variant, v.id AS variant_id, v.stock AS variant_stock,
      (pr.active AND pr.percent>0) AS has_offer, ROUND(p.price*(1-COALESCE(pr.percent,0)/100.0)) AS offer_price
    FROM cart_items c JOIN products p ON p.id=c.product_id LEFT JOIN product_variants v ON v.id=c.variant_id
    LEFT JOIN offers pr ON pr.product_id=p.id AND pr.active=true
    WHERE c.user_id=$1 AND p.store_id=$2`, [req.user.id, store_id]);
  if (!items.length) return res.status(400).json({ error: 'السلة فاضية لهذا المحل' });

  const store = await one('SELECT * FROM stores WHERE id=$1 AND status=$2', [store_id, 'approved']);
  if (!store) return res.status(404).json({ error: 'المحل غير موجود' });
  if (store.on_vacation) return res.status(400).json({ error: 'المحل ويا إجازة حالياً — جرب بعدين' });
  if (!isOpenNow(store)) return res.status(400).json({ error: 'المحل مغلق حالياً — جرب بعد ساعات الدوام' });

  const addr = address_id ? await one('SELECT * FROM addresses WHERE id=$1 AND user_id=$2', [address_id, req.user.id]) : null;

  // الفوترة بسعر العرض إن كان مفعّلاً — الزبون يدفع نفس اللي شافه بالسلة
  const subtotal = items.reduce((a, b) => a + (b.has_offer ? b.offer_price : b.price) * b.qty, 0);

  // ── سعر التوصيل بالمعادلة الجديدة (مسافة + تعدد محلات) ──
  // إذا عندنا إحداثيات المحل والزبون نحسب بدقة، وإلا نحط الحد الأدنى 1500
  const storePoint = (store.lat && store.lng) ? { lat: +store.lat, lng: +store.lng } : null;
  const userPoint = (addr?.lat && addr?.lng) ? { lat: +addr.lat, lng: +addr.lng } : null;
  const fee = storePoint && userPoint
    ? calculateDeliveryPrice([storePoint], userPoint).total_price
    : 1500; // حد أدنى إذا ما عندنا إحداثيات
  const baseDiscount = 0; // ألغينا خصم الـ 50 ألف — السعر بالمسافة يغني عنه

  // ── تم إعادة تفعيل حارس التحقق بناء على طلب المستخدم ──
  const windowMin = await smartRule('verify_window_min', 10);
  if (await phoneVerifyNeeded(req.user.id, subtotal)) {
    if (!(await freshVerification(req.user.id, windowMin)))
      return res.status(403).json({ error: 'أكّد رقم هاتفك أولاً عبر تلغرام', verify_required: true });
  }

  // ── الكوبون ──
  let coupon = null, couponDiscount = 0;
  if (coupon_code) {
    // uses_left = 0 معناها بلا حد (حسب المخطط)، وأي كوبون منتهي الصلاحية/موقوف يرد خطأ
    coupon = await one(`SELECT * FROM coupons WHERE code=$1 AND active=true AND (expires_at IS NULL OR expires_at > now())`, [String(coupon_code).trim().toUpperCase()]);
    if (!coupon) return res.status(400).json({ error: 'الكوبون غير صالح' });
    if (coupon.min_total > subtotal) return res.status(400).json({ error: `الحد الأدنى للكوبون ${coupon.min_total.toLocaleString()} د.ع` });
    if (coupon.store_id && coupon.store_id !== store_id) return res.status(400).json({ error: 'هذا الكوبون لمحل آخر' });
    const used = await one(`SELECT count(*)::int AS n FROM coupon_usages WHERE coupon_id=$1 AND user_id=$2`, [coupon.id, req.user.id]);
    if (used.n >= (coupon.allowed_uses_per_user || 1)) return res.status(400).json({ error: 'استعملت هذا الكوبون من قبل' });
    couponDiscount = coupon.percent
      ? Math.round(subtotal * coupon.percent / 100)
      : coupon.flat;
    if (coupon.max_discount && couponDiscount > coupon.max_discount) couponDiscount = coupon.max_discount;
  }

  // ── استخدم النقاط ──
  let pointsUsed = Math.max(0, Math.min(parseInt(redeem_points) || 0, req.user.points || 0));
  const POINT_RATE = 100; // كل 100 نقطة = 1000 د.ع
  pointsUsed = pointsUsed - (pointsUsed % POINT_RATE); // بدون ما تضيع النقاط الزايدة
  let pointsDiscount = Math.floor(pointsUsed / POINT_RATE) * 1000;
  if (pointsDiscount > subtotal) { pointsUsed = Math.floor(subtotal / 1000) * POINT_RATE; pointsDiscount = subtotal; }

  const discount = baseDiscount;
  const total = Math.max(0, subtotal + fee - discount - couponDiscount - pointsDiscount);

  let order;
  try {
    order = await tx(async (c) => {
        const o = (await c.query(`INSERT INTO orders (code, user_id, store_id, subtotal, delivery_fee, discount, coupon_code, coupon_id, points_used, points_discount, scheduled_at, group_id, warranty_days, total, note, address_id, address_text, payment_method)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18) RETURNING *`,
          ['', req.user.id, store_id, subtotal, fee, discount, coupon?.code || '', coupon?.id || null, pointsUsed, pointsDiscount, scheduled_at || null, group_id || null, store.warranty_days ?? 3, total, note, addr?.id || null,
            address || (addr ? `${addr.label} — ${addr.details}` : 'عنوان عند التوصيل'), payment_method])).rows[0];
        await c.query(`UPDATE orders SET code='ZB-'||(10000+id) WHERE id=$1`, [o.id]);
        o.code = `ZB-${10000 + o.id}`;
        for (const it of items)
          await c.query(`INSERT INTO order_items (order_id, product_id, variant_id, name, variant, price, qty) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
            [o.id, it.product_id, it.variant_id, it.name, it.variant || '', it.has_offer ? it.offer_price : it.price, it.qty]);
        // ── خصم المخزون ذرّياً — يمنع بيع كمية غير موجودة ──
        for (const it of items) {
          if (it.variant_id) {
            const vr = await c.query(`UPDATE product_variants SET stock = stock - $1 WHERE id=$2 AND stock >= $1`, [it.qty, it.variant_id]);
            if (vr.rowCount === 0) throw Object.assign(new Error('نفدت الكمية من المخزون — عدّل سلتك'), { status: 400 });
          } else {
            const pr = await c.query(`UPDATE products SET stock = stock - $1 WHERE id=$2 AND stock >= $1`, [it.qty, it.product_id]);
            if (pr.rowCount === 0) throw Object.assign(new Error('نفدت الكمية من المخزون — عدّل سلتك'), { status: 400 });
          }
        }
        await c.query(`INSERT INTO order_status_history (order_id, to_status, by_role) VALUES ($1,'new','customer')`, [o.id]);
        await c.query(`DELETE FROM cart_items WHERE user_id=$1 AND product_id IN (SELECT id FROM products WHERE store_id=$2)`, [req.user.id, store_id]);
        // سجل استخدام الكوبون
        if (coupon) {
          await c.query(`INSERT INTO coupon_usages (coupon_id, user_id, order_id, discount) VALUES ($1,$2,$3,$4)`, [coupon.id, req.user.id, o.id, couponDiscount]);
          if (coupon.uses_left > 0) await c.query(`UPDATE coupons SET uses_left = uses_left - 1 WHERE id=$1 AND uses_left > 0`, [coupon.id]);
        }
    // خصم النقاط من رصيد الزبون
    if (pointsUsed) {
      await c.query(`UPDATE users SET points = points - $1 WHERE id=$2`, [pointsUsed, req.user.id]);
      await c.query(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,$2,'redeem',$3,$4)`,
        [req.user.id, -pointsUsed, `استبدال نقاط = ${pointsDiscount.toLocaleString()} د.ع خصم`, `order ${o.id}`]);
    }
    await c.query(`INSERT INTO notifications (user_id, type, title, body, data)
      VALUES ($1,'order','طلب جديد وصل 🧾 #'||$2::text,'من ${req.user.name || 'زبون'} — ${total.toLocaleString()} د.ع كاش', jsonb_build_object('order_id',$3::int))`,
      [store.owner_id, o.code, o.id]);
      return o;
    });
  } catch (e) {
    // تراجع كامل للمعاملة — أي خطأ (نفاد مخزون مثلاً) يرد كرسالة واضحة
    return res.status(e.status || 500).json({ error: e.message || 'خطأ بالسيرفر — جرب مرة ثانية' });
  }

  res.status(201).json({ order });
});

r.post('/orders/:id/cancel', async (req, res) => {
  const o = await one('SELECT * FROM orders WHERE id=$1 AND user_id=$2 AND status=$3', [req.params.id, req.user.id, 'new']);
  if (!o) return res.status(400).json({ error: 'الطلب انجهز أو انلغى — ما ينفع' });
  await tx(async (c) => {
    await c.query(`UPDATE orders SET status='cancelled', updated_at=now() WHERE id=$1`, [o.id]);
    await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role, note) VALUES ($1,'new','cancelled','customer','إلغاء من الزبون')`, [o.id]);
    // إرجاع المخزون المحجوز للطلب الملغي
    const oitems = await c.query(`SELECT product_id, variant_id, qty FROM order_items WHERE order_id=$1`, [o.id]);
    for (const it of oitems.rows) {
      if (it.variant_id) await c.query(`UPDATE product_variants SET stock = stock + $1 WHERE id=$2`, [it.qty, it.variant_id]);
      else await c.query(`UPDATE products SET stock = stock + $1 WHERE id=$2`, [it.qty, it.product_id]);
    }
  });
  res.json({ ok: true });
});

// ═══════════ التقييم ═══════════
r.post('/orders/:id/rate', async (req, res) => {
  const { rating, comment = '' } = req.body;
  const o = await one('SELECT * FROM orders WHERE id=$1 AND user_id=$2 AND status=$3', [req.params.id, req.user.id, 'delivered']);
  if (!o) return res.status(400).json({ error: 'ما تكدر تقيّم إلا طلب مسلّم' });
  const rev = (await q(`INSERT INTO reviews (order_id, store_id, user_id, rating, comment) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [o.id, o.store_id, req.user.id, rating, comment]))[0];
  await q(`UPDATE stores SET rating_avg=ROUND((rating_avg*rating_count+$1)::numeric/(rating_count+1),2), rating_count=rating_count+1 WHERE id=$2`,
    [rating, o.store_id]);
  
  // Reward 5 points for the review
  await q(`UPDATE users SET points = points + 5 WHERE id=$1`, [req.user.id]);
  await q(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1, 5, 'earn', 'مكافأة تقييم الطلب ⭐', $2)`, [req.user.id, o.id]);

  res.json({ review: rev });
});

// ═══════════ الإرجاع / الاستبدال ═══════════
r.post('/orders/:id/return', async (req, res) => {
  const { reason, details = '', type = 'return', desired = '', variant_id = null } = req.body;
  const o = await one(`SELECT * FROM orders WHERE id=$1 AND user_id=$2 AND status='delivered'`,
    [req.params.id, req.user.id]);
  if (!o) return res.status(400).json({ error: 'الإرجاع متاح لطلبات مسلّمة فقط' });
  const dup = await one('SELECT id FROM refund_requests WHERE order_id=$1 AND status=$2', [o.id, 'pending']);
  if (dup) return res.status(400).json({ error: 'طلب الإرجاع انرسل مسبقاً — بانتظار التاجر' });
  const del = await one(`SELECT created_at FROM order_status_history WHERE order_id=$1 AND to_status='delivered' ORDER BY id DESC LIMIT 1`, [o.id]);
  const baseAt = new Date(del?.created_at ?? o.updated_at).getTime();
  const within = Date.now() - baseAt <= (o.warranty_days ?? 3) * 86400000;
  if (!within) return res.status(400).json({ error: `انقضت مدة الضمان (${o.warranty_days ?? 3} أيام من الاستلام)` });
  // استبدال: البديل يجب أن يكون تركيبة بالطلب نفسه ومخزونها متوفر
  let label = desired;
  if (type === 'exchange') {
    if (!variant_id) return res.status(400).json({ error: 'اختر المقاس/اللون البديل' });
    const v = await one(`SELECT v.*, oi.name AS item_name FROM product_variants v
      JOIN order_items oi ON oi.product_id=v.product_id AND oi.order_id=$1
      WHERE v.id=$2`, [o.id, variant_id]);
    if (!v) return res.status(400).json({ error: 'البديل مو من منتجات هذا الطلب' });
    if ((v.stock ?? 0) <= 0) return res.status(400).json({ error: `البديل «${(v.color ? v.color + ' · ' : '') + v.name}» نفد — اختبر غيره` });
    label = v.color ? `${v.color} · ${v.name}` : v.name;
  }
  const rf = (await q(`INSERT INTO refund_requests (order_id, reason, details, type, desired) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [o.id, reason, details, type, label]))[0];
  const vendorOwner = o.store_id ? (await one('SELECT owner_id FROM stores WHERE id=$1', [o.store_id])).owner_id : null;
  await q(`INSERT INTO notifications (user_id, type, title, body, data) VALUES ($1,'refund',$2,$3, jsonb_build_object('order_id',$4::int, 'refund_id',$5::int))`,
    [vendorOwner, type === 'exchange' ? 'طلب استبدال جديد 🔁' : 'طلب إرجاع جديد ⤴',
      type === 'exchange' ? `يريد استبدال بـ «${label}»${reason ? ` — ${reason}` : ''}` : reason, o.id, rf.id]);
  res.status(201).json({ refund: rf });
});

// ═══════════ تقدير سعر التوصيل قبل الطلب ═══════════
// يستخدمه التطبيق لعرض سعر التوصيل للزبون بدقة في صفحة السلة
// المعاملات: store_ids (قائمة بأرقام المحلات) + lat/lng (موقع الزبون) اختياري
r.get('/delivery-estimate', async (req, res) => {
  const { store_ids, lat, lng, address_id } = req.query;
  const ids = (store_ids || '').split(',').map(Number).filter(Boolean);
  if (!ids.length) return res.status(400).json({ error: 'أرسل store_ids' });

  const stores = await q(
    `SELECT id, lat, lng FROM stores WHERE id = ANY($1)`,
    [ids]
  );

  // موقع الزبون — من address_id أو من lat/lng مباشرة
  let userPoint = null;
  if (address_id) {
    const a = await one(`SELECT lat, lng FROM addresses WHERE id=$1 AND user_id=$2`, [address_id, req.user.id]);
    if (a?.lat && a?.lng) userPoint = { lat: +a.lat, lng: +a.lng };
  } else if (lat && lng) {
    userPoint = { lat: +lat, lng: +lng };
  }

  // إحداثيات المحلات بترتيب الـ ids
  const shopPoints = stores
    .filter(s => s.lat && s.lng)
    .map(s => ({ lat: +s.lat, lng: +s.lng }));

  // إذا ما عندنا إحداثيات كافية نرجع الحد الأدنى
  if (!shopPoints.length || !userPoint) {
    return res.json({ fee: 1500, fallback: true, note: 'لا تتوفر إحداثيات كافية' });
  }

  const { total_price, breakdown } = calculateDeliveryPrice(shopPoints, userPoint);
  res.json({ fee: total_price, breakdown });
});

// ═══════════ نقاط الولاء ═══════════
r.get('/points', async (req, res) => {
  const txns = await q(`SELECT * FROM point_transactions WHERE user_id=$1 ORDER BY id DESC LIMIT 50`, [req.user.id]);
  const rate = await one(`SELECT value FROM settings WHERE key='point_rate'`);
  res.json({ balance: req.user.points || 0, rate: parseInt(rate?.value || '100'), transactions: txns });
});

// ═══════════ دعوة الأصدقاء ═══════════
r.get('/referral', async (req, res) => {
  res.json({ code: req.user.referral_code, points_referrer: 100, points_new: 50 });
});

// ═══════════ الكوبونات ═══════════
r.get('/coupons', async (req, res) => {
  const rows = await q(`SELECT id, code, store_id, percent, flat, min_total, max_discount, expires_at
    FROM coupons WHERE active=true AND (expires_at IS NULL OR expires_at > now())
    ORDER BY id DESC LIMIT 20`);
  res.json({ coupons: rows });
});

// ── تفعيل الكوبون عند تفك الكاش ──
r.post('/cart/apply-coupon', async (req, res) => {
  const { store_id, code, subtotal } = req.body;
  const coupon = await one(`SELECT * FROM coupons WHERE code=$1 AND active=true AND (expires_at IS NULL OR expires_at > now())`, [String(code || '').trim().toUpperCase()]);
  if (!coupon) return res.status(400).json({ error: 'الكوبون غير صالح' });
  if (coupon.min_total > subtotal) return res.status(400).json({ error: `الحد الأدنى ${coupon.min_total.toLocaleString()} د.ع` });
  if (coupon.store_id && coupon.store_id !== (parseInt(store_id) || 0)) return res.status(400).json({ error: 'كوبون لمحل آخر' });
  let d = coupon.percent ? Math.round(subtotal * coupon.percent / 100) : coupon.flat;
  if (coupon.max_discount && d > coupon.max_discount) d = coupon.max_discount;
  res.json({ ok: true, code: coupon.code, discount: d, percent: coupon.percent });
});

// ═══════════ المحادثات: فقط مع المندوب أثناء التوصيل ═══════════
const activeDelivery = (userId, courierId) => one(
  `SELECT o.id FROM orders o WHERE o.user_id=$1 AND o.courier_id=$2 AND o.status='delivering' LIMIT 1`,
  [userId, courierId]);

r.get('/conversations', async (req, res) => {
  const rows = await q(`SELECT cv.*, u.name AS courier_name, u.phone AS courier_phone,
      (SELECT body FROM messages m WHERE m.conversation_id=cv.id ORDER BY m.id DESC LIMIT 1) AS last_message,
      EXISTS(SELECT 1 FROM messages m WHERE m.conversation_id=cv.id AND m.sender_role='courier' AND m.read_at IS NULL) AS has_unread
    FROM conversations cv JOIN users u ON u.id=cv.courier_id
    WHERE cv.user_id=$1 AND EXISTS(SELECT 1 FROM orders o WHERE o.user_id=cv.user_id AND o.courier_id=cv.courier_id AND o.status='delivering')
    ORDER BY cv.last_message_at DESC`, [req.user.id]);
  res.json({ conversations: rows });
});

// ── فتح محادثة مع المندوب (فقط أثناء توصيلة حية له طلباتي) ──
r.post('/conversations', async (req, res) => {
  const courier_id = parseInt(req.body.courier_id) || 0;
  if (!(await activeDelivery(req.user.id, courier_id))) return res.status(403).json({ error: 'ماكو توصيلة حية مع هذا المندوب' });
  let cv = await one(`SELECT * FROM conversations WHERE user_id=$1 AND courier_id=$2`, [req.user.id, courier_id]);
  if (!cv) cv = (await q(`INSERT INTO conversations (user_id, courier_id) VALUES ($1,$2) RETURNING *`, [req.user.id, courier_id]))[0];
  res.json({ conversation: cv });
});

// ═══════════ متابعة المتاجر ═══════════
r.get('/store-favorites', async (req, res) => {
  const rows = await q(`SELECT sf.*, s.name AS store_name, s.logo AS store_logo, s.rating_avg AS rating, s.rating_count AS reviews_count
    FROM store_favorites sf JOIN stores s ON s.id=sf.store_id WHERE sf.user_id=$1 ORDER BY sf.id DESC`, [req.user.id]);
  res.json({ favorites: rows });
});

r.post('/store-favorites', async (req, res) => {
  const { store_id } = req.body;
  const exists = await one(`SELECT id FROM store_favorites WHERE user_id=$1 AND store_id=$2`, [req.user.id, store_id]);
  if (exists) {
    await q(`DELETE FROM store_favorites WHERE id=$1`, [exists.id]);
    return res.json({ favorite: false });
  }
  await q(`INSERT INTO store_favorites (user_id, store_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [req.user.id, store_id]);
  res.json({ favorite: true });
});

r.get('/conversations/:id/messages', async (req, res) => {
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  if (!(await activeDelivery(req.user.id, cv.courier_id))) return res.status(403).json({ error: 'انتهت رحلة التوصيل — المحادثة مغلقة' });
  const msgs = await q(`SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id=m.sender_id
    WHERE m.conversation_id=$1 ORDER BY m.id`, [cv.id]);
  await q(`UPDATE messages SET read_at=now() WHERE conversation_id=$1 AND sender_id!=$2 AND read_at IS NULL`, [cv.id, req.user.id]);
  res.json({ conversation: cv, messages: msgs });
});

r.post('/conversations/:id/messages', async (req, res) => {
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  if (!(await activeDelivery(req.user.id, cv.courier_id))) return res.status(403).json({ error: 'انتهت رحلة التوصيل — المحادثة مغلقة' });
  const body = String(req.body.body || '').slice(0, 1000);
  const m = (await q(`INSERT INTO messages (conversation_id, sender_id, sender_role, body) VALUES ($1,$2,'customer',$3) RETURNING *`, [cv.id, req.user.id, body]))[0];
  await q(`UPDATE conversations SET last_message_at=now() WHERE id=$1`, [cv.id]);
  const courier = await one('SELECT u.name FROM users u WHERE u.id=$1', [cv.courier_id]);
  if (courier) await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'chat','رسالة من الزبون 💬',$2)`, [cv.courier_id, body.slice(0, 60)]);
  res.status(201).json({ message: m });
});

// ═══════════ الأسئلة على المنتجات (Q&A) ═══════════
r.post('/products/:id/question', async (req, res) => {
  const p = await one('SELECT * FROM products WHERE id=$1', [req.params.id]);
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  const qrow = (await q(`INSERT INTO product_questions (product_id, store_id, user_id, question) VALUES ($1,$2,$3,$4) RETURNING *`,
    [p.id, p.store_id, req.user.id, String(req.body.question || '').slice(0, 500)]))[0];
  res.status(201).json({ question: qrow });
});

// ═══════════ عجلة الحظ ═══════════
r.get('/spin/status', async (req, res) => {
  const today = await one(`SELECT * FROM spin_wins WHERE user_id=$1 AND day=CURRENT_DATE`, [req.user.id]);
  res.json({ used_today: !!today, points_won_today: today?.points || 0 });
});

r.post('/spin', async (req, res) => {
  const done = await one(`SELECT * FROM spin_wins WHERE user_id=$1 AND day=CURRENT_DATE`, [req.user.id]);
  if (done) return res.status(400).json({ error: 'درت الدور اليوم — ارجع بكرة 🎡' });
  const choices = [0, 20, 20, 30, 30, 50, 50, 100, 100, 200];
  const points = choices[Math.floor(Math.random() * choices.length)];
  await tx(async (c) => {
    await c.query(`INSERT INTO spin_wins (user_id, points) VALUES ($1,$2)`, [req.user.id, points]);
    if (points > 0) {
      await c.query(`UPDATE users SET points = points + $1 WHERE id=$2`, [points, req.user.id]);
      await c.query(`INSERT INTO point_transactions (user_id, points, type, note) VALUES ($1,$2,'bonus','مكسب عجلة الحظ 🎡')`, [req.user.id, points]);
    }
  });
  res.json({ ok: true, points });
});

// ═══════════ المفضلة ═══════════
r.get('/favorites', async (req, res) => {
  const rows = await q(`SELECT p.*, s.name AS store_name, s.logo AS store_logo
    FROM favorites f JOIN products p ON p.id=f.product_id JOIN stores s ON s.id=p.store_id
    WHERE f.user_id=$1 ORDER BY f.id DESC`, [req.user.id]);
  res.json({ products: rows });
});
r.post('/favorites', async (req, res) => {
  const ex = await one(`SELECT id FROM favorites WHERE user_id=$1 AND product_id=$2`, [req.user.id, req.body.product_id]);
  if (ex) {
    await q(`DELETE FROM favorites WHERE id=$1`, [ex.id]);
    return res.json({ favorite: false });
  }
  await q(`INSERT INTO favorites (user_id, product_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [req.user.id, req.body.product_id]);
  res.json({ favorite: true });
});
r.delete('/favorites/:product_id', async (req, res) => {
  await q('DELETE FROM favorites WHERE user_id=$1 AND product_id=$2', [req.user.id, req.params.product_id]);
  res.json({ ok: true });
});

// ═══════════ الإشعارات ═══════════
r.get('/notifications/count', async (req, res) => {
  const row = await one(`SELECT
      (SELECT count(*)::int FROM notifications WHERE (user_id=$1 OR (role=$2 AND user_id IS NULL)) AND read_at IS NULL) AS count,
      (SELECT to_json(t) FROM (
         SELECT id, title, body, type, created_at FROM notifications
         WHERE (user_id=$1 OR (role=$2 AND user_id IS NULL)) AND read_at IS NULL
         ORDER BY id DESC LIMIT 1
       ) t) AS latest`,
    [req.user.id, req.user.role]);
  res.json({ count: row?.count ?? 0, latest: row?.latest ?? null });
});
r.get('/notifications', async (req, res) => {
  const rows = await q(`SELECT *, (read_at IS NOT NULL) AS read FROM notifications WHERE user_id=$1 OR (role=$2 AND user_id IS NULL) ORDER BY id DESC LIMIT 50`,
    [req.user.id, req.user.role]);
  res.json({ notifications: rows });
});
r.post('/notifications/read', async (req, res) => {
  await q(`UPDATE notifications SET read_at=now() WHERE read_at IS NULL AND (user_id=$1 OR (user_id IS NULL AND role=$2))`,
    [req.user.id, req.user.role]);
  res.json({ ok: true });
});
r.post('/notifications/:id/read', async (req, res) => {
  await q(`UPDATE notifications SET read_at=now() WHERE id=$1 AND (user_id=$2 OR (user_id IS NULL AND role=$3))`,
    [req.params.id, req.user.id, req.user.role]);
  res.json({ ok: true });
});
r.delete('/notifications/:id', async (req, res) => {
  await q(`DELETE FROM notifications WHERE id=$1 AND user_id=$2`, [req.params.id, req.user.id]);
  res.json({ ok: true });
});

// ═══════════ الدعم الفني الذكي (AI) ═══════════
r.post('/support/chat', async (req, res) => {
  const { message } = req.body;
  
  // Here we can integrate with Google Gemini or OpenAI API later.
  // For now, return a generic AI response mimicking a helpful assistant.
  const lowerMsg = String(message || '').toLowerCase();
  let reply = 'فهمت سؤالك، حالياً آني مساعد ذكي تحت التجربة. تكدر تسألني عن طلباتك أو كيفية استخدام المنصة!';
  
  if (lowerMsg.includes('طلب') || lowerMsg.includes('وين')) {
    reply = 'تكدر تتابع حالة طلبك من قسم "طلباتي" بحسابك، واذا الطلب ويه المندوب تكدر تتبع موقعه عالخريطة.';
  } else if (lowerMsg.includes('نقط') || lowerMsg.includes('نقاط')) {
    reply = 'نظام النقاط يخليك تجمع نقاط من كل طلب (1 نقطة لكل 1000 دينار)، وتكدر تحول كل 100 نقطة إلى خصم 1000 دينار من سلتك الجاية!';
  } else if (lowerMsg.includes('شكرا') || lowerMsg.includes('ممنون')) {
    reply = 'تدلل حبيبي، بأي وقت اني موجود لخدمتك!';
  } else if (lowerMsg.includes('مرحبا') || lowerMsg.includes('هلا')) {
    reply = 'أهلاً بيك يا غالي! شلون أكدر أساعدك اليوم؟';
  }

  // Simulate network delay for realistic AI feeling
  await new Promise(resolve => setTimeout(resolve, 800));

  res.json({ reply });
});

export default r;
