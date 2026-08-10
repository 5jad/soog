import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';
import { pool, q, one } from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let done = false;

/// تهيئة تلقائية عند أول تشغيل (بدون بيانات محلية):
/// 1) إنشاء الجداول إذا ما موجودة  2) حقن بيانات دنيا (أدمن + الكوت + أقسام + إعدادات)
export async function ensureDb() {
  if (done) return;

  // ترحيلات دائمة: تنفذ في كل تشغيل على أي قاعدة (IF NOT EXISTS آمن) — أوجدت الجداول الحديثة
  const ALWAYS = `
CREATE TABLE IF NOT EXISTS telegram_links (
  phone TEXT PRIMARY KEY,
  chat_id BIGINT NOT NULL UNIQUE,
  linked_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS telegram_bindings (
  token TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT FALSE
);
`;
  await pool.query(ALWAYS);

  const ok = await one(`SELECT to_regclass('public.users') IS NOT NULL AS ok`);
  if (ok?.ok) {
    const u = await one(`SELECT count(*)::int AS c FROM users`);
    if ((u?.c ?? 0) > 0) { done = true; return; }
  } else {
    const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8')
      // schema.sql يبدأ بـ DROP للتصفير المحلي — على السحابة نُزيله (ما نمسح شي موجود)
      .replace(/^DROP TABLE[^;]*;\s*/i, '');
    await pool.query(sql);
    console.log('📦 انبنيت قاعدة البيانات (schema.sql)');
  }
  await lightSeed();
  done = true;
}

/// حقن دنيا آمن (بدون مسح البيانات) — يشتغل مرة وحدة على قاعدة فارغة
async function lightSeed() {
  const adminHash = await bcrypt.hash('admin123', 10);
  await q(`INSERT INTO users (name, phone, role, password)
    VALUES ($1,$2,$3,$4)
    ON CONFLICT (phone) DO NOTHING`, ['أدمن زبون', '07900000000', 'admin', adminHash]);

  const gov = await one(`SELECT id FROM governorates WHERE name='واسط (الكوت)'`);
  let govId;
  if (!gov) {
    const r = await q(`INSERT INTO governorates (name, name_en, sort) VALUES ($1,$2,$3) RETURNING id`, ['واسط (الكوت)', 'Wasit', 1]);
    govId = r[0].id;
    const dNames = ['مركز الكوت', 'سوق المدينة', 'حي الجهاد', 'حي النصر', 'حي السلام', 'شارع الجمهورية', 'شارع الاستقلال', 'حي الحسين'];
    for (const [i, n] of dNames.entries())
      await q(`INSERT INTO districts (governorate_id, name, sort) VALUES ($1,$2,$3)`, [govId, n, i]);
  } else {
    govId = gov.id;
  }

  const cnt = await one(`SELECT count(*)::int AS c FROM categories`);
  if ((cnt?.c ?? 0) === 0) {
    const cats = [
      ['ملابس رجالي', '👔'], ['ملابس نسائي', '👗'], ['أطفال وألعاب', '🧒'], ['مكياج وعناية', '💄'],
      ['أحذية', '👟'], ['شنط وإكسسوارات', '👜'], ['مطاعم وأكل', '🍔'], ['بقالة وسوبرماركت', '🛒'],
      ['صيدليات', '💊'], ['إلكترونيات', '📱'],
    ];
    for (const [i, [n, ic]] of cats.entries())
      await q(`INSERT INTO categories (name, icon, sort) VALUES ($1,$2,$3)`, [n, ic, i]);
  }

  const settings = [
    ['platform_name', 'زبون'], ['platform_slogan', 'متاجر محافظة واسط — الكوت'],
    ['governorate_name', 'واسط (الكوت)'],
    ['commission_rate', '10'], ['courier_rate', '5'],
    ['ad_price_3d', '15000'], ['ad_price_7d', '25000'], ['ad_price_14d', '40000'],
    ['refund_days', '7'], ['free_delivery_min', '50000'], ['daily_goal', '5000000'],
  ];
  for (const [k, v] of settings)
    await q(`INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO NOTHING`, [k, v]);

  console.log('🌱 انحقنت البيانات الدنيا: أدمن 07900000000/admin123 + الكوت + الأقسام + الإعدادات');
}