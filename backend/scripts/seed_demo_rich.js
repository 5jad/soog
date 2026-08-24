// ═══════════ بذر البيانات الوهمية الغنية — متاجر ومنتجات وإعلانات وتقييمات بصور مولّدة ═══════════
// كل الصور تُولَّد بـ sharp (SVG→JPEG) وتُخزن data-URI داخل القاعدة — تعيش على Vercel بلا ملفات
// الماركر: أسماء المتاجر تبدأ "[وهمي] " وأرقام المستخدمين 000000000* — يخفيها وضع العرض من لوحة الأدمن
// التشغيل محلياً:  DATABASE_URL='postgres://zaboon@127.0.0.1:5434/zaboon' PGSSL=false node scripts/seed_demo_rich.js
// التشغيل سحابياً: node scripts/seed_demo_rich.js   (يقرأ backend/.env)

import 'dotenv/config';
import pg from 'pg';
import sharp from 'sharp';

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.PGSSL === 'false' || !process.env.DATABASE_URL?.includes('neon') ? false : { rejectUnauthorized: false },
});
const q = (t, p) => pool.query(t, p);

// ── توليد الصور ─────────────────────────────────────────────
const F = 'Noto Sans Arabic';

async function img({ w, h, c1, c2, title = '', sub = '', big = '' }) {
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const parts = [
    `<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">
      <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/>
      </linearGradient></defs>
      <rect width="${w}" height="${h}" fill="url(#g)"/>
      <circle cx="${w * 0.85}" cy="${h * 0.18}" r="${Math.min(w, h) * 0.28}" fill="#ffffff" opacity="0.08"/>
      <circle cx="${w * 0.12}" cy="${h * 0.88}" r="${Math.min(w, h) * 0.22}" fill="#ffffff" opacity="0.07"/>`,
  ];
  if (big) parts.push(`<text x="50%" y="44%" font-family="${F}" font-size="${Math.min(w, h) * 0.42}" text-anchor="middle" dominant-baseline="central">${esc(big)}</text>`);
  if (title) parts.push(`<text x="50%" y="${big ? 74 : 50}%" font-family="${F}" font-weight="800" font-size="${Math.round(w / (title.length > 18 ? 16 : 11))}" text-anchor="middle" fill="#ffffff">${esc(title)}</text>`);
  if (sub) parts.push(`<text x="50%" y="${big ? 87 : 66}%" font-family="${F}" font-size="${Math.round(w / 22)}" text-anchor="middle" fill="#ffffff" opacity="0.85">${esc(sub)}</text>`);
  parts.push('</svg>');
  return sharp(Buffer.from(parts.join(''))).jpeg({ quality: 72 }).toBuffer();
}

const uri = (buf) => `data:image/jpeg;base64,${buf.toString('base64')}`;

// لوغو متجر مربع: حرف أول الاسم بدون البادئة
async function logoImg(name, [c1, c2]) {
  const letter = name.replace('[وهمي] ', '').trim().charAt(0);
  return uri(await img({ w: 320, h: 320, c1, c2, big: letter }));
}
// غلاف متجر عريض
async function coverImg(name, tagline, [c1, c2]) {
  return uri(await img({ w: 1280, h: 420, c1, c2, title: name.replace('[وهمي] ', ''), sub: tagline }));
}

// ═══ أيقونات أقسام مرسومة SVG — librsvg ما يرندر الإيموجي الملون فنرسم رموز بيضاء بسيطة ═══
// كل أيقونة داخل مربع 600×780 وموسّطة حول (300,290)
const ICONS = {
  'ملابس': `<path fill="#fff" opacity="0.92" d="M 230 170 L 275 145 L 325 145 L 370 170 L 415 250 L 368 282 L 368 445 L 232 445 L 232 282 L 185 250 Z"/>
    <path fill="#00000022" d="M 275 145 L 300 175 L 325 145 L 300 138 Z"/>`,
  'الكترونيات': `<rect x="245" y="150" width="110" height="270" rx="22" fill="#fff" opacity="0.92"/>
    <rect x="258" y="172" width="84" height="205" rx="8" fill="#00000030"/>
    <circle cx="300" cy="400" r="9" fill="#00000040"/>`,
  'حلويات': `<path fill="#fff" opacity="0.92" d="M 225 300 Q 225 235 300 235 Q 375 235 375 300 L 375 315 L 225 315 Z"/>
    <path fill="#fff" opacity="0.75" d="M 235 325 L 365 325 L 345 440 L 255 440 Z"/>
    <circle cx="300" cy="215" r="14" fill="#fff" opacity="0.92"/>
    <circle cx="262" cy="268" r="8" fill="#00000030"/><circle cx="338" cy="268" r="8" fill="#00000030"/>`,
  'منزل': `<path fill="#fff" opacity="0.92" d="M 190 250 Q 190 225 215 225 L 385 225 Q 410 225 410 250 L 410 330 Q 410 355 385 355 L 215 355 Q 190 355 190 330 Z"/>
    <rect x="175" y="270" width="35" height="85" rx="16" fill="#fff" opacity="0.92"/>
    <rect x="390" y="270" width="35" height="85" rx="16" fill="#fff" opacity="0.92"/>
    <rect x="205" y="355" width="18" height="30" rx="6" fill="#fff" opacity="0.92"/>
    <rect x="377" y="355" width="18" height="30" rx="6" fill="#fff" opacity="0.92"/>
    <rect x="230" y="255" width="140" height="45" rx="14" fill="#00000022"/>`,
  'تجميل': `<rect x="278" y="255" width="44" height="185" rx="10" fill="#fff" opacity="0.92"/>
    <path fill="#fff" opacity="0.92" d="M 278 255 L 278 175 Q 278 158 293 158 L 300 158 L 300 255 Z"/>
    <path fill="#fff" opacity="0.75" d="M 300 158 Q 322 175 322 200 L 322 255 L 300 255 Z"/>
    <rect x="270" y="205" width="60" height="14" rx="7" fill="#00000030"/>`,
  'أطفال': `<circle cx="245" cy="205" r="34" fill="#fff" opacity="0.92"/>
    <circle cx="355" cy="205" r="34" fill="#fff" opacity="0.92"/>
    <circle cx="300" cy="290" r="95" fill="#fff" opacity="0.92"/>
    <circle cx="268" cy="278" r="11" fill="#00000045"/><circle cx="332" cy="278" r="11" fill="#00000045"/>
    <ellipse cx="300" cy="318" rx="16" ry="11" fill="#00000045"/>`,
};

// صورة منتج 3:4 — أيقونة القسم + اسم المنتج
async function prodImg(name, [c1, c2], iconKey, variant = 0) {
  const rot = [0, 8, -8][variant % 3];
  const buf = await img({ w: 600, h: 780, c1, c2 });
  const deco = Buffer.from(
    `<svg width="600" height="780" xmlns="http://www.w3.org/2000/svg">
      <circle cx="300" cy="300" r="175" fill="#ffffff" opacity="0.14"/>
      <g transform="rotate(${rot} 300 300)">${ICONS[iconKey] || ICONS['ملابس']}</g>
      <rect x="40" y="600" width="520" height="110" rx="24" fill="#000000" opacity="0.30"/>
      <text x="300" y="655" font-family="${F}" font-weight="700" font-size="${name.length > 22 ? 26 : 32}" text-anchor="middle" fill="#ffffff">${name.slice(0, 30)}</text>
    </svg>`,
  );
  return uri(await sharp(buf).composite([{ input: deco }]).jpeg({ quality: 72 }).toBuffer());
}
// بانر إعلان — أيقونة القسم كبيرة يمين والنص يسار
async function adImg(title, sub, [c1, c2], iconKey) {
  const buf = await img({ w: 1400, h: 480, c1, c2 });
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const deco = Buffer.from(
    `<svg width="1400" height="480" xmlns="http://www.w3.org/2000/svg">
      <circle cx="1130" cy="240" r="175" fill="#ffffff" opacity="0.16"/>
      <g transform="translate(830,0)">${ICONS[iconKey] || ICONS['ملابس']}</g>
      <text x="700" y="205" font-family="${F}" font-weight="800" font-size="66" text-anchor="start" direction="rtl" fill="#ffffff">${esc(title)}</text>
      <text x="700" y="285" font-family="${F}" font-size="38" text-anchor="start" direction="rtl" fill="#ffffff" opacity="0.85">${esc(sub)}</text>
    </svg>`,
  );
  return uri(await sharp(buf).composite([{ input: deco }]).jpeg({ quality: 72 }).toBuffer());
}

// ── البيانات ────────────────────────────────────────────────
const PALETTES = [
  ['#12294e', '#2563eb'], ['#7c2d12', '#f97316'], ['#4c1d95', '#a78bfa'], ['#0c4a6e', '#38bdf8'],
  ['#831843', '#f472b6'], ['#14532d', '#22c55e'], ['#581c87', '#c084fc'], ['#713f12', '#facc15'],
];

// [اسم، وسم، قسم، إيموجي، [منتجات: اسم وسعر]]
const STORES = [
  ['أزياء النخبة', 'أحدث صيحات الموضة الرجالية والنسائية', 'ملابس', '👗', [
    ['قميص كلاسيك أزرق', 25000, ['أزرق فاتح', 'أبيض', 'كحلي']], ['فستان سواريه مطرز', 85000, []],
    ['جاكيت جلد طبيعي', 120000, ['أسود', 'بني']], ['بنطلون قماش كاجوال', 35000, ['كحلي', 'رمادي']],
    ['عباية خليجية فاخرة', 75000, ['أسود', 'كحلي']], ['بدلة رسمية كاملة', 185000, ['كحلي', 'رمادي غامق']],
  ]],
  ['عالم الجوالات', 'جوالات واكسسوارات بأفضل الأسعار', 'الكترونيات', '📱', [
    ['شاحن سريع 65W', 18000, []], ['سماعة بلوتوث لاسلكية', 45000, ['أسود', 'أبيض']],
    ['كفر حماية شفاف', 7000, []], ['باور بانك 20000mAh', 38000, []],
    ['ساعة ذكية Series X', 165000, ['أسود', 'فضي']], ['كيبل نوع C مجدول', 9000, []],
  ]],
  ['حلويات الشرق', 'حلويات شرقية وغربية طازجة يومياً', 'حلويات', '🍰', [
    ['كنافة نابلسية كيلو', 22000, []], ['بقلاوة مشكلة كيلو', 30000, []],
    ['كيكة شوكولاتة وسطة', 15000, []], ['تشيز كيك فراولة', 12000, []],
    ['معمول بالتمر كيلو', 18000, []], ['دونات مشكلة دزينة', 14000, []],
  ]],
  ['بيت الأثاث', 'كل يلزم بيتك من أثاث ومستلزمات', 'منزل', '🛋️', [
    ['طقم صحون بورسلان 12 قطعة', 55000, []], ['غلاية كهربائية ستيل', 28000, []],
    ['طقم مفارش سرير مزدوج', 45000, []], ['مقلاة هوائية 5 لتر', 95000, []],
    ['سجاد صالة 3×4', 130000, []], ['طقم أكواب زجاج مزخرف', 16000, []],
  ]],
  ['لمسة تجميل', 'مستحضرات تجميل وعناية أصلية', 'تجميل', '💄', [
    ['كريم مرطب للوجه', 22000, []], ['عطر نسائي فاخر 100ml', 88000, []],
    ['طقم مكياج كامل', 65000, []], ['سيروم فيتامين سي', 34000, []],
    ['شامبو بالأرغان 500ml', 15000, []], ['أحمر شفاه مات', 12000, ['أحمر', 'وردي', 'نبيذي']],
  ]],
  ['ملعب الأطفال', 'ألعاب ومستلزمات الأطفال', 'أطفال', '🧸', [
    ['دراجة أطفال 16 إنش', 110000, ['أحمر', 'أزرق']], ['دبدوب كبير 80سم', 28000, []],
    ['مجموعة ليغو بناء', 42000, []], ['سيارة تحكم عن بعد', 55000, []],
    ['مجموعة مستلزمات مدرسية', 19000, []], ['لعبة تعليمية إلكترونية', 33000, []],
  ]],
];

const AD_TEMPLATES = [
  ['تخفيضات نهاية الأسبوع 🔥', 'خصومات توصل 50% على تشكيلة مختارة'],
  ['وصل حديثاً 📦', 'أجهزة واكسسوارات جديدة وصلت المحل'],
  ['عرض العيد 🎉', 'جهزوا هداياكم بأسعار مميزة'],
  ['توصيل مجاني 🚚', 'على الطلبات فوق 75 ألف دينار'],
];

const REVIEW_TEXTS = [
  'منتج أصلي والتوصيل كان سريع، شكراً', 'جودة ممتازة والسعر مناسب، أنصح بيها',
  'تعامل راقي والتغليف كان نظيف ومضمون', 'وصل الطلب بالوقت المحدد، خدمة حلوة',
  'أفضل محل جربته بالكوت، ما نقصت أي شي', 'السلعة مطابقة للوصف تماماً، راضي جداً',
];
const REVIEWERS = ['أبو حسين', 'زينب م.', 'مصطفى الكردي', 'نور الهدى', 'عمار س.', 'رحاف أحمد'];

// ── التنفيذ ─────────────────────────────────────────────────
const govs = await q(`SELECT id FROM governorates ORDER BY sort LIMIT 1`);
if (!govs.rows.length) { console.error('✗ ماكو محافظات — شغّل seed.js الأساسي أول'); process.exit(1); }
const govId = govs.rows[0].id;
const districts = await q(`SELECT id FROM districts WHERE governorate_id=$1 ORDER BY sort`, [govId]);
const cats = await q(`SELECT id, name FROM categories`);
const catId = (name) => cats.rows.find((c) => c.name === name)?.id ?? cats.rows[0]?.id;

let madeStores = 0, madeProducts = 0, madeAds = 0, madeReviews = 0;

for (let si = 0; si < STORES.length; si++) {
  const [name, tagline, catName, , prods] = STORES[si];
  const pal = PALETTES[si % PALETTES.length];
  const fullName = `[وهمي] ${name}`;
  const phone = `000000000${String(100 + si)}`;

  // مستخدم تاجر وهمي
  await q(
    `INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,'vendor',true,'vendor123')
     ON CONFLICT (phone) DO UPDATE SET name=EXCLUDED.name`,
    [phone, `[وهمي] مالك ${name}`],
  );
  const owner = (await q(`SELECT id FROM users WHERE phone=$1`, [phone])).rows[0].id;
  const district = districts.rows[si % districts.rows.length]?.id ?? null;

  // المتجر — ينحدّث إذا موجود
  const existing = (await q(`SELECT id FROM stores WHERE name=$1`, [fullName])).rows[0];
  let sid;
  if (existing) {
    sid = existing.id;
    await q(`UPDATE stores SET logo=$2, cover=$3, status='approved', verified=true,
        description=$4, delivery_fee=2000, free_delivery_min=75000, rating_avg=4.5, owner_id=$5
      WHERE id=$1`,
      [sid, await logoImg(fullName, pal), await coverImg(name, tagline, pal),
       `${tagline} — ${tagline.split(' ').slice(-2).join(' ')} بأفضل جودة`, owner]);
  } else {
    sid = (await q(
      `INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, cover, description,
         address, delivery_fee, free_delivery_min, open_time, close_time, verified, status, rating_avg, rating_count, lat, lng)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'الكوت — المنطقة العامة',2000,75000,'9ص','11م',true,'approved',4.5,20,$9,$10) RETURNING id`,
      [owner, govId, district, fullName, catId(catName),
       await logoImg(fullName, pal), await coverImg(name, tagline, pal),
       `${tagline} — خدمة موثوقة وتوصيل سريع لكل مناطق الكوت`,
       32.512 + (si % 4) * 0.008, 45.821 + Math.floor(si / 4) * 0.01],
    )).rows[0].id;
    await q(`INSERT INTO wallets (store_id) VALUES ($1) ON CONFLICT (store_id) DO NOTHING`, [sid]);
    madeStores++;
  }

  // المنتجات — بصورة رئيسية + صورتين إضافيتين (الموجود تنحدّث صورته)
  for (let pi = 0; pi < prods.length; pi++) {
    const [pname, price, colors] = prods[pi];
    const imgs = [
      await prodImg(pname, pal, catName, 0),
      await prodImg(pname, pal, catName, 1),
      await prodImg(pname, pal, catName, 2),
    ];
    const exists = (await q(`SELECT id FROM products WHERE store_id=$1 AND name=$2`, [sid, pname])).rows[0];
    if (exists) {
      await q(`UPDATE products SET image=$2, images=$3 WHERE id=$1`, [exists.id, imgs[0], imgs]);
      continue;
    }
    const pid = (await q(
      `INSERT INTO products (store_id, category_id, name, description, price, old_price, image, images, stock)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
      [sid, catId(catName), pname,
       `${pname} — منتج تجريبي للعرض. جودة عالية وضمان الاسترجاع خلال 3 أيام.`,
       price, Math.round(price * 1.25 / 500) * 500, imgs[0], imgs, 15 + ((pi * 7) % 20)],
    )).rows[0].id;
    // متغيرات الألوان إذا موجودة
    for (const c of colors) {
      await q(`INSERT INTO product_variants (product_id, color, name, stock) VALUES ($1,$2,$3,$4)`, [pid, c, c, 8]);
    }
    // عرض على كل منتج رابع
    if (pi % 4 === 3) await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,$2,true)`, [pid, 15 + (pi % 3) * 10]);
    madeProducts++;
  }

  // زبائن وهميين للتقييمات — وحدة تكفي لكل متجر
  const custPhone = `000000000${String(300 + si)}`;
  await q(
    `INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,'customer',true)
     ON CONFLICT (phone) DO NOTHING`,
    [custPhone, `[وهمي] ${REVIEWERS[si % REVIEWERS.length]}`],
  );
  const cuid = (await q(`SELECT id FROM users WHERE phone=$1`, [custPhone])).rows[0].id;
  const hasRev = (await q(`SELECT count(*)::int AS n FROM reviews WHERE store_id=$1 AND user_id=$2`, [sid, cuid])).rows[0].n;
  if (!hasRev) {
    for (let ri = 0; ri < 3; ri++) {
      await q(`INSERT INTO reviews (store_id, user_id, rating, comment) VALUES ($1,$2,$3,$4)`,
        [sid, cuid, 5 - (ri % 2), REVIEW_TEXTS[(si + ri) % REVIEW_TEXTS.length]]);
      madeReviews++;
    }
  }

  // إعلان نشط لبعض المتاجر — الموجود تنحدّث صورته
  if (si < AD_TEMPLATES.length) {
    const [atitle, asub] = AD_TEMPLATES[si];
    const adArt = await adImg(atitle, asub, pal, catName);
    const hasAd = (await q(`SELECT id FROM ad_requests WHERE store_id=$1 AND title=$2`, [sid, `[وهمي] ${atitle}`])).rows[0];
    if (hasAd) {
      await q(`UPDATE ad_requests SET image=$2, status='active', ends_at=now() + interval '30 days' WHERE id=$1`, [hasAd.id, adArt]);
    } else {
      await q(
        `INSERT INTO ad_requests (store_id, title, art, image, gradient, duration_days, price, status, sort, starts_at, ends_at)
         VALUES ($1,$2,'🖼',$3,$4,30,0,'active',$5,now(),now() + interval '30 days')`,
        [sid, `[وهمي] ${atitle}`, adArt, `linear-gradient(120deg,${pal[0]},${pal[1]})`, si],
      );
      madeAds++;
    }
  }
}

console.log(`✓ خلص البذر الوهمي: متاجر +${madeStores} · منتجات +${madeProducts} · إعلانات +${madeAds} · تقييمات +${madeReviews}`);
process.exit(0);
