// ═══════════ وضع العرض التجريبي: إخفاء / إظهار بلا مسح ═══════════
// البيانات الوهمية تبقى في القاعدة، ونخفيها بمجرد فلترة الاستعلامات.
// الماركر: المتاجر اسمها يبدأ بـ [وهمي] والمستخدمون أرقامهم تبدأ 000000000
import { one, q } from './db.js';

const KEY = 'demo_mode'; // 'shown' | 'hidden'

export const demoValue = async () => {
  const s = await one(`SELECT value FROM settings WHERE key=$1`, [KEY]);
  return s ? s.value : 'shown';
};

export const isHidden = async () => (await demoValue()) === 'hidden';

export const setDemoMode = (value) =>
  q(`INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value`, [KEY, value]);

// كمية البيانات الوهمية الحالية — تستعمل لمعرفة هل فيه داتا وهمية
export const demoStats = async () => {
  const r = await one(`
    SELECT
      (SELECT count(*) FROM stores WHERE name LIKE '[وهمي] %')::int AS stores,
      (SELECT count(*) FROM products WHERE name LIKE '[وهمي]%')::int AS products,
      (SELECT count(*) FROM users WHERE phone LIKE '000000000%')::int AS users,
      (SELECT count(*) FROM orders WHERE store_id IN (SELECT id FROM stores WHERE name LIKE '[وهمي] %')
        OR user_id IN (SELECT id FROM users WHERE phone LIKE '000000000%'))::int AS orders`);
  return r || { stores: 0, products: 0, users: 0, orders: 0 };
};

// عند الإخفاء: تُرجِع شرط SQL يخفي الوهمي، وعند الإظهار ترجع ''
// s/u/o أسماء الألَيَاز المعتمدة في الاستعلام (افتراضياً вин)
const conds = (s = 's', u = 'u', o = 'o') => ({
  stores: `NOT (${s}.name LIKE '[وهمي] %')`,
  users: `NOT (${u}.phone LIKE '000000000%')`,
  orders: `NOT (${o}.store_id IN (SELECT id FROM stores WHERE name LIKE '[وهمي] %')
          OR ${o}.user_id IN (SELECT id FROM users WHERE phone LIKE '000000000%')
          OR (${o}.courier_id IS NOT NULL AND ${o}.courier_id IN (SELECT id FROM users WHERE phone LIKE '000000000%')))`,
  products: `NOT (${o}.store_id IN (SELECT id FROM stores WHERE name LIKE '[وهمي] %'))`,
  docs: `NOT (${o}.store_id IN (SELECT id FROM stores WHERE name LIKE '[وهمي] %'))`,
  ads: `NOT (${o}.store_id IN (SELECT id FROM stores WHERE name LIKE '[وهمي] %'))`,
  cash: `NOT (${o}.courier_id IN (SELECT id FROM users WHERE phone LIKE '000000000%'))`,
  notif: `NOT (${o}.user_id IN (SELECT id FROM users WHERE phone LIKE '000000000%'))`,
});

// ترجع الجملة الشرطية حسب النوع (خالية إذا الوضع إظهار)
export const demoCond = async (type, aliases) => {
  if (await isHidden()) return conds(aliases?.s, aliases?.u, aliases?.o)[type] || 'true';
  return '';
};