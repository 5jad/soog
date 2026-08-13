import { Router } from 'express';
import { q, one, tx } from '../db.js';
import { auth, roles } from '../middleware.js';
import { demoCond } from '../demo.js';

const r = Router();
r.use(auth, roles('delivery'));

// ── الحالة: متصل/غير متصل (مخزنة محلياً بالذاكرة البسيطة) ──
const online = new Set();

r.get('/status', (req, res) => res.json({ online: online.has(req.user.id) }));
r.get('/online', (req, res) => res.json({ online: online.has(req.user.id) }));
r.post('/online', (req, res) => {
  if (req.body.online) online.add(req.user.id); else online.delete(req.user.id);
  res.json({ online: online.has(req.user.id) });
});

// ── الطلبات المتاحة ──
r.get('/available', async (req, res) => {
  const dOrder = await demoCond('orders');
  const orders = await q(`SELECT o.*, s.name AS store_name, s.address AS store_address, s.phone AS store_phone, s.lat AS store_lat, s.lng AS store_lng, s.location_url AS store_location_url,
      u.name AS user_name, u.phone AS user_phone,
      a.lat AS user_lat, a.lng AS user_lng, a.label AS user_address_label
    FROM orders o JOIN stores s ON s.id=o.store_id JOIN users u ON u.id=o.user_id
    LEFT JOIN addresses a ON a.id=o.address_id
    WHERE o.status='ready' AND o.courier_id IS NULL ${dOrder ? `AND ${dOrder}` : ''} ORDER BY o.id LIMIT 20`);
  res.json({ orders });
});

r.post('/accept/:orderId', async (req, res) => {
  const o = await one(`SELECT * FROM orders WHERE id=$1 AND status='ready' AND courier_id IS NULL`, [req.params.orderId]);
  if (!o) return res.status(400).json({ error: 'الطلب انحجز أو غير متاح' });
  // منع قبول رحلة جديدة والمندوب عندة رحلة جارية — يسلمها أولاً
  const active = await one(`SELECT t.id FROM delivery_trips t JOIN orders o2 ON o2.id=t.order_id
    WHERE t.courier_id=$1 AND o2.status='delivering' AND t.delivered_at IS NULL`, [req.user.id]);
  if (active) return res.status(400).json({ error: 'عندك رحلة جارية — سلمها أولاً قبل ما تستلم جديد' });
  // إذا الطلب من مجموعة (أكثر من محل) — ياخذ المندوب جميع طلبات المجموعة برحلة واحدة
  const group = o.group_id
    ? await q(`SELECT * FROM orders WHERE group_id=$1 AND status='ready' AND courier_id IS NULL AND id <> $2`, [o.group_id, o.id])
    : [];
  const all = [o, ...group];
  await tx(async (c) => {
    const t = (await c.query(`INSERT INTO delivery_trips (order_id, courier_id) VALUES ($1,$2) RETURNING *`, [o.id, req.user.id])).rows[0];
    for (const ord of all) {
      await c.query(`INSERT INTO trip_orders (trip_id, order_id) VALUES ($1,$2)`, [t.id, ord.id]);
      await c.query(`UPDATE orders SET courier_id=$1, status='delivering', updated_at=now() WHERE id=$2`, [req.user.id, ord.id]);
      await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role) VALUES ($1,'ready','delivering','delivery')`, [ord.id]);
    }
    await c.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'delivery','مندوبك انطلق 🛵','يوصلك ${all.length === 1 ? 'طلبك' : `طلباتك من ${all.length} محلات`}')`, [o.user_id]);
  });
  res.json({ ok: true, orders: all.length });
});

// ── رحلتي الحالية ──
r.get('/trip', async (req, res) => {
  const t = await one(`SELECT t.*, o.code, o.total, o.status, o.address_text, o.user_id, o.group_id,
      s.name AS store_name, s.address AS store_address, s.phone AS store_phone, s.lat AS store_lat, s.lng AS store_lng, s.location_url AS store_location_url,
      u.name AS user_name, u.phone AS user_phone,
      a.lat AS user_lat, a.lng AS user_lng, a.label AS user_address_label
    FROM delivery_trips t JOIN orders o ON o.id=t.order_id JOIN stores s ON s.id=o.store_id
    JOIN users u ON u.id=o.user_id
    LEFT JOIN addresses a ON a.id=o.address_id
    WHERE t.courier_id=$1 AND o.status='delivering' ORDER BY t.id DESC LIMIT 1`, [req.user.id]);
  if (!t) return res.json({ trip: null });
  t.items = await q('SELECT * FROM order_items WHERE order_id=$1', [t.order_id]);
  // كل طلبات الرحلة (حالة الطلب من أكثر من محل)
  t.orders = await q(`SELECT o.id, o.code, o.status, o.total, o.store_id, s.name AS store_name,
      s.address AS store_address, s.phone AS store_phone, s.lat AS store_lat, s.lng AS store_lng, s.location_url AS store_location_url
    FROM trip_orders tr JOIN orders o ON o.id=tr.order_id JOIN stores s ON s.id=o.store_id
    WHERE tr.trip_id=$1 ORDER BY o.id`, [t.id]);
  res.json({ trip: t });
});

// ── رحلة الطلب المحدد (لتفاصيل الطلب بحساب المندوب — رحلة واحدة لكل مجموعة) ──
r.get('/orders/:id/trip', async (req, res) => {
  const t = await one(`SELECT t.*, o.code, o.total, o.status, o.address_text, o.user_id, o.group_id,
      s.name AS store_name, s.address AS store_address, s.phone AS store_phone, s.lat AS store_lat, s.lng AS store_lng, s.location_url AS store_location_url,
      u.name AS user_name, u.phone AS user_phone,
      a.lat AS user_lat, a.lng AS user_lng, a.label AS user_address_label
    FROM delivery_trips t JOIN orders o ON o.id=t.order_id JOIN stores s ON s.id=o.store_id
    JOIN users u ON u.id=o.user_id LEFT JOIN addresses a ON a.id=o.address_id
    WHERE t.id=(SELECT trip_id FROM trip_orders WHERE order_id=$1 ORDER BY trip_id DESC LIMIT 1) AND t.courier_id=$2
    LIMIT 1`, [req.params.id, req.user.id]);
  if (!t) return res.json({ trip: null });
  t.orders = await q(`SELECT o.id, o.code, o.status, o.total, s.name AS store_name
    FROM trip_orders tr JOIN orders o ON o.id=tr.order_id JOIN stores s ON s.id=o.store_id
    WHERE tr.trip_id=$1 ORDER BY o.id`, [t.id]);
  res.json({ trip: t });
});
r.post('/location', async (req, res) => {
  const { lat, lng } = req.body;
  if (!lat || isNaN(+lat) || !lng || isNaN(+lng)) return res.status(400).json({ error: 'إحداثيات ناقصة' });
  const t = await one(`SELECT id FROM delivery_trips WHERE id=$1 AND courier_id=$2 AND delivered_at IS NULL`, [req.body.trip_id, req.user.id]);
  if (!t) return res.status(403).json({ error: 'الرحلة غير موجودة' });
  await q(`UPDATE delivery_trips SET lat=$1, lng=$2, location_updated_at=now() WHERE id=$3 AND courier_id=$4`, [+lat, +lng, req.body.trip_id, req.user.id]);
  await q(`INSERT INTO delivery_track_log (trip_id, lat, lng) VALUES ($1,$2,$3)`, [req.body.trip_id, +lat, +lng]);
  res.json({ ok: true });
});

r.post('/pickup', async (req, res) => {
  const t = await one(`SELECT t.*, o.status FROM delivery_trips t JOIN orders o ON o.id=t.order_id WHERE t.id=$1 AND t.courier_id=$2`,
    [req.body.trip_id, req.user.id]);
  if (!t || t.status !== 'delivering') return res.status(400).json({ error: 'الرحلة غير موجودة' });
  await q(`UPDATE delivery_trips SET picked_at=now() WHERE id=$1`, [t.id]);
  res.json({ ok: true });
});

r.post('/delivered', async (req, res) => {
  const t = await one(`SELECT t.*, o.user_id, o.store_id, o.total FROM delivery_trips t JOIN orders o ON o.id=t.order_id WHERE t.id=$1 AND t.courier_id=$2 AND t.delivered_at IS NULL`,
    [req.body.trip_id, req.user.id]);
  if (!t) return res.status(404).json({ error: 'الرحلة غير موجودة' });
  const ids = (await q('SELECT order_id FROM trip_orders WHERE trip_id=$1', [t.id])).map(r => r.order_id);
  if (!ids.includes(t.order_id)) ids.push(t.order_id);
  const orders = await q(`SELECT * FROM orders WHERE id = ANY($1::int[])`, [ids]);
  const claim = await q(`UPDATE delivery_trips SET delivered_at=now() WHERE id=$1 AND delivered_at IS NULL RETURNING id`, [t.id]);
  if (!claim.length) return res.status(409).json({ error: 'الرحلة مسلّمة مسبقاً' });
  await tx(async (c) => {
    for (const ord of orders) {
      if (ord.status === 'delivered') continue;
      // نقاط الولاء للزبون: 1 نقطة لكل 1000 د.ع من قيمة الطلب (يُحسب قبل التحديث ليُسجل بالطلب)
      const earn = Math.floor(ord.total / 1000);
      await c.query(`UPDATE orders SET status='delivered', updated_at=now(), points_earned=$2 WHERE id=$1`, [ord.id, earn]);
      await c.query(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role) VALUES ($1,'delivering','delivered','delivery')`, [ord.id]);
      if (earn > 0) {
        await c.query(`UPDATE users SET points = points + $1 WHERE id=$2`, [earn, t.user_id]);
        await c.query(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,$2,'earn','نقاط من الطلب ✅',$3)`, [t.user_id, earn, ord.id]);
      }
      // رصيد التاجر: القيمة ناقص العمولة
      const store = (await c.query(`SELECT commission_rate FROM stores WHERE id=$1`, [ord.store_id])).rows[0];
      const comm = Math.round(ord.total * (store.commission_rate / 100));
      await c.query(`UPDATE wallets SET available=available+$1 WHERE store_id=$2`, [ord.total - comm, ord.store_id]);
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note, ref) VALUES ($1,'sale',$2,'طلب مسلّم #'||$3::text,$3)`, [ord.store_id, ord.total - comm, ord.id]);
      await c.query(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'commission',$2,'عمولة المنصة')`, [ord.store_id, -comm]);
    }
  });
  res.json({ ok: true, orders: orders.length });
});

// ── المحفظة والجرد ──
// ═══════════ محادثات المندوب مع الزبائن (فقط أثناء التوصيل) ═══════════
const deliveringWith = (customerId, courierId) => one(
  `SELECT o.id FROM orders o WHERE o.user_id=$1 AND o.courier_id=$2 AND o.status='delivering' LIMIT 1`,
  [customerId, courierId]);

r.get('/conversations', async (req, res) => {
  const rows = await q(`SELECT cv.*, u.name AS user_name,
      (SELECT body FROM messages m WHERE m.conversation_id=cv.id ORDER BY m.id DESC LIMIT 1) AS last_message,
      EXISTS(SELECT 1 FROM messages m WHERE m.conversation_id=cv.id AND m.sender_role='customer' AND m.read_at IS NULL) AS has_unread
    FROM conversations cv JOIN users u ON u.id=cv.user_id
    WHERE cv.courier_id=$1 AND EXISTS(SELECT 1 FROM orders o WHERE o.user_id=cv.user_id AND o.courier_id=cv.courier_id AND o.status='delivering')
    ORDER BY cv.last_message_at DESC`, [req.user.id]);
  res.json({ conversations: rows });
});

r.get('/conversations/:id/messages', async (req, res) => {
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND courier_id=$2', [req.params.id, req.user.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  if (!(await deliveringWith(cv.user_id, req.user.id))) return res.status(403).json({ error: 'انتهت رحلة التوصيل — المحادثة مغلقة' });
  const msgs = await q(`SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id=m.sender_id
    WHERE m.conversation_id=$1 ORDER BY m.id`, [cv.id]);
  await q(`UPDATE messages SET read_at=now() WHERE conversation_id=$1 AND sender_id!=$2 AND read_at IS NULL`, [cv.id, req.user.id]);
  res.json({ conversation: cv, messages: msgs });
});

r.post('/conversations/:id/messages', async (req, res) => {
  const cv = await one('SELECT * FROM conversations WHERE id=$1 AND courier_id=$2', [req.params.id, req.user.id]);
  if (!cv) return res.status(404).json({ error: 'المحادثة غير موجودة' });
  if (!(await deliveringWith(cv.user_id, req.user.id))) return res.status(403).json({ error: 'انتهت رحلة التوصيل — المحادثة مغلقة' });
  const body = String(req.body.body || '').slice(0, 1000);
  const m = (await q(`INSERT INTO messages (conversation_id, sender_id, sender_role, body) VALUES ($1,$2,'courier',$3) RETURNING *`, [cv.id, req.user.id, body]))[0];
  await q(`UPDATE conversations SET last_message_at=now() WHERE id=$1`, [cv.id]);
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'chat','رسالة من المندوب 📦',$2)`, [cv.user_id, body.slice(0, 60)]);
  res.status(201).json({ message: m });
});

r.get('/wallet', async (req, res) => {
  const today = await q(`SELECT o.code, o.total, o.status FROM orders o WHERE o.courier_id=$1 AND o.created_at::date=CURRENT_DATE ORDER BY o.id`, [req.user.id]);
  const collected = today.filter(o => o.status === 'delivered').reduce((a, b) => a + b.total, 0);
  const pending = today.filter(o => o.status === 'delivering').reduce((a, b) => a + b.total, 0);
  const rate = await one(`SELECT value FROM settings WHERE key='courier_rate'`);
  const commission = Math.round(collected * (parseFloat(rate?.value || 5) / 100));
  const reports = await q(`SELECT * FROM cash_reports WHERE courier_id=$1 ORDER BY id DESC LIMIT 20`, [req.user.id]);
  res.json({ wallet: { balance: collected - Math.round(collected * (parseFloat(rate?.value || 5) / 100)), today: collected, collected, pending, commission, reports }, transactions: reports.map(r => ({ id: r.id, type: 'credit', note: 'تقرير كاش ' + (r.receipt_no || '') + ' — صافي', amount: r.net, created_at: r.created_at, status: r.status })) });
});

r.post('/cash-report', async (req, res) => {
  const total_collected = req.body.total_collected ?? req.body.amount;
  const rate = await one(`SELECT value FROM settings WHERE key='courier_rate'`);
  const commission = Math.round(total_collected * (parseFloat(rate?.value || 5) / 100));
  const rep = (await q(`INSERT INTO cash_reports (courier_id, total_collected, commission_amount, net)
    VALUES ($1,$2,$3,$4) RETURNING *`, [req.user.id, total_collected, commission, total_collected - commission]))[0];
  await q(`INSERT INTO notifications (role, type, title, body, data) VALUES ('admin','cash','المندوب سلّم الكاش 💵',$1, jsonb_build_object('report_id',$2::int))`, [`${total_collected.toLocaleString()} د.ع قيد المراجعة`, rep.id]);
  res.status(201).json({ report: rep });
});

// ── إحصائيات سريعة ──
r.get('/stats', async (req, res) => {
  const today = await q(`SELECT status, count(*)::int AS n FROM orders WHERE courier_id=$1 AND created_at::date=CURRENT_DATE GROUP BY status`, [req.user.id]);
  const s = Object.fromEntries(today.map(x => [x.status, x.n]));
  res.json({ stats: { today_orders: today.reduce((a, b) => a + b.n, 0), delivered: s.delivered || 0, delivering: s.delivering || 0 } });
});

export default r;
