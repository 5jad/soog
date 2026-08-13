// ═══════════ هجرة صور base64 → ملفات مخدومة (لمرة واحدة) ═══════════
// المعالجة: يقرأ كل قيمة صورة من القاعدة — إن كانت base64 (data: أو /9j)
// يحوّلها إلى ملف في public/uploads ويحدّث الصف بالمسار الجديد.
//
// ⚠️ التشغيل الآمن:
//   1) القاعدة المحلية أولاً: DATABASE_URL='postgres://zaboon@127.0.0.1:5434/zaboon'
//   2) الإنتاج: بموافقة صريحة منفصلة وبعد نسخة احتياطية.
//
// التشغيل: node src/migrate-images.js [--count=N]   (—count للحد: يعالج أول N صف فقط)
import { q } from './db.js';
import { UPLOAD_BASE, convertValue, isBase64Image } from './image-store.js';

const limit = (() => {
  const i = process.argv.findIndex((a) => a.startsWith('--count='));
  return i >= 0 ? Number(process.argv[i].split('=')[1]) || 0 : 0;
})();

// مناطق الصور المُرحَّلة: (جدول، عمود نصي واحد، عمود مصفوفة)
const TARGETS = [
  { table: 'products', cols: ['image', 'images'] },
  { table: 'stores', cols: ['logo', 'cover'] },
  { table: 'ad_requests', cols: ['art', 'image'] },
  { table: 'users', cols: ['avatar'] },
];

let converted = 0;
let skipped = 0;

for (const t of TARGETS) {
  const rows = await q(`SELECT id, ${t.cols.join(', ')} FROM ${t.table} ORDER BY id`, []);
  for (const row of rows) {
    if (limit && converted + skipped >= limit) break;
    const sets = [];
    const pp = [row.id];
    for (const col of t.cols) {
      const v = row[col];
      const base = Array.isArray(v) ? v : v != null ? String(v) : '';
      // نتخطى الموجود أصلاً كمسار أو إيموجي/نص قصير
      const needs = Array.isArray(v) ? v.some(isBase64Image) : isBase64Image(v);
      if (!needs) continue;
      const nv = await convertValue(v);
      if (nv === null || nv === undefined) { skipped++; continue; }
      pp.push(nv);
      sets.push(`${col}=$${pp.length}`);
    }
    if (sets.length) {
      await q(`UPDATE ${t.table} SET ${sets.join(', ')} WHERE id=$1`, pp);
      converted++;
      if (converted % 50 === 0) console.log(`${t.table}: ${converted} صف محوّل...`);
    }
  }
  if (limit && converted + skipped >= limit) break;
}

console.log(`\nتم تحويل ${converted} صف — تخطّي ${skipped} قيمة غير صالحة`);
console.log(`المسار الجديد: ${UPLOAD_BASE}... (ملفات في backend/src/public/uploads/)`);
if (converted > 0) console.log('⚠️ تأكد من فحص التطبيق محلياً قبل أي تشغيل على الإنتاج.');