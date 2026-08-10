// ═══════════ ترحيلات المخطط — تعمل مرة واحدة على أي قاعدة دون مسح البيانات ═══════════
// التشغيل: node scripts/migrate.js
import { pool } from '../src/db.js';

const ensures = [
  ["ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS variant_label TEXT NOT NULL DEFAULT ''", "cart_items.variant_label"],
  ["ALTER TABLE users ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0", "users.points"],
  ["ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code TEXT", "users.referral_code"],
  ["ALTER TABLE users ADD COLUMN IF NOT EXISTS referred_by INTEGER", "users.referred_by"],
  ["ALTER TABLE users ADD COLUMN IF NOT EXISTS roles TEXT[]", "users.roles"],
  ["ALTER TABLE users ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false", "users.verified"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS group_id INTEGER", "orders.group_id"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS warranty_days INTEGER NOT NULL DEFAULT 3", "orders.warranty_days"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS note TEXT DEFAULT ''", "orders.note"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cod'", "orders.payment_method"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS points_used INTEGER NOT NULL DEFAULT 0", "orders.points_used"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS points_discount INTEGER NOT NULL DEFAULT 0", "orders.points_discount"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal INTEGER NOT NULL DEFAULT 0", "orders.subtotal"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee INTEGER NOT NULL DEFAULT 0", "orders.delivery_fee"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount INTEGER NOT NULL DEFAULT 0", "orders.discount"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS total INTEGER NOT NULL DEFAULT 0", "orders.total"],
  ["ALTER TABLE orders ADD COLUMN IF NOT EXISTS code TEXT", "orders.code"],
  ["ALTER TABLE products ADD COLUMN IF NOT EXISTS old_price INTEGER", "products.old_price"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(3,2) NOT NULL DEFAULT 5.0", "stores.rating_avg"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS delivery_fee INTEGER NOT NULL DEFAULT 0", "stores.delivery_fee"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS free_delivery_min INTEGER NOT NULL DEFAULT 50000", "stores.free_delivery_min"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS on_vacation BOOLEAN NOT NULL DEFAULT false", "stores.on_vacation"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'approved'", "stores.status"],
  ["ALTER TABLE stores ADD COLUMN IF NOT EXISTS is_open BOOLEAN NOT NULL DEFAULT true", "stores.is_open"],
];

for (const [sql, label] of ensures) {
  try { await pool.query(sql); console.log('✓', label); }
  catch (e) { console.log('✗', label, '—', e.message.slice(0, 80)); }
}
console.log('انتهت الترحيلات');
process.exit(0);