// توليد صور دائمة (data-URI) للمتاجر والمنتجات وتحديثها في قاعدة السحابة مباشرة
// التشغيل: node scripts/gen_seed_images.js
// الهدف: الصور تعيش داخل قاعدة البيانات — ما تختفي على Vercel ولا تحتاج حاسوباً
// المنتجات: لون رمادي حسب رقم القسم + اسم المنتج
// المتاجر: لون ثابت خاص بكل متجر (بحسب الفهرس)

import { pool } from '../src/db.js';

const FONT = '"Noto-Sans-Arabic"';

const COLORS = [
  ['#14532d', '#22c55e'], ['#7c2d12', '#fb923c'], ['#4c1d95', '#a78bfa'],
  ['#0c4a6e', '#38bdf8'], ['#831843', '#f472b6'], ['#713f12', '#eab308'],
  ['#1e293b', '#94a3b8'], ['#581c87', '#c084fc'],
];

import { execSync } from 'child_process';
import { readFileSync, unlinkSync } from 'fs';

async function mkLabel(text, colors, w, h, size) {
  const [c1, c2] = colors;
  const safe = String(text).replace(/"/g, '').slice(0, 40);
  const fname = `${Math.random().toString(36).slice(2)}.jpg`;
  const file = `/tmp/opencode/l_${fname}`;
  execSync(
    `convert -size ${w}x${h} gradient:'${c1}'-'${c2}' ` +
    `-font "${FONT}" -pointsize ${size} -fill white -gravity center -annotate +0+0 "${safe}" ` +
    `-bordercolor white -border 14x10 -crop ${w}x${h}+0+0 +repage ${file}`,
    { stdio: 'ignore' }
  );
  const b64 = readFileSync(file);
  unlinkSync(file);
  return `data:image/jpeg;base64,${b64.toString('base64')}`;
}

const stores = await pool.query(`SELECT id, name FROM stores WHERE logo = '🏪' OR logo LIKE '/uploads/%'`);
console.log('المتاجر بلا صور دائمة:', stores.rows.length);
for (const [i, s] of stores.rows.entries()) {
  const uri = await mkLabel(s.name, COLORS[i % COLORS.length], 720, 400, 88);
  await pool.query(`UPDATE stores SET logo=$1 WHERE id=$2`, [uri, s.id]);
}
const prods = await pool.query(`SELECT id, name, category_id FROM products WHERE image = '📦' OR image LIKE '/uploads/%'`);
console.log('المنتجات بلا صور دائمة:', prods.rows.length);
for (const [i, p] of prods.rows.entries()) {
  const uri = await mkLabel(p.name, COLORS[(p.category_id ?? i) % COLORS.length], 640, 640, 64);
  await pool.query(`UPDATE products SET image=$1 WHERE id=$2`, [uri, p.id]);
}
console.log('✓ الصور الدائمة جاهزة داخل قاعدة السحابة');
process.exit(0);