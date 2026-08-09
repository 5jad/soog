import { pool } from './db.js';

const stmts = [
  `ALTER TABLE product_variants ADD COLUMN IF NOT EXISTS vgroup TEXT DEFAULT 'قياس'`,
  `ALTER TABLE product_variants ADD COLUMN IF NOT EXISTS color TEXT DEFAULT ''`,
  `ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS variant_label TEXT DEFAULT ''`,
  `CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id)`,
  `CREATE INDEX IF NOT EXISTS idx_cart_combo ON cart_items (user_id, product_id, variant_label)`,
  `ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'return' CHECK (type IN ('return','exchange'))`,
  `ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS desired TEXT DEFAULT ''`,
  `ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ`,
  `CREATE INDEX IF NOT EXISTS idx_refund_orders ON refund_requests(order_id)`,
  `DROP TABLE IF EXISTS messages, conversations CASCADE`,
  `CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    courier_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, courier_id)
  )`,
  `CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id INTEGER NOT NULL REFERENCES users(id),
    sender_role TEXT DEFAULT 'customer',
    body TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
  )`,
];

for (const s of stmts) {
  try {
    await pool.query(s);
  } catch (e) {
    console.error('⚠️ مهاجرة فشلت:', e.message);
  }
}
console.log('✅ المهاجرة (chat courier only + refund) انطوت');
await pool.end();