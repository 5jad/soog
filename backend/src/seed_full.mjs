import pg from 'pg';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
dotenv.config({ path: '/home/max/Desktop/project2/backend/.env' });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false }, max: 6 });
const q = async (sql, p = []) => (await pool.query(sql, p)).rows;
const one = async (sql, p = []) => (await pool.query(sql, p)).rows[0] || null;
const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const KUT = { lat: 32.512, lng: 45.818 };
const agoDays = (d) => new Date(Date.now() - d * 86400000);
const inDays = (d) => new Date(Date.now() + d * 86400000);

let B = [];
const add = (r) => B.push(r);
const flush = async (table, cols) => {
  if (!B.length) return 0;
  let n = 0;
  for (let i = 0; i < B.length; i += 25) {
    const chunk = B.slice(i, i + 25);
    const ph = chunk.map((_, r) => `(${cols.map((_, c) => `$${r * cols.length + c + 1}`).join(',')})`).join(',');
    await pool.query(`INSERT INTO ${table} (${cols.join(',')}) VALUES ${ph}`, chunk.flat());
    n += chunk.length;
  }
  B = [];
  return n;
};

async function seed() {
  console.log('⏳ توليد البيانات المتكاملة (دفعات سريعة)...');
  await q(`TRUNCATE audit_logs, notifications, favorites, reviews, refund_requests,
    order_status_history, order_items, orders, delivery_trips, delivery_track_log, trip_orders,
    cash_reports, wallet_transactions, wallets, ad_requests, ad_packages, offers, product_variants,
    products, store_documents, stores, cart_items, otp_codes, users,
    conversations, messages, product_questions, spin_wins, coupon_usages, coupons,
    store_favorites, point_transactions, phone_verifications, telegram_bindings, telegram_links,
    category_attrs, categories, addresses, districts, governorates, settings RESTART IDENTITY CASCADE`);

  // ═══ 1) المرجعيات ═══
  const govList = [
    ['واسط (الكوت)', 'Wasit', 1, ['مركز الكوت', 'سوق المدينة', 'حي الجهاد', 'حي النصر', 'حي السلام', 'شارع الجمهورية', 'شارع الاستقلال', 'حي الحسين', 'حي الوحدة', 'شارع الوحدة']],
    ['بغداد', 'Baghdad', 2, ['الكرادة', 'المنصور', 'الأعظمية', 'زيونة']],
    ['البصرة', 'Basra', 3, ['العشار', 'الجزائر', 'كرمة علي']],
    ['النجف', 'Najaf', 4, ['الغري', 'المنطقة الصناعية', 'حي السلام']],
    ['أربيل', 'Erbil', 5, ['شارع 60م', 'عناوة', 'الإنكليزي']],
  ];
  const govs = {};
  for (const [i, [name, en, sort]] of govList.entries()) { govs[name] = i + 1; }
  for (const [gid, g] of govList.entries()) add([gid + 1, g[0], g[1], g[2]]);
  await flush('governorates', ['id', 'name', 'name_en', 'sort']);
  const districts = [];
  govList.forEach((g, gid) => g[3].forEach((d, i) => add([gid + 1, d, i])));
  await flush('districts', ['governorate_id', 'name', 'sort']);
  const dists = await q(`SELECT id, name, governorate_id FROM districts ORDER BY id`);
  const wasit = dists.filter(d => d.governorate_id === govs['واسط (الكوت)']);
  const di = (arr, i) => arr[i % arr.length].id;

  const cats = [
    ['ملابس رجالي', '👔'], ['ملابس نسائي', '👗'], ['أطفال وألعاب', '🧒'], ['مكياج وعناية', '💄'],
    ['أحذية', '👟'], ['شنط وإكسسوارات', '👜'], ['مطاعم وأكل', '🍔'], ['بقالة وسوبرماركت', '🛒'],
    ['صيدليات', '💊'], ['إلكترونيات', '📱'], ['عطور وهدايا', '🏺'], ['قرطاسية وكتب', '📚'],
  ];
  const catIds = {};
  cats.forEach((c, i) => catIds[c[0]] = i + 1);
  cats.forEach((c, i) => add([i + 1, c[0], c[1], i]));
  await flush('categories', ['id', 'name', 'icon', 'sort']);

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
    'عطور وهدايا': [['volume','الحجم','text',[],true], ['brand','الشركة المصنعة','text',[],false]],
    'قرطاسية وكتب': [['brand','الشركة المصنعة','text',[],true], ['pages','عدد الصفحات','text',[],false]],
  };
  let aS = 0;
  for (const [cName, attrs] of Object.entries(ATTRS))
    for (const [key, label, type, options, required] of attrs)
      add([catIds[cName], key, label, type, JSON.stringify(options), required, aS++]);
  await flush('category_attrs', ['category_id', 'key', 'label', 'type', 'options', 'required', 'sort']);

  const settings = [
    ['platform_name','زبون'], ['platform_slogan','كل ما تتمناه — بمكان واحد'], ['governorate_name','واسط (الكوت)'],
    ['commission_rate','10'], ['courier_rate','5'], ['ad_price_3d','15000'], ['ad_price_7d','25000'],
    ['ad_price_14d','40000'], ['refund_days','7'], ['free_delivery_min','50000'], ['daily_goal','5000000'],
    ['demo_mode','shown'], ['whatsapp','077269029243'], ['support_phone','077269029243'],
  ];
  await q(`INSERT INTO settings (key, value) VALUES ${settings.map((_, i) => `($${i * 2 + 1},$${i * 2 + 2})`).join(',')} ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value`, settings.flat());
  for (const [days, price] of [[3, 15000], [7, 25000], [14, 40000]]) add([days, price, true]);
  await flush('ad_packages', ['days', 'price', 'active']);

  // ═══ 2) المستخدمون ═══
  const PH = '077269029243', PC = '077269029241', PV = '077269029242';
  const adminPass = await bcrypt.hash('$/Sa/13#', 10);
  const demoPass = await bcrypt.hash('123456', 10);
  const userRows = [
    [PH, 'أدمن زبون', 'admin', adminPass, true],
    [PC, 'مندوب زبون', 'delivery', adminPass, true],
    [PV, 'تاجر زبون', 'vendor', adminPass, true],
    ['000000000100', 'تاجر تجريبي', 'vendor', demoPass, true],
    ['000000000200', 'زبون تجريبي', 'customer', demoPass, true],
    ['000000000300', 'مندوب تجريبي', 'delivery', demoPass, true],
  ];
  const vendors = [
    ['أبو علي', 'الأصيل — ملابس رجالي', '👔', 'ملابس رجالي', 'أرقى الملابس الرجالية: قمصان، بدلات، جاكيتات', 4.8, 187, 2000, 'approved', true],
    ['أم نور', 'بوتيك النور — نسائي', '👗', 'ملابس نسائي', 'فساتين سهرة وأزياء موضة بأجود الأقمشة', 4.9, 214, 2000, 'approved', true],
    ['أبو محمد', 'طفولة — أطفال وألعاب', '🧸', 'أطفال وألعاب', 'ملابس أطفال قطنية وألعاب تعليمية آمنة', 4.7, 98, 1500, 'approved', true],
    ['لمسة', 'لمسة — مكياج وعناية', '💄', 'مكياج وعناية', 'مكياج وعطور ومنتجات عناية أصلية', 0, 0, 2000, 'pending', false],
    ['أبو حسين', 'حذاء الشام — أحذية', '👟', 'أحذية', 'أحذية أصلية بكل المقاسات', 4.5, 66, 1500, 'approved', true],
    ['عبير', 'عبير — شنط وإكسسوارات', '👜', 'شنط وإكسسوارات', 'شنط يد جلد طبيعي وإكسسوارات راقية', 4.6, 54, 2000, 'approved', true],
    ['أبو ياسر', 'مطعم الفرات الشعبي', '🍢', 'مطاعم وأكل', 'كباب ومسكوف على الفحم، أكل بيتي طازج', 4.4, 132, 3000, 'approved', true],
    ['حيدر', 'بستان الكوت — بقالة', '🛒', 'بقالة وسوبرماركت', 'كل احتياجات بيتك بأسعار منافسة', 4.3, 89, 1000, 'approved', true],
    ['صيدلانية رنا', 'صيدلية الشفاء', '💊', 'صيدليات', 'أدوية ومستحضرات أصلية بإشراف صيدلاني', 4.8, 45, 2000, 'approved', true],
    ['كرار', 'تكنا سنتر — إلكترونيات', '📱', 'إلكترونيات', 'هواتف وأجهزة كهربائية أصلية مع ضمان سنة', 4.2, 71, 2500, 'approved', true],
    ['أمجاد', 'عطور الأصالة', '🏺', 'عطور وهدايا', 'عطور أصلية وهدايا فاخرة من أشهر الماركات', 4.7, 38, 2000, 'approved', true],
    ['أبو سجاد', 'مكتبة المعارف', '📚', 'قرطاسية وكتب', 'كتب وقرطاسية ولوازم مدرسية', 3.9, 12, 1000, 'suspended', true],
  ];
  vendors.forEach((v, i) => userRows.push([`077200011${String(i).padStart(2, '0')}`, v[0], 'vendor', demoPass, true]));
  const courierNames = ['حسين', 'علي', 'كرار', 'سجاد', 'حمزة', 'مصطفى', 'نور'];
  courierNames.forEach((n, i) => userRows.push([`0770555${String(6670 + i)}`, `مندوب — ${n}`, 'delivery', demoPass, true]));
  const custNames = ['حجي علي', 'أم حسين', 'أبو كرار', 'زهراء', 'مصطفى', 'نور الهدى', 'كرار حسن', 'فاطمة كاظم',
    'علي حسين', 'سارة محمد', 'محمد جاسم', 'رقية صادق', 'حسام عبد', 'زينب علي', 'أحمد عباس', 'منى خالد',
    'حسنين جواد', 'رنا سمير', 'عباس مهدي', 'دلال ناصر', 'كاظم فاضل', 'يسرى عامر', 'عمر عادل', 'حوراء جعفر',
    'صادق كريم', 'ايناس رعد', 'قاسم صباح', 'ليلى حميد'];
  custNames.forEach((n, i) => userRows.push([`0776${String(1000000 + i * 7919).slice(0, 7)}`, n, 'customer', demoPass, true]));
  for (let i = 0; i < 6; i++) userRows.push([`0777${String(500000 + i * 13).slice(0, 7)}`, `ضيف — زائر ${i + 1}`, 'customer', null, false]);
  userRows.forEach(u => add(u));
  await flush('users', ['phone', 'name', 'role', 'password', 'verified']);
  const byPhone = {};
  for (const u of await q(`SELECT id, phone FROM users`)) byPhone[u.phone] = u.id;
  const admin = byPhone[PH], myCourier = byPhone[PC], myVendor = byPhone[PV];
  const demoVendor = byPhone['000000000100'], demoCustomer = byPhone['000000000200'], demoCourier = byPhone['000000000300'];
  const couriers = courierNames.map((_, i) => byPhone[`0770555${String(6670 + i)}`]);
  couriers.push(myCourier, demoCourier);
  const customers = custNames.map((_, i) => byPhone[`0776${String(1000000 + i * 7919).slice(0, 7)}`]);
  const guests = Array.from({ length: 6 }, (_, i) => byPhone[`0777${String(500000 + i * 13).slice(0, 7)}`]);
  customers.push(demoCustomer);

  // ═══ 3) المتاجر ═══
  const GRADS = ['linear-gradient(120deg,#1D4ED8,#38BDF8)', 'linear-gradient(120deg,#9D174D,#F97316)', 'linear-gradient(120deg,#15803D,#06B6D4)', 'linear-gradient(120deg,#B45309,#F5A623)', 'linear-gradient(120deg,#1E3A8A,#06B6D4)'];
  const PLACES = ['الجسر الكبير', 'ساحة التربية', 'مستشفى الكوت', 'جامعة واسط'];
  const storeIds = [];
  for (const [i, v] of vendors.entries()) {
    const uid = byPhone[`077200011${String(i).padStart(2, '0')}`];
    const lat = KUT.lat + rnd(-30, 30) * 0.001, lng = KUT.lng + rnd(-30, 30) * 0.001;
    add([i + 1, uid, govs['واسط (الكوت)'], di(wasit, i), v[1], catIds[v[3]], v[2], pick(GRADS), v[4],
      `سوق المدينة، الكوت — قرب ${pick(PLACES)}`, lat, lng,
      `https://www.google.com/maps/search/?api=1&query=${lat.toFixed(6)},${lng.toFixed(6)}`, `0772001${String(20 + i)}`,
      v[7], 50000, v[8] === 'pending' ? '10ص' : '9ص', '11ل', true, v[8], v[9], 10.0, v[5], v[6], 3]);
    storeIds.push(i + 1);
  }
  const myStore = 13, demoStore = 14;
  add([myStore, myVendor, govs['واسط (الكوت)'], di(wasit, 1), 'متجر التاجر — أزياء راقية', catIds['ملابس رجالي'],
    '🧥', 'linear-gradient(120deg,#1E3A8A,#06B6D4)', 'ملابس رجالية أصلية — إرجاع مجاني خلال 3 أيام',
    'سوق المدينة، الكوت — مجاور ساحة التربية', 32.51, 45.82,
    'https://www.google.com/maps/search/?api=1&query=32.510000,45.820000', PV, 2000, 50000, '9ص', '11ل', true, 'approved', true, 10.0, 4.9, 156, 3]);
  add([demoStore, demoVendor, govs['واسط (الكوت)'], di(wasit, 1), 'متجر التجريبي', catIds['إلكترونيات'],
    '🏪', 'linear-gradient(120deg,#1D4ED8,#38BDF8)', 'محل تجريبي جاهز للتجربة', 'سوق المدينة، الكوت', 32.505, 45.825,
    '', '000000000100', 2000, 50000, '9ص', '11ل', true, 'approved', true, 10.0, 4.5, 40, 3]);
  storeIds.push(myStore, demoStore);
  await flush('stores', ['id', 'owner_id', 'governorate_id', 'district_id', 'name', 'category_id', 'logo', 'cover', 'description', 'address', 'lat', 'lng', 'location_url', 'phone', 'delivery_fee', 'free_delivery_min', 'open_time', 'close_time', 'is_open', 'status', 'verified', 'commission_rate', 'rating_avg', 'rating_count', 'warranty_days']);
  storeIds.forEach(sid => add([sid, 0, 0]));
  await flush('wallets', ['store_id', 'available', 'pending']);
  vendors.forEach((v, i) => { if (i % 3 === 0) add([i + 1, 'license', 'رخصة العمل', 'approved']); });
  add([1, 'commercial', 'السجل التجاري', 'approved']);
  add([4, 'license', 'رخصة العمل', 'pending']);
  add([myStore, 'license', 'رخصة العمل', 'approved']);
  await flush('store_documents', ['store_id', 'type', 'title', 'status']);

  // ═══ 4) المنتجات ═══
  const SETS = {
    'ملابس رجالي': [['قميص قطني مصري', 18000, 25000], ['جاكيت شتوي فاخر', 55000, 65000], ['سروال جينز كلاسيك', 28000, null], ['بدلة رجالية سوداء', 120000, 145000], ['ساعة يد رياضية', 42000, null], ['حزام جلد طبيعي', 12000, null], ['نظارة شمسية', 15000, 20000], ['كاب قماش', 8000, null]],
    'ملابس نسائي': [['فستان سهرة أنيق', 45000, 60000], ['بلوزة حرير', 22000, null], ['عباية خليجية', 38000, null], ['جاكيت نسائي', 48000, 58000], ['تنورة طويلة', 19000, null], ['حزام نسائي', 9000, null]],
    'أطفال وألعاب': [['لعبة تعليمية خشبية', 15000, null], ['طقم ملابس أطفال', 12000, null], ['دمية محشوة', 18000, 24000], ['سيارة أطفال كهربائية', 85000, 99000], ['ألوان خشبية 24', 6000, null], ['لعبة تركيب ليغو', 22000, null]],
    'مكياج وعناية': [['طقم مكياج كامل', 60000, null], ['عطر فرنسي أصلي', 45000, 55000], ['كريم ترطيب', 14000, null], ['ماسكارا', 8000, null], ['مجموعة فرش', 16000, null], ['أحمر شفاه', 7000, null]],
    'أحذية': [['حذاء رياضي أزرق', 35000, null], ['صندل جلد', 18000, null], ['حذاء كاجوال', 26000, 32000], ['حذاء نسائي كعب', 30000, null], ['شباشب بيتي', 9000, null], ['حذاء مدرسي', 14000, null]],
    'شنط وإكسسوارات': [['شنطة يد جلد', 38000, null], ['محفظة رجالية', 12000, null], ['نظارة ماركة', 25000, 35000], ['سلسلة فضة', 20000, null], ['ساعة نسائية', 48000, null], ['شنطة سفر', 65000, 75000]],
    'مطاعم وأكل': [['وجبة كباب مشوي', 8000, null], ['مسكوف على الفحم', 25000, null], ['دجاج مشوي كامل', 12000, null], ['وجبة برغر', 9000, 12000], ['سلطة فتوش', 4000, null], ['عصير طبيعي', 3000, null]],
    'بقالة وسوبرماركت': [['زيت عافية 1ل', 7500, null], ['رز عنبر 5كغ', 22000, null], ['سكر 5كغ', 8000, null], ['شاي كرك 1كغ', 9000, null], ['حليب جاف 1كغ', 15000, 18000], ['معجون طماطم', 6000, null]],
    'صيدليات': [['باراسيتامول 500', 3000, null], ['فيتامين D3', 12000, null], ['ميزان حرارة رقمي', 15000, null], ['فيتامين C فوار', 8000, null], ['غسول مطهر', 7000, null], ['كريم حروق', 6000, null]],
    'إلكترونيات': [['شاشة سامسونج 32', 285000, 320000], ['موبايل شاومي 256GB', 220000, null], ['سماعة بلوتوث', 25000, null], ['شاحن سريع 65W', 15000, null], ['مكيف شباك 1.5طن', 450000, 500000], ['ماوس لاسلكي', 9000, null]],
    'عطور وهدايا': [['عطر رجالي فاخر', 60000, 75000], ['عطر نسائي', 55000, null], ['سلة هدايا', 35000, null], ['معطر سيارة', 8000, null], ['عود بخور فاخر', 28000, null]],
    'قرطاسية وكتب': [['مصحف مقاس وسط', 15000, null], ['أقلام جاف 12', 6000, null], ['دفتر 100 ورقة', 2500, null], ['حقيبة مدرسية', 18000, null], ['كتاب قصصي', 8000, null]],
  };
  const ICONS = { 'ملابس رجالي': '👔', 'ملابس نسائي': '👗', 'أطفال وألعاب': '🧸', 'مكياج وعناية': '💄', 'أحذية': '👟', 'شنط وإكسسوارات': '👜', 'مطاعم وأكل': '🍢', 'بقالة وسوبرماركت': '🛒', 'صيدليات': '💊', 'إلكترونيات': '📱', 'عطور وهدايا': '🏺', 'قرطاسية وكتب': '📚' };
  let prodId = 1;
  const products = []; // {id, store, cat, price}
  for (const [i, v] of vendors.entries()) {
    const sid = i + 1;
    for (const [name, price, old] of SETS[v[3]]) {
      const avail = Math.random() > 0.15;
      add([prodId, sid, catIds[v[3]], name, `منتج أصلي من ${v[1]} — جودة مضمونة`, price, old, ICONS[v[3]], avail, avail ? rnd(3, 40) : 0]);
      products.push({ id: prodId, store: sid, price });
      prodId++;
    }
  }
  const myProds = [['قميص رسمي أبيض', 20000, 26000], ['بنطال شينو كحلي', 30000, null], ['حذاء رسمي جلد', 42000, 50000], ['جاكيت سحاب', 38000, null], ['بذلة رياضية', 45000, null], ['ساعة كلاسيك', 55000, null], ['نظارة رجالية', 18000, null], ['محفظة جلد', 15000, null]];
  for (const [name, price, old] of myProds) {
    add([prodId, myStore, catIds['ملابس رجالي'], name, 'منتج من متجر التاجر — جودة أصلية', price, old, '🧥', true, 20]);
    products.push({ id: prodId, store: myStore, price });
    prodId++;
  }
  for (const [name, price, old] of [['قلم سامسونج S24', 55000, 65000], ['سماعة لاسلكية', 18000, null], ['بور بانك 20000', 12000, null], ['ساعة ذكية', 40000, 50000]]) {
    add([prodId, demoStore, catIds['إلكترونيات'], name, 'منتج تجريبي', price, old, '📱', true, 15]);
    products.push({ id: prodId, store: demoStore, price });
    prodId++;
  }
  await flush('products', ['id', 'store_id', 'category_id', 'name', 'description', 'price', 'old_price', 'image', 'is_available', 'stock']);

  const myProdsI = products.filter(p => p.store === myStore);
  const variants = [];
  for (const p of products) {
    if (p.store === myStore) { ['M', 'L', 'XL'].forEach((sz, j) => variants.push([p.id, 'قياس', '', sz, j === 1 ? 0 : rnd(2, 10)])); continue; }
    if (p.store === demoStore) continue;
    const sid = p.store;
    const catName = vendors[sid - 1][3];
    if (catName === 'ملابس رجالي' || catName === 'ملابس نسائي') ['S', 'M', 'L', 'XL', 'XXL'].forEach(sz => variants.push([p.id, 'قياس', '', sz, rnd(0, 12)]));
    if (catName === 'أحذية') ['40', '41', '42', '43'].forEach(sz => variants.push([p.id, 'قياس', '', sz, rnd(0, 10)]));
  }
  variants.forEach(v => add(v));
  await flush('product_variants', ['product_id', 'vgroup', 'color', 'name', 'stock']);
  let offN = 0;
  for (const p of products) if (offN++ % 5 === 0) add([p.id, pick([15, 20, 25, 30, 40]), true]);
  await flush('offers', ['product_id', 'percent', 'active']);

  // ═══ 5) عناوين وكوبونات ═══
  for (const [i, cid] of customers.entries())
    add([cid, di(wasit, i), pick(['البيت', 'العمل', 'بيت الأهل']), `حي ${wasit[i % wasit.length].name}، شارع ${rnd(1, 40)}، دار ${rnd(1, 200)}`, KUT.lat + rnd(-20, 20) * 0.001, KUT.lng + rnd(-20, 20) * 0.001, true]);
  await flush('addresses', ['user_id', 'district_id', 'label', 'details', 'lat', 'lng', 'is_default']);
  const couponIds = { PLAT10: 1, KUT5K: 2, STORE10: 3 };
  add([1, 'PLAT10', null, 10, 0, 25000, 10000, 1, 50, inDays(30), true]);
  add([2, 'KUT5K', null, 0, 5000, 15000, 0, 1, 0, inDays(14), true]);
  add([3, 'STORE10', myStore, 15, 0, 20000, 0, 1, 0, inDays(20), true]);
  await flush('coupons', ['id', 'code', 'store_id', 'percent', 'flat', 'min_total', 'max_discount', 'allowed_uses_per_user', 'uses_left', 'expires_at', 'active']);// ═══ 6) الطلبات ═══
  const STATUSES = ['new', 'new', 'new', 'preparing', 'preparing', 'ready', 'ready', 'delivering', 'delivering', 'delivering', 'delivered', 'delivered', 'delivered', 'delivered', 'cancelled', 'returned'];
  const CHAIN = { new: ['new'], preparing: ['new', 'preparing'], ready: ['new', 'preparing', 'ready'], delivering: ['new', 'preparing', 'ready', 'delivering'], delivered: ['new', 'preparing', 'ready', 'delivering', 'delivered'], cancelled: ['new', 'preparing', 'cancelled'], returned: ['new', 'preparing', 'ready', 'delivering', 'delivered', 'returned'] };
  const SIZES = ['قياسي', 'M', 'L', 'XL'];
  const orders = [];
  const oItems = [];
  const oHistory = [];
  for (let i = 0; i < 40; i++) {
    const status = STATUSES[i % STATUSES.length];
    const storeId = i % 5 === 0 ? myStore : pick(storeIds);
    const storeProds = products.filter(p => p.store === storeId);
    const user = i % 7 === 0 ? customers[i % customers.length] : (i % 3 === 0 ? guests[Math.floor(i / 3) % guests.length] : customers[i % customers.length]);
    const items = [];
    for (let j = 0; j < rnd(1, 3); j++) {
      const pr = pick(storeProds);
      const ex = items.find(x => x.id === pr.id);
      if (ex) ex.qty++;
      else items.push({ id: pr.id, qty: rnd(1, 2), price: pr.price });
    }
    const subtotal = items.reduce((a, x) => a + x.price * x.qty, 0);
    const fee = subtotal >= 50000 ? 0 : pick([1000, 1500, 2000, 2500]);
    let couponId = null, couponCode = '', discount = 0;
    if (i % 4 === 0 && status !== 'cancelled') {
      couponId = i % 2 === 0 ? 1 : 2;
      couponCode = i % 2 === 0 ? 'PLAT10' : 'KUT5K';
      discount = i % 2 === 0 ? Math.min(10000, Math.round(subtotal * 0.1)) : Math.min(5000, subtotal >= 15000 ? 5000 : 0);
    }
    const pointsUsed = i % 6 === 0 ? Math.min(500, Math.floor(subtotal / 1000) * 50) : 0;
    const pointsDiscount = Math.round(pointsUsed / 50) * 500;
    const total = subtotal + fee - discount - pointsDiscount;
    const daysAgo = rnd(0, 14);
    const oid = i + 1;
    orders.push({ id: oid, status, storeId, user, total, daysAgo, couponId });
    add([oid, `ZB-${10000 + i}`, user, storeId, null, status, subtotal, fee, discount, pointsUsed, pointsDiscount, couponId, couponCode, total, 'cod',
      `عنوان الطلب رقم ${i + 1} — حي النصر، الكوت`, pick(['دق جرس الباب', 'الدفع عند الاستلام', '', '', 'اتصل قبل الوصول']),
      agoDays(daysAgo), agoDays(daysAgo),
      status === 'preparing' && i % 9 === 0 ? new Date(Date.now() + 3 * 3600000) : null]);
    for (const x of items) {
      const nm = (await one(`SELECT name FROM products WHERE id=$1`, [x.id]))?.name || `منتج ${x.id}`;
      oItems.push([oid, x.id, nm, pick(SIZES), x.price, x.qty]);
    }
    const chain = CHAIN[status];
    for (const [k, stt] of chain.entries())
      oHistory.push([oid, k > 0 ? chain[k - 1] : null, stt, stt === 'delivering' || stt === 'delivered' ? 'delivery' : 'vendor', '']);
    if (status === 'cancelled' || status === 'returned')
      oHistory.push([oid, chain[chain.length - 1], status, 'vendor', status === 'cancelled' ? 'الزبون ألغى الطلب' : 'استرجاع من الزبون']);
  }
  await flush('orders', ['id', 'code', 'user_id', 'store_id', 'courier_id', 'status', 'subtotal', 'delivery_fee', 'discount', 'points_used', 'points_discount', 'coupon_id', 'coupon_code', 'total', 'payment_method', 'address_text', 'note', 'created_at', 'updated_at', 'scheduled_at']);
  for (const r of oItems) add(r);
  await flush('order_items', ['order_id', 'product_id', 'name', 'variant', 'price', 'qty']);
  for (const r of oHistory) add(r);
  await flush('order_status_history', ['order_id', 'from_status', 'to_status', 'by_role', 'note']);

  // ═══ 7) رحلات التوصيل + التتبع ═══
  const trips = [];
  let tripId = 1;
  for (const o of orders.filter(o => o.status === 'delivering' || o.status === 'delivered')) {
    const courier = tripId % 3 === 0 ? myCourier : couriers[tripId % couriers.length];
    const start = agoDays(o.daysAgo);
    add([tripId, o.id, courier, start, new Date(start.getTime() + 30 * 60000), o.status === 'delivered' ? new Date(start.getTime() + 2 * 3600000) : null, null, null, null]);
    trips.push({ id: tripId, orderId: o.id, courier, lat: KUT.lat + rnd(-10, 20) * 0.002, lng: KUT.lng + rnd(-10, 20) * 0.002, status: o.status });
    tripId++;
  }
  await flush('delivery_trips', ['id', 'order_id', 'courier_id', 'accepted_at', 'picked_at', 'delivered_at', 'lat', 'lng', 'location_updated_at']);
  await q(`UPDATE orders o SET courier_id = t.courier_id FROM delivery_trips t WHERE t.order_id = o.id`);
  for (const t of trips) add([t.id, t.orderId]);
  await flush('trip_orders', ['trip_id', 'order_id']);
  for (const t of trips)
    for (let k = 1; k <= 5; k++)
      add([t.id, Number((KUT.lat + (t.lat - KUT.lat) * k / 6).toFixed(6)), Number((KUT.lng + (t.lng - KUT.lng) * k / 6).toFixed(6))]);
  await flush('delivery_track_log', ['trip_id', 'lat', 'lng']);

  // ═══ 8) نقاط الولاء + محافظ المتاجر ═══
  const earnByUser = {};
  for (const o of orders.filter(o => o.status === 'delivered')) {
    const earn = Math.floor(o.total / 1000);
    if (earn > 0) {
      earnByUser[o.user] = (earnByUser[o.user] || 0) + earn;
      add([o.user, earn, 'earn', 'نقاط من الطلب ✅', String(o.id)]);
    }
  }
  for (const [i, cid] of customers.entries()) {
    add([cid, i % 2 === 0 ? 50 : 100, 'bonus', 'مكافأة تسجيل الحساب 🎁', '']);
    if (i % 4 === 0) add([cid, pick([10, 20, 50, 100, 200]), 'bonus', 'جائزة عجلة الحظ 🎡', '']);
  }
  await flush('point_transactions', ['user_id', 'points', 'type', 'note', 'ref']);
  const sumPts = {};
  for (const p of await q(`SELECT user_id, SUM(points)::int pts FROM point_transactions GROUP BY user_id`)) sumPts[p.user_id] = p.pts;
  for (const [uid, pts] of Object.entries(sumPts))
    await q(`UPDATE users SET points=$1 WHERE id=$2`, [pts, uid]);
  for (const [i, cid] of customers.entries())
    if (i % 4 === 0) add([cid, rnd(10, 200), new Date()]);
  await flush('spin_wins', ['user_id', 'points', 'day']);

  for (const sid of storeIds) {
    const sold = orders.filter(o => o.storeId === sid && o.status === 'delivered');
    if (!sold.length) continue;
    const sum = sold.reduce((a, o) => a + o.total, 0);
    const comm = Math.round(sum * 0.1);
    await q(`UPDATE wallets SET available=$1, pending=$2 WHERE store_id=$3`, [sum - comm - 50000, 40000, sid]);
    add([sid, 'sale', sum - comm, 'مبيعات الطلبات المسلمة', '']);
    add([sid, 'commission', -comm, 'عمولة المنصة 10%', '']);
    if (rnd(0, 1)) add([sid, 'withdraw', -50000, 'استلام نقدي الأسبوع الماضي', '']);
  }
  await flush('wallet_transactions', ['store_id', 'type', 'amount', 'note', 'ref']);

  // ═══ 9) تقارير كاش ═══
  for (let i = 0; i < 10; i++) {
    const courier = couriers[i % couriers.length];
    const total = rnd(15, 90) * 10000;
    const c = Math.round(total * 0.05);
    const st = i < 4 ? 'pending' : 'approved';
    add([courier, agoDays(i % 7), total, c, total - c, st, st === 'approved' ? admin : null, st === 'approved' ? `RC-${2000 + i}` : null]);
  }
  await flush('cash_reports', ['courier_id', 'report_date', 'total_collected', 'commission_amount', 'net', 'status', 'approved_by', 'receipt_no']);

  // ═══ 10) الإعلانات ═══
  const adDefs = [
    [myStore, 'تشكيلة الشتاء 🔥 خصم حتى 30%', '🧥', 7, 25000, 'active', 1],
    [storeIds[1], 'فساتين السهرة الجديدة ✨', '👗', 7, 25000, 'active', 2],
    [storeIds[2], 'عروض الألعاب 🧸 خصم 25%', '🧸', 14, 40000, 'active', 3],
    [storeIds[9], 'إلكترونيات بأسعار الصندوق 📱', '📱', 14, 40000, 'pending', 0],
    [storeIds[10], 'عطور أصلية بانتظار الموافقة 🏺', '🏺', 7, 25000, 'pending', 0],
    [storeIds[4], 'تخفيضات نهاية الأسبوع 🏷', '🏷️', 3, 15000, 'rejected', 0],
    [storeIds[6], 'عرض تخفيضات انتهى ⏰', '⏰', 3, 15000, 'expired', 0],
  ];
  for (const [sid, title, art, days, price, status, sort] of adDefs)
    add([sid, title, art, pick(GRADS), days, price, status, sort,
      status === 'active' ? agoDays(2) : null,
      status === 'active' ? inDays(days - 2) : null]);
  await flush('ad_requests', ['store_id', 'title', 'art', 'gradient', 'duration_days', 'price', 'status', 'sort', 'starts_at', 'ends_at']);

  // ═══ 11) تقييمات + مفضلة + أسئلة + متابعة متاجر ═══
  const RCOMMENTS = ['خدمة ممتازة وسريعة 🔥', 'الجودة زينة والتغليف راقي', 'التوصيل وصل بوقته', 'من أفضل المتاجر بالكوت', 'الأسعار معقولة شكراً', 'خامة ممتازة بس المقاس أكبر شوية', 'تعامل محترم، أكرر التجربة', 'المنتج مطابق للوصف تماماً'];
  let rv = 0;
  for (const sid of storeIds) {
    for (let j = 0, n = rnd(2, 5); j < n; j++) {
      add([sid, customers[rv % customers.length], rnd(3, 5), pick(RCOMMENTS), agoDays(rnd(1, 12)), null]);
      rv++;
    }
  }
  await flush('reviews', ['store_id', 'user_id', 'rating', 'comment', 'created_at', 'order_id']);
  for (let i = 0; i < 15; i++) add([customers[i % customers.length], pick(products).id]);
  await flush('favorites', ['user_id', 'product_id']);
  for (const [i, s] of storeIds.entries())
    if (i % 3 === 0) add([customers[i], s]);
  await flush('store_favorites', ['user_id', 'store_id']);
  const QUESTS = ['هل يتوفر مقاس أكبر؟', 'هل المنتج أصلي؟', 'كم مدة التوصيل؟', 'هل يمكن الاستبدال؟', 'المقاسات مضبوطة؟'];
  for (let i = 0; i < 8; i++) {
    const p = pick(products);
    add([p.id, p.store, customers[i % customers.length], QUESTS[i % QUESTS.length], i % 2 === 0 ? 'نعم متوفر حالياً ✅' : null, i % 2 === 0 ? new Date() : null]);
  }
  await flush('product_questions', ['product_id', 'store_id', 'user_id', 'question', 'answer', 'answered_at']);

  // ═══ 12) محادثات (أثناء التوصيل فقط) ═══
  let cvId = 1;
  const cvRows = [];
  for (const o of orders.filter(o => o.status === 'delivering')) {
    const t = trips.find(tr => tr.orderId === o.id);
    if (!t) continue;
    add([cvId, o.user, t.courier, new Date()]);
    cvRows.push({ id: cvId, user: o.user, courier: t.courier });
    cvId++;
  }
  await flush('conversations', ['id', 'user_id', 'courier_id', 'last_message_at']);
  for (const cv of cvRows) {
    add([cv.id, cv.user, 'customer', pick(['وين وصلت بالمندوب؟', 'يوجد مشكلة على الباب أرجو الاتصال', 'متى يوصل الطلب؟', 'صباح الخير، الطريق للعنوان متعارف عليه؟']), null]);
    add([cv.id, cv.courier, 'courier', pick(['أنا بالطريق قرب الجسر الأصفر 🚚', 'وصلت الساحة، على بابك بعد 5 دقائق', 'حاضر، اتصال بعد قليل', 'الطلب بين أيدينا — أنتظرني على الباب']), null]);
  }
  await flush('messages', ['conversation_id', 'sender_id', 'sender_role', 'body', 'read_at']);

  // ═══ 13) إشعارات ═══
  const notifs = [
    [null, 'admin', 'order', 'طلب جديد بانتظار المراجعة', 'أحد المتاجر استلم طلباً جديداً'],
    [null, 'admin', 'cash', 'المندوب حسين سلّم الكاش', '186,500 د.ع قيد المراجعة'],
    [null, 'admin', 'ad', 'طلب إعلان جديد — بانتظار موافقتك', '3 طلبات إعلان قيد الموافقة'],
    [null, 'admin', 'store', 'متجر بانتظار التوثيق', 'لمسة — رفعت مستندات التوثيق'],
    [myVendor, null, 'order', 'طلب جديد على متجرك 🔔', 'فاتك طلب بقيمة 73,000 د.ع'],
    [myVendor, null, 'ad', 'إعلانك انقبل من المشرف ✓', 'تشكيلة الشتاء تعرض بالواجهة الرئيسية'],
    [myCourier, null, 'delivery', 'مهمة توصيل جديدة 🚚', 'المنطقة: حي الجهاد — الكاش 45,000 د.ع'],
    [customers[0], null, 'order', 'طلبك في الطريق إليك 🚚', 'الكود ZB-10001 — المندوب قربك'],
    [customers[1], null, 'info', 'وصلتك نقاط الولاء ⭐', '125 نقطة من طلبك السابق'],
    [customers[2], null, 'chat', 'رسالة من المندوب 📦', 'وصلت الساحة، على بابك بعد 5 دقائق'],
    [demoCustomer, null, 'ad', 'عروض اليوم 🔥', 'خصم حتى 30% عند الأصيل'],
    [myCourier, null, 'cash', 'تم اعتماد تقرير الكاش ✓', 'RC-2000 تمت الموافقة عليه'],
  ];
  for (const n of notifs) add([n[0], n[1], n[2], n[3], n[4]]);
  await flush('notifications', ['user_id', 'role', 'type', 'title', 'body']);

  // ═══ 14) سلة + إرجاعات + سجلات + OTP + تليجرام ═══
  for (let i = 0; i < 5; i++) add([customers[i], pick(products).id, null, rnd(1, 2)]);
  await flush('cart_items', ['user_id', 'product_id', 'variant_id', 'qty']);
  for (const o of orders.filter(o => o.status === 'returned'))
    add([o.id, pick(['المنتج غير مطابق', 'انتهاء صلاحية', 'تأخر التوصيل', 'تغير الرأي']), 'التفاصيل كاملة بالاستلام', 'return', 'مقاس / لون آخر', 'pending', null]);
  await flush('refund_requests', ['order_id', 'reason', 'details', 'type', 'desired', 'status', 'resolved_at']);
  for (const a of [
    [admin, 'users.update', 'منصة', null, null, null],
    [admin, 'stores.approve', 'متجر التاجر', myStore, null, '{"status":"approved"}'],
    [admin, 'cash.approve', 'تقرير كاش RC-2000', null, null, null],
    [admin, 'ad.approve', 'إعلان تشكيلة الشتاء', null, null, null],
    [admin, 'settings.update', 'daily_goal = 5,000,000', null, null, null],
  ]) add(a);
  await flush('audit_logs', ['admin_id', 'action', 'entity', 'entity_id', 'old_data', 'new_data']);
  add(['077269029241', '123456', 'login', new Date(Date.now() + 5 * 60000), false]);
  await flush('otp_codes', ['phone', 'code', 'purpose', 'expires_at', 'used']);
  add(['077269029241', 123456789]);
  await flush('telegram_links', ['phone', 'chat_id']);
  add(['seed-token-1', customers[0], '077269029243', 'verified', 'register', null, null, null, null, null, false, 0, new Date(), new Date(Date.now() + 3600000), null]);
  await flush('phone_verifications', ['token', 'user_id', 'phone', 'status', 'purpose', 'ip', 'chat_id', 'contact_phone', 'code', 'code_expires_at', 'code_ok', 'attempts', 'created_at', 'expires_at', 'verified_at']);
  add(['seed-bind-1', '077269029241', new Date(Date.now() + 2 * 3600000), false]);
  await flush('telegram_bindings', ['token', 'phone', 'expires_at', 'used']);

  // ═══ 15) إعادة مزامنة المتسلسلات ═══
  const tables = (await q(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`)).map(r => r.table_name);
  for (const t of tables) {
    let seq = null;
    try { seq = await one(`SELECT pg_get_serial_sequence('public.${t}','id') s`); } catch { seq = null; }
    if (seq?.s) await pool.query(`SELECT setval($1, COALESCE((SELECT max(id) FROM public."${t}"), 1), true)`, [seq.s]);
  }

  const counts = {
    users: (await one(`SELECT count(*)::int c FROM users`)).c,
    vendors: (await one(`SELECT count(*)::int c FROM users WHERE role='vendor'`)).c,
    couriers: (await one(`SELECT count(*)::int c FROM users WHERE role='delivery'`)).c,
    customers: (await one(`SELECT count(*)::int c FROM users WHERE role='customer'`)).c,
    stores: (await one(`SELECT count(*)::int c FROM stores`)).c,
    products: (await one(`SELECT count(*)::int c FROM products`)).c,
    orders: (await one(`SELECT count(*)::int c FROM orders`)).c,
    reviews: (await one(`SELECT count(*)::int c FROM reviews`)).c,
    ads: (await one(`SELECT count(*)::int c FROM ad_requests`)).c,
    trips: (await one(`SELECT count(*)::int c FROM delivery_trips`)).c,
  };
  console.log(`✅ تم توليد البيانات المتكاملة:
  المستخدمون: ${counts.users} (تجار ${counts.vendors} | مناديب ${counts.couriers} | زبائن ${counts.customers})
  المتاجر: ${counts.stores} | المنتجات: ${counts.products} | الطلبات: ${counts.orders}
  التقييمات: ${counts.reviews} | الإعلانات: ${counts.ads} | الرحلات: ${counts.trips}

  ─ الحسابات الخاصة (كلمة السر $/Sa/13#):
    أدمن: 077269029243 | تاجر: 077269029242 (متجر: متجر التاجر — أزياء راقية) | مندوب: 077269029241
  ─ حسابات العرض (123456): تاجر 000000000100 | زبون 000000000200 | مندوب 000000000300`);
  await pool.end();
}

seed().catch(async (e) => { console.error('❌', e.stack || e.message); process.exit(1); });