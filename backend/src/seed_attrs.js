import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const q = async (sql, p = []) => (await pool.query(sql, p)).rows;

const ATTRS = {
  1: [ // ملابس رجالي
    ['size', 'المقاس', 'select', ['S', 'M', 'L', 'XL', 'XXL'], true],
    ['color', 'اللون', 'select', ['أسود', 'أبيض', 'كحلي', 'رمادي', 'بيج', 'أخضر'], false],
  ],
  2: [ // ملابس نسائي
    ['size', 'المقاس', 'select', ['S', 'M', 'L', 'XL', 'XXL', 'XS'], true],
    ['color', 'اللون', 'select', ['أسود', 'أبيض', 'وردي', 'بيج', 'بني', 'عنابي'], false],
  ],
  3: [ // أطفال وألعاب
    ['age', 'الفئة العمرية', 'select', ['0-1 سنة', '1-3 سنوات', '3-6 سنوات', '6-12 سنة', '12+ سنة'], true],
    ['type', 'النوع', 'text', [], true],
  ],
  4: [ // مكياج وعناية
    ['skin', 'مناسب لـ', 'select', ['جميع البشرة', 'بشرة دهنية', 'بشرة جافة', 'بشرة حساسة'], false],
    ['expiry', 'تاريخ الانتهاء', 'text', [], true],
  ],
  5: [ // أحذية
    ['size', 'المقاس', 'select', ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'], true],
    ['color', 'اللون', 'select', ['أسود', 'أبيض', 'بني', 'رمادي', 'بيج'], false],
  ],
  6: [ // شنط وإكسسوارات
    ['material', 'الخامة', 'text', [], true],
    ['brand', 'الشركة المصنعة', 'text', [], false],
  ],
  7: [ // مطاعم وأكل
    ['serve', 'تكفي لـ', 'text', [], true],
    ['expiry', 'تاريخ الانتهاء', 'text', [], false],
  ],
  8: [ // بقالة وسوبرماركت
    ['weight', 'الوزن / الحجم', 'text', [], true],
    ['expiry', 'تاريخ الانتهاء', 'text', [], false],
  ],
  9: [ // صيدليات
    ['prescription', 'وصفة طبية', 'select', ['بدون وصفة', 'يتطلب وصفة'], true],
    ['expiry', 'تاريخ الانتهاء', 'text', [], true],
  ],
  10: [ // إلكترونيات
    ['brand', 'الشركة المصنعة', 'text', [], true],
    ['warranty', 'مدة الضمان', 'select', ['بدون ضمان', '3 أشهر', '6 أشهر', 'سنة واحدة', 'سنتان'], true],
  ],
};

(async () => {
  console.log('⏳ إضافة سمات الأقسام...');
  await q('DELETE FROM category_attrs');
  let n = 0;
  for (const [catId, attrs] of Object.entries(ATTRS)) {
    for (const [key, label, type, options, required] of attrs) {
      await q(`INSERT INTO category_attrs (category_id, key, label, type, options, required, sort)
        VALUES ($1,$2,$3,$4,$5,$6,$7)`, [Number(catId), key, label, type, JSON.stringify(options), required, n]);
      n++;
    }
  }
  console.log(`✅ تمت إضافة ${n} سمة`);
  await pool.end();
})().catch(async (e) => { console.error('❌', e.message); await pool.end(); process.exit(1); });