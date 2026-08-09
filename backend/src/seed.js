import pg from 'pg';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
dotenv.config();

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const q = async (sql, p = []) => (await pool.query(sql, p)).rows;

const F = (n) => Math.round(n * 100) / 100;
const fx = (d) => `🛍️ ${d}`;

async function seed() {
  console.log('⏳ بدء التجهيز...');

  // تصفير قاعدة البيانات لضمان تكرار التشغيل بدون أخطاء (seed = حالة تجريبية نظيفة)
  await q(`TRUNCATE audit_logs, notifications, favorites, reviews, refund_requests,
    order_status_history, order_items, orders, delivery_trips, cash_reports, wallet_transactions,
    wallets, ad_requests, ad_packages, offers, product_variants, products, store_documents, stores,
    categories, addresses, cart_items, otp_codes, users, districts, governorates, settings RESTART IDENTITY CASCADE`);

  // ── المحافظات والأحياء ──
  const wasit = (await q(`INSERT INTO governorates (name, name_en, sort) VALUES ($1,$2,$3) RETURNING id`,
    ['واسط (الكوت)', 'Wasit', 1]))[0].id;
  await q(`INSERT INTO governorates (name, name_en, sort) VALUES ($1,$2,$3)`,
    ['بغداد', 'Baghdad', 2]);

  const dNames = ['مركز الكوت', 'سوق المدينة', 'حي الجهاد', 'حي النصر', 'حي السلام', 'شارع الجمهورية', 'شارع الاستقلال', 'حي الحسين'];
  for (const [i, n] of dNames.entries())
    await q(`INSERT INTO districts (governorate_id, name, sort) VALUES ($1,$2,$3)`, [wasit, n, i]);

  // ── الأقسام ──
  const cats = [
    ['ملابس رجالي', '👔'], ['ملابس نسائي', '👗'], ['أطفال وألعاب', '🧒'], ['مكياج وعناية', '💄'],
    ['أحذية', '👟'], ['شنط وإكسسوارات', '👜'], ['مطاعم وأكل', '🍔'], ['بقالة وسوبرماركت', '🛒'],
    ['صيدليات', '💊'], ['إلكترونيات', '📱'],
  ];
  const catIds = {};
  for (const [i, [n, ic]] of cats.entries()) {
    const r = (await q(`INSERT INTO categories (name, icon, sort) VALUES ($1,$2,$3) RETURNING id`, [n, ic, i]))[0];
    catIds[n] = r.id;
  }

  // ── سمات الأقسام (كل قسم له سماته الخاصة) ──
  const ATTRS = {
    'ملابس رجالي': [['size','المقاس','select',['S','M','L','XL','XXL'],true], ['color','اللون','select',['أسود','أبيض','كحلي','رمادي','بيج','أخضر'],false]],
    'ملابس نسائي': [['size','المقاس','select',['S','M','L','XL','XXL'],true], ['color','اللون','select',['أسود','أبيض','وردي','بيج','بني','عنابي'],false]],
    'أطفال وألعاب': [['age','الفئة العمرية','select',['0-1 سنة','1-3 سنوات','3-6 سنوات','6-12 سنة','12+ سنة'],true], ['type','النوع','text',[],true]],
    'مكياج وعناية': [['skin','مناسب لـ','select',['جميع البشرة','بشرة دهنية','بشرة جافة','بشرة حساسة'],false], ['expiry','تاريخ الانتهاء','text',[],true]],
    'أحذية': [['size','المقاس','select',['36','37','38','39','40','41','42','43','44','45','46'],true], ['color','اللون','select',['أسود','أبيض','بني','رمادي','بيج'],false]],
    'شنط وإكسسوارات': [['material','الخامة','text',[],true], ['brand','الشركة المصنعة','text',[],false]],
    'مطاعم وأكل': [['serve','تكفي لـ','text',[],true], ['expiry','تاريخ الانتهاء','text',[],false]],
    'بقالة وسوبرماركت': [['weight','الوزن / الحجم','text',[],true], ['expiry','تاريخ الانتهاء','text',[],false]],
    'صيدليات': [['prescription','وصفة طبية','select',['بدون وصفة','يتطلب وصفة'],true], ['expiry','تاريخ الانتهاء','text',[],true]],
    'إلكترونيات': [['brand','الشركة المصنعة','text',[],true], ['warranty','مدة الضمان','select',['بدون ضمان','3 أشهر','6 أشهر','سنة واحدة','سنتان'],true]],
  };
  let attrSort = 0;
  for (const [cName, attrs] of Object.entries(ATTRS)) {
    for (const [key, label, type, options, required] of attrs)
      await q(`INSERT INTO category_attrs (category_id, key, label, type, options, required, sort)
        VALUES ($1,$2,$3,$4,$5,$6,$7)`, [catIds[cName], key, label, type, JSON.stringify(options), required, attrSort++]);
  }

  // ── المستخدمون ──
  const adminHash = await bcrypt.hash('admin123', 10);
  const vendorHash = await bcrypt.hash('vendor123', 10);
  const admin = (await q(`INSERT INTO users (phone, name, role, password) VALUES ($1,$2,$3,$4) RETURNING id`,
    ['07900000000', 'أدمن زبون', 'admin', adminHash]))[0].id;

  const customer = (await q(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,$3,$4) RETURNING id`,
    ['07731234567', 'حجي علي', 'customer', true]))[0].id;

  const vendorAli = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    ['07701112233', 'أبو علي — الأصيل', 'vendor', true, vendorHash]))[0].id;
  const vendorNoor = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    ['07702223344', 'أم نور — بوتيك النور', 'vendor', true, vendorHash]))[0].id;
  const vendorTofola = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    ['07703334455', 'أبو محمد — طفولة', 'vendor', true, vendorHash]))[0].id;
  const vendorLamsa = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    ['07704445566', 'لمسة', 'vendor', false, vendorHash]))[0].id;

  const courier = (await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    ['07705556677', 'حسين — المندوب', 'delivery', true, vendorHash]))[0].id;

  // ── حسابات العرض على شاشة تسجيل الدخول (000000000100/200/300 · 123456) ──
  const demoHash = await bcrypt.hash('123456', 10);
  for (const [dphone, dname, drole] of [
    ['000000000100', 'تاجر تجريبي', 'vendor'],
    ['000000000200', 'زبون تجريبي', 'customer'],
    ['000000000300', 'مندوب تجريبي', 'delivery'],
  ]) await q(`INSERT INTO users (phone, name, role, verified, password) VALUES ($1,$2,$3,true,$4) ON CONFLICT (phone) DO NOTHING`,
    [dphone, dname, drole, demoHash]);

  // محل جاهز للتاجر التجريبي (يملكه مباشرة — لا يحتاج تسجيل/توثيق)
  const demoVendor = await one(`SELECT id FROM users WHERE phone='000000000100'`);
  const demoGov = await one(`SELECT id FROM governorates WHERE is_active ORDER BY id LIMIT 1`);
  const demoStore = (await q(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, cover, description, address, delivery_fee, open_time, close_time, verified, status, rating_avg, rating_count)
    VALUES ($1,$2,1,'متجر التجريبي',$3,'🏪','linear-gradient(120deg,#1D4ED8,#38BDF8)','محل تجريبي جاهز للنشر','سوق المدينة، الكوت',2000,0,'7ص',true,'approved',4.0,12)
    ON CONFLICT DO NOTHING RETURNING id`, [demoVendor.id, demoGov.id, null]))[0];
  if (demoStore) await q(`INSERT INTO wallets (store_id) VALUES ($1)`, [demoStore.id]);

  // ── المتاجر ──
  const store = async (owner, name, cat, logo, cover, addr, district, desc, fee, open, verified, status) => {
    const r = (await q(`INSERT INTO stores (owner_id, governorate_id, district_id, name, category_id, logo, cover, description, address, delivery_fee, open_time, close_time, verified, status, rating_avg, rating_count)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,0,0) RETURNING id`,
      [owner, wasit, district, name, catIds[cat], logo, cover, desc, addr, fee, open, '11ل', verified, status]))[0];
    await q(`INSERT INTO wallets (store_id) VALUES ($1)`, [r.id]);
    return r.id;
  };

  const dCenter = 1, dSouq = 2, dJihad = 3, dNasr = 4, dSalam = 5, dJomhoria = 6, dIstiqlal = 7, dHussein = 8;

  const alAsil = await store(vendorAli, 'الأصيل — ملابس رجالي', 'ملابس رجالي', '/uploads/stores/s1.jpg',
    'linear-gradient(120deg,#1D4ED8,#38BDF8)', 'سوق المدينة، الكوت', dSouq,
    'ملابس رجالية راقية: قمصان، سراويل، جاكيتات. جودة تضمن الراحة.', 2000, '9ص', true, 'approved');
  await q(`UPDATE stores SET rating_avg=$1, rating_count=$2 WHERE id=$3`, [4.8, 180, alAsil]);

  const boutikNoor = await store(vendorNoor, 'بوتيك النور — نسائي', 'ملابس نسائي', '/uploads/stores/s2.jpg',
    'linear-gradient(120deg,#9D174D,#F97316)', 'شارع الوحدة، الكوت', dCenter,
    'فساتين سهرة، شنط، إكسسوارات — أحدث الأزياء.', 2000, '10ص', true, 'approved');
  await q(`UPDATE stores SET rating_avg=$1, rating_count=$2 WHERE id=$3`, [4.9, 210, boutikNoor]);

  const tofola = await store(vendorTofola, 'طفولة — أطفال وألعاب', 'أطفال وألعاب', '/uploads/stores/s3.jpg',
    'linear-gradient(120deg,#15803D,#06B6D4)', 'حي النصر، الكوت', dNasr,
    'ملابس أطفال وألعاب تعليمية آمنة.', 1500, '9ص', true, 'approved');
  await q(`UPDATE stores SET rating_avg=$1, rating_count=$2 WHERE id=$3`, [4.7, 95, tofola]);

  const lamsa = await store(vendorLamsa, 'لمسة — مكياج وعناية', 'مكياج وعناية', '/uploads/stores/s4.jpg',
    'linear-gradient(120deg,#B45309,#F5A623)', 'شارع الجمهورية، الكوت', dJomhoria,
    'مكياج وعطور ومنتجات عناية بالبشرة أصلية.', 0, '10ص', false, 'pending');

  const style = await store(vendorAli, 'ستايل — أحذية', 'أحذية', '/uploads/stores/s5.jpg',
    'linear-gradient(120deg,#B45309,#F5A623)', 'سوق المدينة، الكوت', dSouq,
    'أحذية رجالية ونسائية أصلية.', 1500, '9ص', true, 'approved');
  await q(`UPDATE stores SET rating_avg=$1, rating_count=$2 WHERE id=$3`, [4.5, 66, style]);

  // ── المنتجات ──
  const prod = async (storeId, cat, name, price, old, img, desc, avail = true) => {
    const r = (await q(`INSERT INTO products (store_id, category_id, name, price, old_price, image, description, is_available, stock)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`, [storeId, catIds[cat], name, price, old || null, img, desc, avail, 15]))[0];
    return r.id;
  };
  const variant = async (pid, name, stock) =>
    (await q(`INSERT INTO product_variants (product_id, name, stock) VALUES ($1,$2,$3) RETURNING id`, [pid, name, stock]))[0].id;

  // الأصيل
  let p = await prod(alAsil, 'ملابس رجالي', 'قميص رجالي قطني', 18000, 25000, '/uploads/products/p01.jpg', 'قطن مصري 100%، مقاسات S–XXL');
  await variant(p, 'S', 4); await variant(p, 'M', 7); await variant(p, 'L', 3); await variant(p, 'XL', 6);
  await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,30,true)`, [p]);
  p = await prod(alAsil, 'ملابس رجالي', 'جاكيت شتوي فاخر', 55000, 65000, '/uploads/products/p02.jpg', 'مقاوم للماء، مقاسات M–XXL');
  await variant(p, 'M', 2); await variant(p, 'L', 0); await variant(p, 'XL', 5);
  await q(`INSERT INTO offers (product_id, percent, active) VALUES ($1,20,true)`, [p]);
  p = await prod(alAsil, 'ملابس رجالي', 'سروال جينز كلاسيك', 28000, null, '/uploads/products/p03.jpg', 'مقاس 30–42');
  await variant(p, '30', 2); await variant(p, '32', 8); await variant(p, '34', 5); await variant(p, '36', 4);
  p = await prod(alAsil, 'ملابس رجالي', 'ساعة يد رياضية', 42000, null, '/uploads/products/p04.jpg', 'ستيل + جلد');
  await variant(p, 'قياسي', 0);

  // بوتيك النور
  p = await prod(boutikNoor, 'ملابس نسائي', 'فستان سهرة أنيق', 45000, 60000, '/uploads/products/p05.jpg', 'فستان سهرة فخم');
  await variant(p, 'S', 5); await variant(p, 'M', 8); await variant(p, 'L', 4);
  p = await prod(boutikNoor, 'ملابس نسائي', 'شنطة يد جلد', 38000, null, '/uploads/products/p06.jpg', 'جلد طبيعي');
  p = await prod(boutikNoor, 'ملابس نسائي', 'بلوزة حرير', 22000, null, '/uploads/products/p07.jpg', 'حرير ناعم');
  await variant(p, 'S', 6); await variant(p, 'M', 6); await variant(p, 'L', 3);

  // طفولة
  p = await prod(tofola, 'أطفال وألعاب', 'لعبة تعليمية خشبية', 15000, null, '/uploads/products/p08.jpg', 'تعليمية وآمنة');
  p = await prod(tofola, 'أطفال وألعاب', 'طقم ملابس أطفال', 12000, null, '/uploads/products/p09.jpg', 'قطن');
  await variant(p, '2Y', 4); await variant(p, '4Y', 5);

  // لمسة
  p = await prod(lamsa, 'مكياج وعناية', 'طقم مكياج كامل', 60000, null, '/uploads/products/p10.jpg', 'بالتقسيط المريح');
  p = await prod(lamsa, 'مكياج وعناية', 'عطر فرنسي', 45000, 55000, '/uploads/products/p11.jpg', 'عطر أصلي');

  // ستايل
  p = await prod(style, 'أحذية', 'حذاء رياضي أزرق', 35000, null, '/uploads/products/p12.jpg', 'مريح للجري', false);
  p = await prod(style, 'أحذية', 'صندل جلد', 18000, null, '/uploads/products/p13.jpg', 'جلد طبيعي');
  await variant(p, '40', 4); await variant(p, '41', 5); await variant(p, '42', 3);

  // ── مستندات التوثيق ──
  await q(`INSERT INTO store_documents (store_id, type, title, status) VALUES ($1,$2,$3,$4)`,
    [alAsil, 'license', 'رخصة العمل', 'approved']);
  await q(`INSERT INTO store_documents (store_id, type, title, status) VALUES ($1,$2,$3,$4)`,
    [alAsil, 'commercial', 'السجل التجاري', 'approved']);
  await q(`INSERT INTO store_documents (store_id, type, title, status, reviewed_by, reviewed_at) VALUES ($1,$2,$3,$4,$5,now())`,
    [alAsil, 'electricity', 'فاتورة الكهرباء', 'pending', admin]);
  await q(`INSERT INTO store_documents (store_id, type, title, status) VALUES ($1,$2,$3,$4)`,
    [lamsa, 'license', 'رخصة العمل', 'pending']);

  // ── الإعلانات ──
  const now = new Date();
  await q(`INSERT INTO ad_requests (store_id, title, art, gradient, duration_days, price, status, starts_at, ends_at, sort) VALUES
    ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [alAsil, 'تشكيلة الشتاء 🔥 خصم حتى 40%', '🧥', 'linear-gradient(120deg,#1E3A8A,#06B6D4)', 7, 25000, 'active',
      now, new Date(now.getTime() + 4 * 864e5), 1]);
  await q(`INSERT INTO ad_requests (store_id, title, art, gradient, duration_days, price, status, starts_at, ends_at, sort) VALUES
    ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [boutikNoor, 'فساتين السهرة الجديدة ✨', '👗', 'linear-gradient(120deg,#9D174D,#F97316)', 7, 35000, 'active',
      now, new Date(now.getTime() + 5 * 864e5), 2]);
  await q(`INSERT INTO ad_requests (store_id, title, art, gradient, duration_days, price, status) VALUES
    ($1,$2,$3,$4,$5,$6,$7)`,
    [tofola, 'عروض الألعاب 🧸 خصم 25%', '🧸', 'linear-gradient(120deg,#15803D,#38BDF8)', 14, 40000, 'pending']);

  // ── عنوان الزبون ──
  await q(`INSERT INTO addresses (user_id, district_id, label, details, is_default) VALUES ($1,$2,$3,$4,true)`,
    [customer, dJihad, 'البيت', 'حي الجهاد، قرب مسجد النور، عمارة 7']);

  // ── طلب تجريبي ──
  const o = (await q(`INSERT INTO orders (code, user_id, store_id, courier_id, status, subtotal, delivery_fee, discount, total, address_text, created_at)
    VALUES ('ZB-1042',$1,$2,$3,'delivering',71000,2000,0,73000,$4, now() - interval '3 hours') RETURNING id`,
    [customer, alAsil, courier, 'حي الجهاد، قرب مسجد النور']))[0];
  await q(`INSERT INTO order_items (order_id, name, variant, price, qty) VALUES ($1,$2,$3,$4,$5)`,
    [o.id, 'قميص رجالي قطني', 'M', 18000, 1]);
  await q(`INSERT INTO order_items (order_id, name, variant, price, qty) VALUES ($1,$2,$3,$4,$5)`,
    [o.id, 'جاكيت شتوي فاخر', 'L', 55000, 1]);
  await q(`INSERT INTO delivery_trips (order_id, courier_id) VALUES ($1,$2)`, [o.id, courier]);
  for (const [from, to] of [['new','preparing'],['preparing','ready'],['ready','delivering']])
    await q(`INSERT INTO order_status_history (order_id, from_status, to_status, by_role) VALUES ($1,$2,$3,$4)`,
      [o.id, from, to, from === 'ready' ? 'delivery' : 'vendor']);

  // ── محافظ رصيد وهمي ──
  await q(`UPDATE wallets SET available=2847500, pending=486000 WHERE store_id=$1`, [alAsil]);
  await q(`INSERT INTO wallet_transactions (store_id, type, amount, note) VALUES ($1,'withdraw',900000,'استلام نقدي 5/8')`, [alAsil]);

  // ── الإشعارات ──
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'delivery','مندوبك بوصلك بعد 12 دقيقة','طلب #ZB-1042 — الأصيل • الكاش 73,000 د.ع')`, [customer]);
  await q(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ad','إعلانك انقبل من المشرف ✓','تشكيلة الشتاء يعرض بالواجهة الرئيسية')`, [vendorAli]);
  await q(`INSERT INTO notifications (role, type, title, body) VALUES ('admin','ad','طلب إعلان جديد — طفولة','14 أيام — 40,000 د.ع • بانتظار موافقتك')`);
  await q(`INSERT INTO notifications (role, type, title, body) VALUES ('admin','cash','المندوب حسين سلّم الكاش','186,500 د.ع قيد المراجعة')`);

  // ── عملاء إضافيون للتقييمات ──
  const c1 = (await q(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,$3,$4) RETURNING id`, ['07761112233', 'أم حسين', 'customer', true]))[0].id;
  const c2 = (await q(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,$3,$4) RETURNING id`, ['07762223344', 'أبو كرار', 'customer', true]))[0].id;
  const c3 = (await q(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,$3,$4) RETURNING id`, ['07763334455', 'زهراء', 'customer', true]))[0].id;
  const c4 = (await q(`INSERT INTO users (phone, name, role, verified) VALUES ($1,$2,$3,$4) RETURNING id`, ['07764445566', 'مصطفى', 'customer', true]))[0].id;

  // ── تقييمات وتعليقات (تظهر في صفحة المنتج والمحل) ──
  const review = async (storeId, userId, rating, comment, daysAgo) =>
    await q(`INSERT INTO reviews (store_id, user_id, rating, comment, created_at) VALUES ($1,$2,$3,$4, now() - $5::int * interval '1 day')`,
      [storeId, userId, rating, comment, daysAgo]);
  await review(alAsil, customer, 5, 'ملابس طقطق وراقية، والتوصيل كان سريع 🔥', 1);
  await review(alAsil, c1, 4, 'خامة القميص ممتازة بس المقاسات أكبر شوية', 3);
  await review(alAsil, c2, 5, 'أفضل محل ملابس رجالية بالكوت، أراجعهم دائماً', 6);
  await review(alAsil, c3, 4, 'الأسعار مناسبة والجودة زينة', 12);
  await review(alAsil, c4, 5, 'الساعة الرياضية أصلية والتغليف راقي', 20);
  await review(boutikNoor, customer, 5, 'الفستان مثل الصورة بالضبط، أخذته للمناسبة وشكروني عليه 🌟', 2);
  await review(boutikNoor, c1, 5, 'أحدث الأزياء وأذواق راقية، الشنطة جلد طبيعي فعلاً', 5);
  await review(boutikNoor, c2, 4, 'البلوزة حرير ناعم، بس التوصيل تأخر يوم', 9);
  await review(tofola, customer, 5, 'اللعبة الخشبية تعليمية وآمنة، ولدي ما يفاركها 🧸', 4);
  await review(tofola, c3, 5, 'ملابس الأطفال قطن مريح ومقاسات مضبوطة', 15);
  await review(style, c4, 4, 'الحذاء مريح والأسعار معقولة', 7);

  // ── الإعدادات ──
  const settings = [
    ['platform_name', 'زبون'],
    ['platform_slogan', 'كل ما تتمناه — بمكان واحد'],
    ['governorate_name', 'واسط (الكوت)'],
    ['commission_rate', '10'],
    ['courier_rate', '5'],
    ['ad_price_3d', '15000'],
    ['ad_price_7d', '25000'],
    ['ad_price_14d', '40000'],
    ['refund_days', '7'],
    ['free_delivery_min', '50000'],
    ['daily_goal', '5000000'],
  ];
  for (const [k, v] of settings) await q(`INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO NOTHING`, [k, v]);

  console.log(`✅ تم التجهيز:
  ─ الأدمن:   هاتف 07900000000 / كلمة السر admin123
  ─ زبون:     07731234567 (OTP تجريبي)
  ─ تاجر:     07701112233 (الأصيل)
  ─ مندوب:    07705556677 (حسين)
  ─ محافظات:  واسط (الكوت) + بغداد — جاهز للتوسعة`);
  await pool.end();
}

seed().catch(async (e) => { console.error('❌', e.message); await pool.end(); process.exit(1); });
