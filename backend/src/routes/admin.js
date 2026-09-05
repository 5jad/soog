import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { q, one, tx } from '../db.js';
import { auth, roles } from '../middleware.js';
import { demoStats, setDemoMode, isHidden, demoCond } from '../demo.js';

const r = Router();
r.use(auth, roles('admin'));

const audit = async (adminId, action, entity, entityId, oldData = null, newData = null) =>
  q(`INSERT INTO audit_logs (admin_id, action, entity, entity_id, old_data, new_data) VALUES ($1,$2,$3,$4,$5,$6)`,
    [adminId, action, entity, entityId, oldData ? JSON.stringify(oldData) : null, newData ? JSON.stringify(newData) : null]);

// ═══════════ لوحة الأرقام الرئيسية ═══════════
r.get('/stats', async (req, res) => {
  const dOrder = await demoCond('orders');
  const dStore = await demoCond('stores');
  const dUser = await demoCond('users');
  const dAds = await demoCond('ads');
  const dDocs = await demoCond('docs');
  const dCash = await demoCond('cash');
  const wOrder = dOrder ? `WHERE ${dOrder}` : '';
  const today = await one(`SELECT
      count(*) FILTER (WHERE created_at::date=CURRENT_DATE AND status NOT IN ('cancelled'))::int AS orders_today,
      count(*) FILTER (WHERE created_at::date=CURRENT_DATE AND status='new')::int AS new_orders,
      COALESCE(sum(total) FILTER (WHERE created_at::date=CURRENT_DATE AND status NOT IN ('cancelled')),0)::int AS sales_today,
      COALESCE(sum(total) FILTER (WHERE created_at::date=CURRENT_DATE),0)::int AS gross_today,
      COALESCE(sum(total) FILTER (WHERE created_at::date=CURRENT_DATE AND status NOT IN ('cancelled')),0)::numeric * 0.1::numeric AS commission_today
    FROM orders o ${wOrder}`);
  const counts = await one(`SELECT
      count(*)::int AS active_stores FROM stores s WHERE status='approved' ${dStore ? `AND ${dStore}` : ''}`);
  const users = await one(`SELECT
      count(*) FILTER (WHERE role='customer' AND created_at::date=CURRENT_DATE)::int AS new_customers,
      count(*) FILTER (WHERE role='customer')::int AS total_customers FROM users u ${dUser ? `WHERE ${dUser}` : ''}`);
  const couriers = await one(`SELECT count(*)::int AS n FROM users u WHERE role='delivery' ${dUser ? `AND ${dUser}` : ''}`);
  const pendingQueue = await one(`SELECT
      (SELECT count(*) FROM ad_requests a WHERE status='pending' ${dAds ? `AND ${dAds.replaceAll('o.','a.')}` : ''})::int AS ads,
      (SELECT count(*) FROM store_documents d WHERE status='pending' ${dDocs ? `AND ${dDocs.replaceAll('o.','d.')}` : ''})::int AS docs,
      (SELECT count(*) FROM cash_reports cr WHERE status='pending' ${dCash ? `AND ${dCash.replaceAll('o.','cr.')}` : ''})::int AS cash`);
  const orders = await q(`SELECT o.*, s.name AS store_name, u.name AS user_name, c.name AS courier_name
    FROM orders o JOIN stores s ON s.id=o.store_id LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users c ON c.id=o.courier_id
    ${dOrder ? `WHERE ${dOrder}` : ''} ORDER BY o.id DESC LIMIT 8`);
  res.json({ stats: { ...today, ...counts, ...users, ...couriers, queue: pendingQueue }, recent: orders, recent_orders: orders });
});

// ── المبيعات: آخر 7 أيام ──
r.get('/sales', async (req, res) => {
  const dOrder = await demoCond('orders');
  const dStore = await demoCond('stores');
  const wOrder = dOrder ? `WHERE ${dOrder.replaceAll('o.','')}` : '';
  const rows = await q(`SELECT to_char(created_at,'YYYY-MM-DD') AS d, COALESCE(sum(total),0)::int AS total
    FROM orders o ${dOrder ? `WHERE ${dOrder} AND o.created_at >= now() - interval '7 days' AND o.status NOT IN ('cancelled')` : `WHERE created_at >= now() - interval '7 days' AND status NOT IN ('cancelled')`} 
    GROUP BY d ORDER BY d`);
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(Date.now() - i * 864e5).toISOString().slice(0, 10);
    const found = rows.find(x => x.d === d);
    days.push({ date: d, total: found ? found.total : 0 });
  }
  const cats = await q(`SELECT c.name, c.icon, COALESCE(sum(oi.price*oi.qty),0)::int AS total
    FROM order_items oi JOIN products p ON p.id=oi.product_id JOIN categories c ON c.id=p.category_id
    JOIN orders o ON o.id=oi.order_id WHERE o.created_at::date=CURRENT_DATE AND o.status NOT IN ('cancelled')
      ${dOrder ? `AND ${dOrder}` : ''}
    GROUP BY c.id ORDER BY total DESC`);
  const tops = await q(`SELECT s.id, s.name, s.logo, COALESCE(sum(o.total),0)::int AS sales, s.commission_rate
    FROM stores s LEFT JOIN orders o ON o.store_id=s.id AND o.created_at::date=CURRENT_DATE AND o.status NOT IN ('cancelled')
      ${dOrder ? `AND ${dOrder}` : ''}
    ${dStore ? `WHERE ${dStore} AND s.status='approved'` : `WHERE s.status='approved'`}
    GROUP BY s.id ORDER BY sales DESC LIMIT 5`);
  res.json({ days, categories: cats, top_stores: tops });
});

// ═══════════ الطلبات (متابعة عامة) ═══════════
r.get('/orders', async (req, res) => {
  const { status } = req.query;
  const w = [];
  const p = [];
  if (status && status !== 'all') { p.push(status); w.push(`o.status=$${p.length}`); }
  const dOrder = await demoCond('orders');
  if (dOrder) w.push(dOrder);
  const orders = await q(`SELECT o.*, s.name AS store_name, s.logo AS store_logo, u.name AS user_name, u.phone AS user_phone, c.name AS courier_name
    FROM orders o JOIN stores s ON s.id=o.store_id LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users c ON c.id=o.courier_id
    WHERE ${w.join(' AND ') || 'true'} ORDER BY o.id DESC LIMIT 100`, p);
  res.json({ orders });
});

r.get('/orders/:id', async (req, res) => {
  const o = await one(`SELECT o.*, s.name AS store_name, s.logo AS store_logo,
      u.name AS user_name, u.phone AS user_phone, c.name AS courier_name, c.phone AS courier_phone
    FROM orders o JOIN stores s ON s.id=o.store_id LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users c ON c.id=o.courier_id
    WHERE o.id=$1`, [req.params.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  o.items = await q('SELECT * FROM order_items WHERE order_id=$1', [o.id]);
  o.history = await q('SELECT * FROM order_status_history WHERE order_id=$1 ORDER BY id', [o.id]);
  res.json({ order: o });
});

r.patch('/orders/:id', async (req, res) => {
  const o = await one('SELECT * FROM orders WHERE id=$1', [req.params.id]);
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  const { status, note = '' } = req.body;
  const valid = ['new', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled', 'returned'];
  if (!valid.includes(status)) return res.status(400).json({ error: 'حالة غير صحيحة' });
  const old = { status: o.status };
  await tx(async (c) => {
    await c.query(`UPDATE orders SET status=$1, updated_at=now() WHERE id=$2`, [status, o.id]);
    await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role, note) VALUES ($1,$2,$3,'admin',$4)`, [o.id, o.status, status, note]);
  });
  await audit(req.user.id, 'order_status', 'order', o.id, old, { status, note });
  res.json({ ok: true });
});

// ═══════════ المتاجر ═══════════
r.get('/stores', async (req, res) => {
  const { status } = req.query;
  const w = [];
  const p = [];
  if (status && status !== 'all') { p.push(status); w.push(`s.status=$${p.length}`); }
  const dStore = await demoCond('stores');
  if (dStore) w.push(dStore);
  const stores = await q(`SELECT s.*, u.name AS owner_name, u.phone AS owner_phone, c.name AS category_name
    FROM stores s LEFT JOIN users u ON u.id=s.owner_id LEFT JOIN categories c ON c.id=s.category_id
    ${w.length ? `WHERE ${w.join(' AND ')}` : ''} ORDER BY s.id DESC`, p);
  const dDocs = await demoCond('docs', { o: 'd' });
  const docs = await q(`SELECT d.*, s.name AS store_name FROM store_documents d JOIN stores s ON s.id=d.store_id WHERE d.status='pending' ${dDocs ? `AND ${dDocs}` : ''} ORDER BY d.id`);
  res.json({ stores, pending_documents: docs });
});

r.post('/stores', async (req, res) => {
  const b = req.body;
  if (!b.name || !b.owner_id) return res.status(400).json({ error: 'اسم المحل والمالك مطلوبان' });
  const owner = await one('SELECT id FROM users WHERE id=$1', [b.owner_id]);
  if (!owner) return res.status(404).json({ error: 'المالك غير موجود' });
  const gov = await one('SELECT id FROM governorates WHERE is_active ORDER BY id LIMIT 1');
  const s = (await q(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, description, address, lat, lng, location_url, phone, delivery_fee, free_delivery_min, open_time, close_time, status, verified)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,'approved',true) RETURNING *`,
    [b.owner_id, b.governorate_id || gov.id, b.district_id || null, b.name, b.category_id || null, b.logo || '🏪',
    b.description || '', b.address || '', b.lat || null, b.lng || null, b.location_url || '', b.phone || '', b.delivery_fee || 2000, b.free_delivery_min || 50000,
    b.open_time || '9ص', b.close_time || '11ل']))[0];
  await q(`INSERT INTO wallets (store_id) VALUES ($1)`, [s.id]);
  await audit(req.user.id, 'store_create', 'store', s.id, null, s);
  res.status(201).json({ store: s });
});

r.patch('/stores/:id', async (req, res) => {
  const s = await one('SELECT * FROM stores WHERE id=$1', [req.params.id]);
  if (!s) return res.status(404).json({ error: 'المحل غير موجود' });
  const b = req.body;
  const allowed = ['status', 'verified', 'commission_rate', 'delivery_fee', 'is_open', 'name', 'phone', 'address', 'category_id', 'lat', 'lng', 'location_url'];
  const sets = [], p = [];
  for (const k of allowed) if (b[k] !== undefined) { p.push(b[k]); sets.push(`${k}=$${p.length}`); }
  if (!sets.length) return res.json({ store: s });
  const ns = (await q(`UPDATE stores SET ${sets.join(', ')} WHERE id=$${p.length + 1} RETURNING *`, [...p, s.id]))[0];
  await audit(req.user.id, 'store_update', 'store', s.id, s, ns);
  if (b.status === 'approved')
    await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'store','محلك انوافق عليه 🎉',$2)`, [ns.owner_id, `${ns.name} صار رسميًا على المنصة`]);
  if (b.status === 'rejected')
    await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'store','محلك مرفوض ✗','راجع سبب الرفض من الإشعارات')`, [ns.owner_id]);
  res.json({ store: ns });
});

// ═══════════ البيانات الوهمية (5 لكل شيء — تحكم كامل) ═══════════

// علامة التمييز: المتاجر تبدأ بـ [وهمي]، والمستخدمون بأرقام 000000000xxx
const DUMMY_MARKER = 'وهمي';

async function resetDummyTx(c) {
  const stores = (await c.query(`SELECT id FROM stores WHERE name LIKE '%' || $1::text || '%'`, ['[' + DUMMY_MARKER + '] %'])).rows.map(x => x.id);
  const users = (await c.query(`SELECT id FROM users WHERE phone LIKE '000000000%'`)).rows.map(x => x.id);
  if (!stores.length && !users.length) return { stores: 0, users: 0, orders: 0 };
  const S = stores.length ? stores : [0];
  const U = users.length ? users : [0];
  await c.query(`DELETE FROM orders WHERE store_id=ANY($1::int[]) OR user_id=ANY($2::int[]) OR courier_id=ANY($2::int[])`, [S, U]);
  await c.query(`DELETE FROM reviews WHERE store_id=ANY($1::int[]) OR user_id=ANY($2::int[])`, [S, U]);
  await c.query(`DELETE FROM favorites WHERE user_id=ANY($1::int[])`, [U]);
  await c.query(`DELETE FROM cart_items WHERE user_id=ANY($1::int[])`, [U]);
  await c.query(`DELETE FROM addresses WHERE user_id=ANY($1::int[])`, [U]);
  await c.query(`DELETE FROM cash_reports WHERE courier_id=ANY($1::int[])`, [U]);
  await c.query(`DELETE FROM notifications WHERE user_id=ANY($1::int[]) OR (role='admin' AND title LIKE '%' || $2::text || '%')`, [U, DUMMY_MARKER]);
  await c.query(`DELETE FROM products WHERE store_id=ANY($1::int[])`, [S]);
  await c.query(`DELETE FROM wallets WHERE store_id=ANY($1::int[])`, [S]);
  await c.query(`DELETE FROM stores WHERE id=ANY($1::int[])`, [S]);
  await c.query(`DELETE FROM users WHERE id=ANY($1::int[])`, [U]);
  return { stores: stores.length, users: users.length };
}

// ═══════════ البيانات الوهمية (إخفاء/إظهار بلا مسح) ═══════════
const checkNotProd = (req, res, next) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ error: 'غير مسموح في بيئة الإنتاج' });
  }
  next();
};

r.get('/dummy', checkNotProd, async (req, res) => {
  res.json({ mode: (await isHidden()) ? 'hidden' : 'shown', stats: await demoStats() });
});

// إظهار: إن كانت البيانات موجودة يظهرها فقط، وإلا يولّدها ويظهرها
r.post('/dummy', checkNotProd, async (req, res) => {
  const stats = await demoStats();
  if (stats.stores > 0 && stats.products > 0) {
    await setDemoMode('shown');
    return res.json({ ok: true, mode: 'shown', stats });
  }
  try {
    const counts = await tx(async (c) => {
      await resetDummyTx(c);

      const gov = (await c.query('SELECT id FROM governorates LIMIT 1')).rows[0];
      if (!gov) throw new Error('لا توجد محافظة');
      const districts = (await c.query('SELECT id FROM districts ORDER BY id')).rows;
      const cats = (await c.query('SELECT id, name FROM categories ORDER BY id')).rows;
      const admin = (await c.query(`SELECT id FROM users WHERE role='admin' LIMIT 1`)).rows[0];
      if (!districts.length || !cats.length) throw new Error('ناقص أحياء أو أقسام — شغّل db:seed أول');
      const di = (i) => districts[i % districts.length].id;
      const catId = (n) => (cats.find(x => x.name === n) || cats[0]).id;
      const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
      const now = new Date();
      const pass = await bcrypt.hash('123456', 10);

      // ── 5 تجار + 5 متاجر ──
      const vendorData = [
        { n: 'أبو ياسر — مطاعم', p: '000000000100', s: 'مطبخ أبو ياسر — كباب', l: '🍢', c: 'مطاعم وأكل', ds: 'كباب ومسكوف على الفحم، أكل بيتي طازج كل يوم' },
        { n: 'أم علي — موضة', p: '000000000101', s: 'بوتيك الأزهار', l: '👗', c: 'ملابس نسائي', ds: 'أحدث صيحات الموضة النسائية وأجمل الفساتين' },
        { n: 'حيدر كاظم', p: '000000000102', s: 'صيدلية الشفاء', l: '💊', c: 'صيدليات', ds: 'أدوية ومستحضرات تجميل أصلية بإشراف صيدلاني' },
        { n: 'أبو كرار', p: '000000000103', s: 'إلكترونيات النور', l: '📱', c: 'إلكترونيات', ds: 'هواتف وأجهزة كهربائية أصلية مع ضمان' },
        { n: 'زينب علي', p: '000000000104', s: 'سبورت زون', l: '👟', c: 'أحذية', ds: 'أحذية رياضية أصلية لكل الفئات العمرية' },
      ];
      const stores = [];
      for (const [i, v] of vendorData.entries()) {
        const u = (await c.query(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,'vendor',true,$3) RETURNING id`, [v.p, v.n, pass])).rows[0];
        const lat = 32.46 + (i * 0.015);
        const lng = 45.8 + (i * 0.014);
        const s = (await c.query(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, description, address, lat, lng, location_url, phone, delivery_fee, free_delivery_min, commission_rate, status, verified, is_open, rating_avg, rating_count)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,'approved',true,true,$16,$17) RETURNING id`,
          [u.id, gov.id, di(i), `[وهمي] ${v.s}`, catId(v.c), v.l, v.ds, `[وهمي] ${v.s} — الكوت`, lat, lng, `https://www.google.com/maps/search/?api=1&query=${lat.toFixed(6)},${lng.toFixed(6)}`, v.p, 2000, 50000, 10, 4 + Math.round(Math.random() * 8) / 10, 15 + i * 6])).rows[0];
        await c.query(`INSERT INTO wallets (store_id, available, pending) VALUES ($1,$2,$3)`, [s.id, rnd(300000, 2000000), rnd(40000, 250000)]);
        stores.push(s.id);
      }

      // ── 5 زبائن مسجلين ──
      const customerData = [
        { n: 'حسن الجبوري', p: '000000000200' },
        { n: 'نور كريم', p: '000000000201' },
        { n: 'علي هادي', p: '000000000202' },
        { n: 'فاطمة عبد الأمير', p: '000000000203' },
        { n: 'مصطفى حامد', p: '000000000204' },
      ];
      const customers = [];
      for (const v of customerData)
        customers.push((await c.query(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,'customer',true,$3) RETURNING id`, [v.p, v.n, pass])).rows[0].id);

      // ── 5 زبائن ضيوف (بلا حساب / غير مفعلين) ──
      const guests = [];
      for (let i = 0; i < 5; i++)
        guests.push((await c.query(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,'customer',false) RETURNING id`, [`00000000020${5 + i}`, `ضيف — زائر ${i + 1}`])).rows[0].id);

      // ── 5 مناديب ──
      const courierNames = ['حسين', 'علي', 'كرار', 'سجاد', 'حمزة'];
      const couriers = [];
      for (const [i, n] of courierNames.entries())
        couriers.push((await c.query(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,'delivery',true,$3) RETURNING id`, [`00000000030${i}`, `مندوب — ${n}`, pass])).rows[0].id);

      // ── 5 منتجات لكل محل (25 منتج) ──
      const prodNames = ['قميص قطني', 'جاكيت شتوي', 'حقيبة جلد', 'عطر فاخر', 'ساعة يد'];
      const products = [];
      for (const sid of stores) {
        const st = (await c.query('SELECT category_id FROM stores WHERE id=$1', [sid])).rows[0];
        for (let j = 0; j < 5; j++) {
          const price = rnd(8, 80) * 1000;
          const p = (await c.query(`INSERT INTO products (store_id, category_id, name, description, price, old_price, image, is_available, stock)
            VALUES ($1,$2,$3,$4,$5,$6,'📦',true,$7) RETURNING id`,
            [sid, st.category_id, `[وهمي] ${prodNames[j]}`, 'منتج تجريبي للعرض والشرح', price, j % 2 ? price + rnd(2, 6) * 1000 : null, rnd(5, 50)])).rows[0];
          products.push({ id: p.id, price });
          if (j === 2) await c.query(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,true)`, [p.id, 20 + (j % 3) * 10]);
        }
      }

      // ── 5 طلبات بحالات مختلفة ──
      const orderDefs = [
        { u: customers[0], s: stores[0], co: couriers[0], st: 'delivered', days: 3, items: 2 },
        { u: guests[0], s: stores[1], co: couriers[1], st: 'delivering', days: 1, items: 1 },
        { u: customers[1], s: stores[2], co: null, st: 'ready', days: 0, items: 2 },
        { u: customers[2], s: stores[3], co: null, st: 'preparing', days: 0, items: 1 },
        { u: guests[1], s: stores[4], co: null, st: 'new', days: 0, items: 2 },
      ];
      const orders = [];
      for (const [i, od] of orderDefs.entries()) {
        const bought = products.slice(i * 5, i * 5 + od.items);
        const subtotal = bought.reduce((a, p) => a + p.price, 0);
        const fee = subtotal >= 50000 ? 0 : 2000;
        const discount = subtotal >= 50000 ? 5000 : 0;
        const total = subtotal + fee - discount;
        const code = `ZB-D${Date.now()}${i}`;
        const o = (await c.query(`INSERT INTO orders (code, user_id, store_id, courier_id, status, subtotal, delivery_fee, discount, total, address_text, note, created_at)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'', now() - $11 * interval '1 day') RETURNING id`,
          [code, od.u, od.s, od.co, od.st, subtotal, fee, discount, total, `[وهمي] ${od.u === guests[1] ? 'حي النصر' : 'مركز الكوت'}، شارع الجمهورية`, od.days])).rows[0];
        for (const [j, p] of bought.entries())
          await c.query(`INSERT INTO order_items (order_id, product_id, name, variant, price, qty) VALUES ($1,$2,$3,'', $4, 1)`, [o.id, p.id, `[وهمي] صنف ${j + 1}`, p.price]);
        orders[od.st] = o.id;

        const chain = { new: ['new'], preparing: ['new', 'preparing'], ready: ['new', 'preparing', 'ready'], delivering: ['new', 'preparing', 'ready', 'delivering'], delivered: ['new', 'preparing', 'ready', 'delivering', 'delivered'] }[od.st];
        for (const [k, st] of chain.entries())
          await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role) VALUES ($1,$2,$3,$4)`, [o.id, k > 0 ? chain[k - 1] : null, st, k < chain.length - 1 ? 'vendor' : 'delivery']);
        if (od.st === 'delivering' || od.st === 'delivered') {
          const base = `now() - ${od.days} * interval '1 day'`;
          await c.query(`INSERT INTO delivery_trips (order_id, courier_id, accepted_at, picked_at, delivered_at)
            VALUES ($1,$2,${base},${base} + interval '1 hour',${od.st === 'delivered' ? base + " + interval '2 hours'" : 'NULL'})`, [o.id, od.co]);
        }
      }

      // ── 5 تقييمات ──
      const revUsers = [...customers, ...guests];
      for (let i = 0; i < 5; i++)
        await c.query(`INSERT INTO reviews (order_id, store_id, user_id, rating, comment) VALUES ($1,$2,$3,$4,$5)`,
          [i === 0 ? orders.delivered : null, stores[i], revUsers[i], 4 + (i % 2), ['خدمة ممتازة وسريعة', 'التوصيل وصل بوقته', 'تعامل راقي شكراً', 'جودة ممتازة', 'تجربة مرة حلوة'][i]]);

      // ── 5 إعلانات (2 نشطة + 3 قيد الموافقة) ──
      const adTitles = ['عرض اليوم 🔥 خصم 30%', 'تشكيلة جديدة وصلت ✨', 'تخفيضات نهاية الأسبوع 🏷', 'عروض الطلبات الكبيرة 🛍', 'ترويج — توصيل مجاني 🚚'];
      for (let i = 0; i < 5; i++) {
        const active = i < 2;
        await c.query(`INSERT INTO ad_requests (store_id, title, art, gradient, duration_days, price, status, sort, starts_at, ends_at)
          VALUES ($1,$2,$3,$4,7,25000,$5,$6,$7,$8)`,
          [stores[i], `[وهمي] ${adTitles[i]}`, ['🧥', '👗', '📱', '💊', '👟'][i], 'linear-gradient(120deg,#1E3A8A,#06B6D4)', active ? 'active' : 'pending', active ? i + 1 : 0, active ? now : null, active ? new Date(now.getTime() + 7 * 864e5) : null]);
      }

      // ── 5 تقارير كاش (3 قيد المراجعة + 2 متأكدة) ──
      for (let i = 0; i < 5; i++) {
        const total = rnd(150, 600) * 1000;
        const commission = Math.round(total * 0.05);
        const st = i < 3 ? 'pending' : 'approved';
        await c.query(`INSERT INTO cash_reports (courier_id, report_date, total_collected, commission_amount, net, status, approved_by, receipt_no)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [couriers[i], new Date(now.getTime() - i * 864e5), total, commission, total - commission, st, st === 'approved' && admin ? admin.id : null, st === 'approved' ? `RC-${1000 + i}` : null]);
      }

      // ── عمليات محفظة ──
      const wt = [['sale', 'مبيعات يومية'], ['commission', 'عمولة المنصة'], ['withdraw', 'استلام نقدي'], ['ad', 'دفع إعلان'], ['adjust', 'تسوية رصيد']];
      for (let i = 0; i < 5; i++)
        await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,$2,$3,$4)`, [stores[i], wt[i][0], rnd(100, 500) * 1000, `[وهمي] ${wt[i][1]}`]);

      // ── 5 عناوين للزبائن المسجلين ──
      for (const [i, cid] of customers.entries())
        await c.query(`INSERT INTO addresses (user_id, district_id, label, details, is_default) VALUES ($1,$2,$3,$4,true)`,
          [cid, di(i), ['البيت', 'العمل', 'بيت الأهل'][i % 3], `[وهمي] حي النصر، شارع ${i + 1}، دار ${10 + i}`]);

      // ── 5 مستندات توثيق ──
      const docs = [['license', 'رخصة العمل'], ['commercial', 'السجل التجاري'], ['electricity', 'فاتورة الكهرباء'], ['license', 'رخصة العمل'], ['license', 'رخصة العمل']];
      for (const [i, [type, title]] of docs.entries())
        await c.query(`INSERT INTO store_documents (store_id, type, title, status) VALUES ($1,$2,$3,$4)`, [stores[i], type, title, i < 3 ? 'pending' : 'approved']);

      // ── إشعارات ──
      const notifs = [
        [null, 'admin', 'طلب إعلان وهمي جديد', 'بانتظار موافقتك من لوحة التحكم'],
        [null, 'admin', 'مندوب وهمي سلّم الكاش', 'التقارير قيد المراجعة'],
        [customers[0], null, 'طلبك وصل للتوصيل 🚚', `الكود ${'ZB-D' + Date.now()}`],
        [couriers[0], null, 'مهمة توصيل جديدة', 'من محل وهمي قريب'],
        [guests[0], null, 'أكمل تسجيل حسابك 🎉', 'حتى تفعّل طلباتك وعنوانك'],
      ];
      for (const [uid, role, t, b] of notifs)
        await c.query(`INSERT INTO notifications (user_id, role, type, title, body) VALUES ($1,$2,'info',$3,$4)`, [uid, role, t, b]);

      // ── مفضلة ──
      for (let i = 0; i < 5; i++)
        await c.query(`INSERT INTO favorites (user_id, product_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [customers[i], products[i * 5].id]);

      return { vendors: 5, customers: 5, guests: 5, couriers: 5, stores: stores.length, products: products.length, orders: 5 };
    });
    await setDemoMode('shown');
    res.json({ ok: true, mode: 'shown', counts });
  } catch (err) {
    console.error('Dummy generation error:', err.message);
    res.status(500).json({ error: 'صار خطأ أثناء التوليد: ' + err.message });
  }
});

// إخفاء: بدون أي مسح — تبقى البيانات وتختفي من كل الاستعلامات
r.post('/dummy/hide', checkNotProd, async (req, res) => {
  await setDemoMode('hidden');
  res.json({ ok: true, mode: 'hidden', stats: await demoStats() });
});

// إظهار البيانات الموجودة فقط (بدون توليد)
r.post('/dummy/show', checkNotProd, async (req, res) => {
  await setDemoMode('shown');
  res.json({ ok: true, mode: 'shown', stats: await demoStats() });
});

// مسح نهائي (اختياري للأدمن)
r.delete('/dummy', checkNotProd, async (req, res) => {
  const removed = await tx((c) => resetDummyTx(c));
  await setDemoMode('shown');
  res.json({ ok: true, ...removed });
});

// ── المستندات ──
r.patch('/documents/:id', async (req, res) => {
  const d = await one('SELECT * FROM store_documents WHERE id=$1', [req.params.id]);
  if (!d) return res.status(404).json({ error: 'المستند غير موجود' });
  const { status, reason = '' } = req.body;
  await q(`UPDATE store_documents SET status=$1, reviewed_by=$2, reviewed_at=now(), reason=$3 WHERE id=$4`,
    [status, req.user.id, reason, d.id]);
  const s = await one('SELECT * FROM stores WHERE id=$1', [d.store_id]);
  if (status === 'approved') {
    // تم إلغاء تفعيل التوثيق التلقائي - المتجر يبقى غير موثق
    const _ = await one(`SELECT count(*)::int AS n FROM store_documents WHERE store_id=$1 AND status='approved'`, [d.store_id]);
  }
  await audit(req.user.id, 'document_' + status, 'store_document', d.id, d, { status, reason });
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'store',$2,$3)`, [s.owner_id, `مستند ${d.title}: ${status === 'approved' ? 'مقبول ✓' : 'مرفوض ✗'}`, reason || '']);
  res.json({ ok: true });
});

// ═══════════ الإعلانات ═══════════
r.get('/ads', async (req, res) => {
  const dAds = await demoCond('ads');
  res.json({
    ads: await q(`SELECT a.*, s.name AS store_name, p.name AS product_name FROM ad_requests a JOIN stores s ON s.id=a.store_id LEFT JOIN products p ON p.id=a.product_id ${dAds ? `WHERE ${dAds.replaceAll('o.','a.')}` : ''} ORDER BY a.status='pending' DESC, a.id`),
  });
});

r.patch('/ads/:id', async (req, res) => {
  const a = await one('SELECT * FROM ad_requests WHERE id=$1', [req.params.id]);
  if (!a) return res.status(404).json({ error: 'الإعلان غير موجود' });
  const { status, sort } = req.body;
  const old = { ...a };
  if (status) {
    if (status === 'active') {
      await q(`UPDATE ad_requests SET status='active', starts_at=now(), ends_at=now()+duration_days*interval '1 day', sort=COALESCE((SELECT max(sort) FROM ad_requests WHERE status='active'),0)+1 WHERE id=$1`, [a.id]);
      await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ad','إعلانك انقبل ✓','يعرض بالواجهة الرئيسية الآن')`, [a.store_id ? (await one('SELECT owner_id FROM stores WHERE id=$1', [a.store_id])).owner_id : null]);
    } else if (status === 'rejected') {
      // استرجاع الرصيد المحجوز + إبلاغ التاجر بالسبب
      await tx(async (c) => {
        await c.query(`UPDATE ad_requests SET status='rejected' WHERE id=$1`, [a.id]);
        await c.query(`UPDATE wallets SET available=available+$1, updated_at=now() WHERE store_id=$2`, [a.price, a.store_id]);
        await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'ad_refund',$2,$3)`, [a.store_id, a.price, `استرجاع إعلان مرفوض: ${a.title}`]);
      });
      const owner = await one('SELECT owner_id FROM stores WHERE id=$1', [a.store_id]);
      const reason = (req.body.reason || '').toString().trim();
      await q(`UPDATE ad_requests SET reject_reason=$1 WHERE id=$2`, [reason, a.id]);
      await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ad','إعلانك مرفوض ✗',$2)`, [owner?.owner_id, reason ? `السبب: ${reason}` : 'راجع السبب من لوحة المحل']);
    } else {
      await q(`UPDATE ad_requests SET status=$1 WHERE id=$2`, [status, a.id]);
    }
  }
  if (sort !== undefined) {
    await q(`UPDATE ad_requests SET sort=$1 WHERE id=$2`, [sort, a.id]);
    const act = await q(`SELECT id FROM ad_requests WHERE status='active' ORDER BY sort, id`);
    for (let i = 0; i < act.length; i++) await q(`UPDATE ad_requests SET sort=$1 WHERE id=$2`, [i + 1, act[i].id]);
  }
  await audit(req.user.id, 'ad_update', 'ad_request', a.id, old, { status, sort });
  res.json({ ok: true });
});

// ── قرار مباشر من تطبيق الأدمن (approve/reject) ──
r.post('/ads/:id/decision', async (req, res) => {
  const a = await one('SELECT * FROM ad_requests WHERE id=$1', [req.params.id]);
  if (!a) return res.status(404).json({ error: 'الإعلان غير موجود' });
  const { action, reason } = req.body;
  const status = action === 'approve' ? 'active' : 'rejected';
  if (status === 'active') {
    await q(`UPDATE ad_requests SET status='active', starts_at=now(), ends_at=now()+duration_days*interval '1 day' WHERE id=$1`, [a.id]);
    const owner = await one('SELECT owner_id FROM stores WHERE id=$1', [a.store_id]);
    await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ad','إعلانك انقبل ✓','يعرض بالواجهة الرئيسية الآن')`, [owner?.owner_id]);
  } else {
    await tx(async (c) => {
      await c.query(`UPDATE ad_requests SET status='rejected' WHERE id=$1`, [a.id]);
      await c.query(`UPDATE wallets SET available=available+$1, updated_at=now() WHERE store_id=$2`, [a.price, a.store_id]);
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'ad_refund',$2,$3)`, [a.store_id, a.price, `استرجاع إعلان مرفوض: ${a.title}`]);
    });
    const owner = await one('SELECT owner_id FROM stores WHERE id=$1', [a.store_id]);
    const why = (reason || '').toString().trim();
    await q(`UPDATE ad_requests SET reject_reason=$1 WHERE id=$2`, [why, a.id]);
    await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ad','إعلانك مرفوض ✗',$2)`, [owner?.owner_id, why ? `السبب: ${why}` : 'راجع السبب من لوحة المحل']);
  }
  await audit(req.user.id, 'ad_decision', 'ad_request', a.id, { status: a.status }, { status });
  res.json({ ok: true });
});

// ═══════════ باقات الإعلانات ═══════════
r.get('/ad-packages', async (req, res) => {
  res.json({ packages: await q('SELECT * FROM ad_packages ORDER BY days') });
});

r.post('/ad-packages', async (req, res) => {
  const { days, price, active = true } = req.body;
  const pkg = (await q(`INSERT INTO ad_packages (days, price, active) VALUES ($1,$2,$3) RETURNING *`, [days, price, active]))[0];
  res.status(201).json({ package: pkg });
});

r.patch('/ad-packages/:id', async (req, res) => {
  const { days, price, active } = req.body;
  const sets = [], p = [];
  if (days !== undefined) { p.push(days); sets.push(`days=$${p.length}`); }
  if (price !== undefined) { p.push(price); sets.push(`price=$${p.length}`); }
  if (active !== undefined) { p.push(active); sets.push(`active=$${p.length}`); }
  if (!sets.length) return res.json({ ok: true });
  const pkg = (await q(`UPDATE ad_packages SET ${sets.join(', ')} WHERE id=$${p.length + 1} RETURNING *`, [...p, req.params.id]))[0];
  res.json({ package: pkg });
});

r.delete('/ad-packages/:id', async (req, res) => {
  await q('DELETE FROM ad_packages WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
});

// ═══════════ الكاش ═══════════
r.get('/cash', async (req, res) => {
  const dCash = await demoCond('cash');
  const reports = await q(`SELECT cr.*, u.name AS courier_name FROM cash_reports cr JOIN users u ON u.id=cr.courier_id ${dCash ? `WHERE ${dCash.replaceAll('o.','cr.')}` : ''} ORDER BY cr.id DESC LIMIT 50`);
  const dOrder = await demoCond('orders');
  const reportRows = await q(`SELECT o.code, o.total, o.status, o.courier_id, u.name AS courier_name FROM orders o JOIN users u ON u.id=o.courier_id WHERE o.created_at::date=CURRENT_DATE ${dOrder ? `AND ${dOrder}` : ''} ORDER BY o.id`);
  res.json({ reports, today_orders: reportRows });
});

// ── مستحقات المحلات هذا الأسبوع ──
r.get('/stores-week', async (req, res) => {
  const dOrder = await demoCond('orders');
  const dStore = await demoCond('stores');
  const rows = await q(`
    SELECT
      s.id, s.name, s.logo, s.commission_rate,
      COALESCE(s.last_paid_at, now() - interval '7 days') AS last_paid_at,
      COUNT(o.id)::int AS order_count,
      COALESCE(SUM(o.total), 0)::int AS gross,
      ROUND(COALESCE(SUM(o.total), 0) * s.commission_rate / 100)::int AS commission_due,
      ROUND(COALESCE(SUM(o.total), 0) * (1 - s.commission_rate / 100))::int AS net_due
    FROM stores s
    LEFT JOIN orders o ON o.store_id = s.id
      AND o.status = 'delivered'
      AND o.updated_at > COALESCE(s.last_paid_at, now() - interval '7 days')
      ${dOrder ? `AND ${dOrder}` : ''}
    ${dStore ? `WHERE ${dStore}` : ''}
    GROUP BY s.id, s.name, s.logo, s.commission_rate, s.last_paid_at
    ORDER BY gross DESC
  `);
  res.json(rows);
});

// ── تسجيل تسليم مستحقات محل ──
r.post('/stores/:id/pay', async (req, res) => {
  try {
    await tx(async (c) => {
      // قفل صف المتجر — يمنع دفعتين متزامنتين لنفس الفترة
      const s = (await c.query(`SELECT * FROM stores WHERE id=$1 FOR UPDATE`, [req.params.id])).rows[0];
      if (!s) throw Object.assign(new Error('المحل غير موجود'), { status: 404 });
      // المستحق: الطلبات المُسلَّمة فعلياً فقط (غير المسلّمة تُحتسب يوم تُسلَّم)
      const since = s.last_paid_at || new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      const row = (await c.query(`
        SELECT COALESCE(SUM(total),0)::int AS gross,
          ROUND(COALESCE(SUM(total),0) * $2::numeric / 100)::int AS commission_due,
          ROUND(COALESCE(SUM(total),0) * (1 - $2::numeric/100))::int AS net_due
        FROM orders WHERE store_id=$1 AND status='delivered' AND updated_at > $3
      `, [s.id, s.commission_rate, since])).rows[0];
      if ((row?.net_due || 0) <= 0) throw Object.assign(new Error('ماكو مستحقات جديدة لهذا المحل'), { status: 400 });
      // تخزين سجل الدفعة (إعلامي — الرصيد يُحصّل عند التسليم أصلو)
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note)
        VALUES ($1,'adjust',$2,'\u062fفعة \u0645ستحقات \u0623سبوعية — \u0635افي \u0628عد \u0627لعمولة')`,
        [s.id, row.net_due]);
      // تحديث تاريخ آخر دفعة (=الآن)
      await c.query(`UPDATE stores SET last_paid_at=now() WHERE id=$1`, [s.id]);
      await audit(req.user.id, 'store_pay', 'store', s.id, null, row);
      res.json({ ok: true, ...row });
    });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message || 'خطأ بالسيرفر' });
  }
});

r.patch('/cash/:id', async (req, res) => {
  const rep = await one('SELECT * FROM cash_reports WHERE id=$1', [req.params.id]);
  if (!rep) return res.status(404).json({ error: 'التقرير غير موجود' });
  const { status } = req.body;
  if (status === 'approved') {
    await q(`UPDATE cash_reports SET status='approved', approved_by=$1, receipt_no='RC-'||1000+id WHERE id=$2`, [req.user.id, rep.id]);
  } else {
    await q(`UPDATE cash_reports SET status=$1, approved_by=$2 WHERE id=$3`, [status, req.user.id, rep.id]);
  }
  await audit(req.user.id, 'cash_' + status, 'cash_report', rep.id, rep);
  res.json({ ok: true });
});

// ── قرار مباشر من تطبيق الأدمن (approve/reject) ──
r.post('/cash/:id/decision', async (req, res) => {
  const rep = await one('SELECT * FROM cash_reports WHERE id=$1', [req.params.id]);
  if (!rep) return res.status(404).json({ error: 'التقرير غير موجود' });
  const { action } = req.body;
  const status = action === 'approve' ? 'approved' : 'rejected';
  if (status === 'approved') {
    await q(`UPDATE cash_reports SET status='approved', approved_by=$1, receipt_no='RC-'||1000+id WHERE id=$2`, [req.user.id, rep.id]);
    await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'cash','تم اعتماد تقرير الكاش ✓','صافي المستحقات انضاف لمحفظتك')`, [rep.courier_id]);
  } else {
    await q(`UPDATE cash_reports SET status='rejected', approved_by=$1 WHERE id=$2`, [req.user.id, rep.id]);
  }
  await audit(req.user.id, 'cash_decision', 'cash_report', rep.id, { status: rep.status }, { status });
  res.json({ ok: true });
});

// ═══════════ المستخدمون ═══════════
r.get('/users', async (req, res) => {
  const { role } = req.query;
  const w = [];
  const p = [];
  if (role && role !== 'all') { p.push(role); w.push(`role=$${p.length}`); }
  const dUser = await demoCond('users');
  if (dUser) w.push(dUser);
  const users = await q(`SELECT id, phone, name, role, avatar, verified, blocked, created_at FROM users u
    ${w.length ? `WHERE ${w.join(' AND ')}` : ''} ORDER BY u.id DESC LIMIT 200`, p);
  res.json({ users });
});

r.patch('/users/:id', async (req, res) => {
  const u = await one('SELECT * FROM users WHERE id=$1', [req.params.id]);
  if (!u) return res.status(404).json({ error: 'المستخدم غير موجود' });
  const { blocked, role, name } = req.body;
  const ns = (await q(`UPDATE users SET
    blocked=COALESCE($1, blocked), role=COALESCE($2, role), name=COALESCE($3, name)
    WHERE id=$4 RETURNING *`, [blocked ?? null, role ?? null, name ?? null, u.id]))[0];
  await audit(req.user.id, 'user_update', 'user', u.id, u, ns);
  res.json({ ok: true });
});

r.post('/users', async (req, res) => {
  const { phone, name, role = 'delivery', password = '' } = req.body;
  if (!phone || !name) return res.status(400).json({ error: 'الرقم والاسم مطلوبين' });
  const exists = await one('SELECT id FROM users WHERE phone=$1', [phone]);
  if (exists) return res.status(400).json({ error: 'الرقم مسجل مسبقًا' });
  const u = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,true,$4) RETURNING id`,
    [phone, name, role, password ? await bcrypt.hash(password, 10) : '']))[0];
  await audit(req.user.id, 'user_create', 'user', u.id, null, { phone, name, role });
  res.status(201).json({ ok: true });
});

// ═══════════ المحافظات والأحياء والأقسام ═══════════
r.get('/governorates', async (_req, res) => {
  const rows = await q('SELECT * FROM governorates ORDER BY sort, id');
  const districts = await q('SELECT * FROM districts ORDER BY sort, id');
  res.json({ governorates: rows.map(g => ({ ...g, districts: districts.filter(d => d.governorate_id === g.id) })) });
});

r.post('/governorates', async (req, res) => {
  const { name, name_en } = req.body;
  if (!name) return res.status(400).json({ error: 'اسم المحافظة مطلوب' });
  const dup = await one('SELECT id FROM governorates WHERE name=$1', [name]);
  if (dup) return res.status(400).json({ error: 'هذه المحافظة مسجلة مسبقًا' });
  const g = (await q(`INSERT INTO governorates (name, name_en) VALUES ($1,$2) RETURNING *`, [name, name_en || '']))[0];
  await audit(req.user.id, 'gov_create', 'governorate', g.id, null, g);
  res.status(201).json({ governorate: g });
});

r.post('/districts', async (req, res) => {
  const { governorate_id, name } = req.body;
  if (!governorate_id || !name) return res.status(400).json({ error: 'المحافظة والحي مطلوبين' });
  const d = (await q(`INSERT INTO districts (governorate_id, name) VALUES ($1,$2) RETURNING *`, [governorate_id, name]))[0];
  res.status(201).json({ district: d });
});

r.delete('/governorates/:id', async (req, res) => {
  await q('DELETE FROM districts WHERE governorate_id=$1', [req.params.id]);
  await q('DELETE FROM governorates WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
});

r.delete('/districts/:id', async (req, res) => {
  await q('DELETE FROM districts WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
});

r.get('/categories', async (_req, res) => {
  res.json({ categories: await q('SELECT * FROM categories ORDER BY sort, id') });
});

r.post('/categories', async (req, res) => {
  const { name, icon = '📦' } = req.body;
  if (!name) return res.status(400).json({ error: 'اسم القسم مطلوب' });
  const c = (await q(`INSERT INTO categories (name, icon) VALUES ($1,$2) RETURNING *`, [name, icon]))[0];
  res.status(201).json({ category: c });
});

r.delete('/categories/:id', async (req, res) => {
  await q('DELETE FROM categories WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
});

// ═══════════ الإشعارات الجماعية ═══════════
r.post('/notify', async (req, res) => {
  const { role, title, body, user_id } = req.body;
  if (!title) return res.status(400).json({ error: 'عنوان الإشعار مطلوب' });
  if (user_id) await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'broadcast',$2,$3)`, [user_id, title, body || '']);
  else if (role && role !== 'all') await q(`INSERT INTO notifications (role, type, title, body) VALUES ($1,'broadcast',$2,$3)`, [role, title, body || '']);
  else {
    for (const rr of ['customer', 'vendor', 'delivery'])
      await q(`INSERT INTO notifications (role, type, title, body) VALUES ($1,'broadcast',$2,$3)`, [rr, title, body || '']);
  }
  await audit(req.user.id, 'broadcast', 'notification');
  res.json({ ok: true });
});

// ═══════════ الإعدادات ═══════════
r.get('/settings', async (_req, res) => {
  const rows = await q('SELECT * FROM settings ORDER BY key');
  res.json({ settings: Object.fromEntries(rows.map(x => [x.key, x.value])) });
});

r.patch('/settings', async (req, res) => {
  const { key, value } = req.body;
  if (!key) return res.status(400).json({ error: 'المفتاح مطلوب' });
  await q(`INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value`, [key, String(value)]);
  await audit(req.user.id, 'settings_update', 'settings', 0, null, { key, value });
  res.json({ ok: true });
});

// ═══════════ الكوبونات والنقاط ═══════════
r.get('/coupons', async (_req, res) => {
  const coupons = await q(`SELECT c.*, s.name AS store_name FROM coupons c LEFT JOIN stores s ON s.id=c.store_id ORDER BY c.id DESC LIMIT 100`);
  const usages = await q(`SELECT cu.*, u.name AS user_name, c.code FROM coupon_usages cu JOIN coupons c ON c.id=cu.coupon_id JOIN users u ON u.id=cu.user_id ORDER BY cu.id DESC LIMIT 50`);
  res.json({ coupons, usages });
});

r.get('/points', async (req, res) => {
  const top = await q(`SELECT id, name, phone, points FROM users WHERE role='customer' ORDER BY points DESC LIMIT 20`);
  res.json({ top });
});

r.patch('/users/:id/points', async (req, res) => {
  const target = await one('SELECT * FROM users WHERE id=$1', [req.params.id]);
  if (!target) return res.status(404).json({ error: 'المستخدم غير موجود' });
  const pts = parseInt(req.body.points) || 0;
  await tx(async (c) => {
    await c.query(`UPDATE users SET points = points + $1 WHERE id=$2`, [pts, target.id]);
    if (pts) await c.query(`INSERT INTO point_transactions (user_id, points, type, note) VALUES ($1,$2,'adjust',$3)`,
      [target.id, pts, `تعديل من الأدمن: ${req.user.name || 'أدمن'}`]);
  });
  await audit(req.user.id, 'points_adjust', 'users', target.id, null, { pts, target: target.phone });
  res.json({ ok: true, balance: (target.points || 0) + pts });
});

// ═══════════ مراجعة التقييمات ═══════════
r.get('/reviews', async (req, res) => {
  const rows = await q(`SELECT rv.*, u.name AS user_name, u.phone AS user_phone,
      s.name AS store_name, o.code AS order_code,
      (SELECT p.name FROM products p JOIN order_items oi ON oi.product_id=p.id WHERE oi.order_id=rv.order_id LIMIT 1) AS product_name
    FROM reviews rv
    JOIN stores s ON s.id=rv.store_id
    LEFT JOIN users u ON u.id=rv.user_id
    LEFT JOIN orders o ON o.id=rv.order_id
    ORDER BY rv.id DESC LIMIT 100`);
  res.json({ reviews: rows });
});

r.delete('/reviews/:id', async (req, res) => {
  const rv = await one('SELECT * FROM reviews WHERE id=$1', [req.params.id]);
  if (!rv) return res.status(404).json({ error: 'التقييم غير موجود' });
  await q(`DELETE FROM reviews WHERE id=$1`, [rv.id]);
  await audit(req.user.id, 'review_delete', 'reviews', rv.id, null, { reason: String(req.query.reason || '') });
  res.json({ ok: true });
});

// ═══════════ طلبات الإرجاع (إشراف الأدمن) ═══════════
r.get('/refunds', async (req, res) => {
  const rows = await q(`SELECT rf.*, o.code AS order_code, o.total, o.store_id, u.name AS user_name, u.phone AS user_phone,
      s.name AS store_name
    FROM refund_requests rf
    JOIN orders o ON o.id=rf.order_id
    JOIN users u ON u.id=o.user_id
    LEFT JOIN stores s ON s.id=o.store_id
    ORDER BY rf.id DESC LIMIT 100`);
  res.json({ refunds: rows });
});

r.patch('/refunds/:id', async (req, res) => {
  const { status, reason = '' } = req.body;
  const rf = await one(`SELECT rf.*, o.user_id, o.status AS order_status, o.store_id FROM refund_requests rf JOIN orders o ON o.id=rf.order_id WHERE rf.id=$1`, [req.params.id]);
  if (!rf) return res.status(404).json({ error: 'الطلب غير موجود' });
  if (rf.status !== 'pending') return res.status(400).json({ error: 'الطلب انحسم مسبقاً' });
  const accepted = status === 'accepted';
  await tx(async (c) => {
    await c.query(`UPDATE refund_requests SET status=$1, resolved_at=now() WHERE id=$2`, [status, rf.id]);
    if (accepted) {
      if (!['returned', 'cancelled'].includes(rf.order_status))
        await c.query(`UPDATE orders SET status='returned', updated_at=now() WHERE id=$1`, [rf.order_id]);
      await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role, note) VALUES ($1,$2,'returned','admin',$3)`,
        [rf.order_id, rf.order_status, reason || 'قرار الأدمن']);
      await c.query(`UPDATE product_variants v SET stock = v.stock + oi.qty
        FROM order_items oi WHERE oi.order_id=$1 AND oi.variant_id IS NOT NULL AND v.id=oi.variant_id`, [rf.order_id]);
      await c.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'refund','قبلنا إرجاعك ✓',$2)`,
        [rf.user_id, rf.type === 'exchange' ? 'الاستبدال مقبول — تعال المحل' : 'استلمنا طلبك — تعال المحل نكمل معاك']);
    } else {
      await c.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'refund','مرفوض ${rf.type === 'exchange' ? 'الاستبدال' : 'الإرجاع'}',$2)`,
        [rf.user_id, reason || '']);
    }
  });
  await audit(req.user.id, 'refund_decision', 'refund_requests', rf.id, null, { status, reason });
  res.json({ ok: true });
});

// ═══════════ سجل العمليات ═══════════
r.get('/audit', async (req, res) => {
  res.json({ logs: await q(`SELECT a.*, u.name AS admin_name FROM audit_logs a LEFT JOIN users u ON u.id=a.admin_id ORDER BY a.id DESC LIMIT 100`) });
});

// ═══════════ الإشعارات للأدمن ═══════════
r.get('/notifications', async (req, res) => {
  const dNotif = await demoCond('notif', { o: 'n' });
  res.json({ notifications: await q(`SELECT * FROM notifications n WHERE role='admin' ${dNotif ? `AND ${dNotif}` : ''} ORDER BY n.id DESC LIMIT 50`) });
});

export default r;
