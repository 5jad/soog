-- ═══════════════════════════════════════════════════════════
-- زبون — هوية «أفق» — مخطط قاعدة البيانات (PostgreSQL)
-- منصة متاجر محافظة واسط (الکوت) — قابلة للتوسع لكل المحافظات
-- ═══════════════════════════════════════════════════════════

DROP TABLE IF EXISTS audit_logs, notifications, favorites, reviews, refund_requests,
  order_status_history, order_items, orders, delivery_trips, cash_reports, wallet_transactions,
  wallets, ad_requests, ad_packages, offers, product_variants, products, store_documents, stores,
  categories, addresses, cart_items, otp_codes, users, districts, governorates, settings CASCADE;

-- ── المحافظات والمناطق (التوسعة المستقبلية) ──
CREATE TABLE governorates (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  name_en TEXT,
  is_active BOOLEAN DEFAULT true,
  sort INTEGER DEFAULT 0
);

CREATE TABLE districts (
  id SERIAL PRIMARY KEY,
  governorate_id INTEGER NOT NULL REFERENCES governorates(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sort INTEGER DEFAULT 0
);

-- ── المستخدمون ──
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','vendor','delivery','admin')),
  avatar TEXT DEFAULT '👤',
  password TEXT,                          -- للأدمن فقط (اسم + كلمة سر)
  verified BOOLEAN DEFAULT false,
  blocked BOOLEAN DEFAULT false,
  points INTEGER DEFAULT 0,               -- نقاط الولاء
  referral_code TEXT UNIQUE,              -- كود دعوة الأصدقاء
  referred_by INTEGER REFERENCES users(id), -- من دعاه
  created_at TIMESTAMPTZ DEFAULT now()
);

-- سجل حركة نقاط الولاء
CREATE TABLE point_transactions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  points INTEGER NOT NULL,
  type TEXT DEFAULT 'earn' CHECK (type IN ('earn','redeem','bonus','adjust')),
  note TEXT DEFAULT '',
  ref TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE otp_codes (
  id SERIAL PRIMARY KEY,
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  purpose TEXT DEFAULT 'login',
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE addresses (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  district_id INTEGER REFERENCES districts(id),
  label TEXT DEFAULT 'الرئيسي',
  details TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── الأقسام ──
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT DEFAULT '📦',
  sort INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true
);

-- سمات المنتجات لكل قسم (مثل القياس للملابس) — يعرّف التاجر القيم عند إضافة منتج
CREATE TABLE category_attrs (
  id SERIAL PRIMARY KEY,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  key TEXT NOT NULL,            -- اسم البرمجي الحقل
  label TEXT NOT NULL,          -- التسمية الظاهرة (مثلاً "القياس")
  type TEXT DEFAULT 'text',     -- text | select
  options JSONB DEFAULT '[]',   -- خيارات النوع select
  required BOOLEAN DEFAULT false,
  sort INTEGER DEFAULT 0
);

-- ── المتاجر ──
CREATE TABLE stores (
  id SERIAL PRIMARY KEY,
  owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  governorate_id INTEGER NOT NULL REFERENCES governorates(id),
  district_id INTEGER REFERENCES districts(id),
  name TEXT NOT NULL,
  category_id INTEGER REFERENCES categories(id),
  logo TEXT DEFAULT '🏪',
  cover TEXT DEFAULT '',
  description TEXT DEFAULT '',
  address TEXT DEFAULT '',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  location_url TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  delivery_fee INTEGER DEFAULT 2000,
  free_delivery_min INTEGER DEFAULT 50000,
  open_time TEXT DEFAULT '9ص',
  close_time TEXT DEFAULT '11ل',
  is_open BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'approved' CHECK (status IN ('pending','approved','rejected','suspended')),
  verified BOOLEAN DEFAULT false,
  commission_rate NUMERIC(5,2) DEFAULT 10.00,
  rating_avg NUMERIC(3,2) DEFAULT 0,
  rating_count INTEGER DEFAULT 0,
  last_paid_at TIMESTAMPTZ,
  warranty_days INTEGER DEFAULT 3,   -- سياسة الضمان (أيام من الاستلام)
  on_vacation BOOLEAN DEFAULT false,   -- إجازة المتجر
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE store_documents (
  id SERIAL PRIMARY KEY,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type TEXT NOT NULL,             -- license / commercial / electricity
  title TEXT NOT NULL,
  file_url TEXT DEFAULT '',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by INTEGER REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── المنتجات ──
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES categories(id),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price INTEGER NOT NULL,
  old_price INTEGER,
  image TEXT DEFAULT '📦',
  images TEXT[] DEFAULT '{}',  -- صور متعددة (رُفعت من معرض الجهاز)
  attributes JSONB DEFAULT '{}',  -- قيم السمات لكل قسم ({"size":"L","color":"أزرق"})
  is_available BOOLEAN DEFAULT true,
  stock INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE product_variants (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  vgroup TEXT DEFAULT 'قياس',
  color TEXT DEFAULT '',
  name TEXT DEFAULT 'قياسي',
  stock INTEGER DEFAULT 0,
  UNIQUE (product_id, vgroup, color, name)
);

CREATE TABLE offers (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  percent INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── السلة والطلبات ──
CREATE TABLE cart_items (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_id INTEGER REFERENCES product_variants(id) ON DELETE CASCADE,
  qty INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, product_id, variant_id)
);

-- الكوبونات / الرموز الترويجية
CREATE TABLE coupons (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  store_id INTEGER REFERENCES stores(id) ON DELETE CASCADE, -- NULL = كوبون عام للمنصة
  percent INTEGER DEFAULT 10,          -- نسبة الخصم
  flat INTEGER DEFAULT 0,              -- أو خصم ثابت دينار
  min_total INTEGER DEFAULT 0,         -- حد أدنى للسلة
  max_discount INTEGER DEFAULT 0,      -- سقف الخصم (0 = بدون سقف)
  allowed_uses_per_user INTEGER DEFAULT 1,
  uses_left INTEGER DEFAULT 0,         -- 0 = غير محدود
  starts_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE coupon_usages (
  id SERIAL PRIMARY KEY,
  coupon_id INTEGER NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
  discount INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (coupon_id, user_id, order_id)
);

-- مفضلة المتاجر (متابعة المتجر)
CREATE TABLE store_favorites (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, store_id)
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  store_id INTEGER NOT NULL REFERENCES stores(id),
  courier_id INTEGER REFERENCES users(id),
  status TEXT DEFAULT 'new' CHECK (status IN ('new','preparing','ready','delivering','delivered','cancelled','returned')),
  subtotal INTEGER NOT NULL DEFAULT 0,
  delivery_fee INTEGER NOT NULL DEFAULT 0,
  discount INTEGER NOT NULL DEFAULT 0,
  coupon_id INTEGER REFERENCES coupons(id),
  coupon_code TEXT DEFAULT '',
  points_used INTEGER DEFAULT 0,
  points_discount INTEGER DEFAULT 0,
  points_earned INTEGER DEFAULT 0,
  group_id TEXT,                          -- لسلة موحّدة عدة متاجر: نفس الـ checkout في عدة طلبات
  scheduled_at TIMESTAMPTZ,               -- جدولة التوصيل
  warranty_days INTEGER DEFAULT 3,        -- ضمان الاسترجاع
  total INTEGER NOT NULL DEFAULT 0,
  payment_method TEXT DEFAULT 'cod',
  address_id INTEGER REFERENCES addresses(id),
  address_text TEXT DEFAULT '',
  note TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  variant_id INTEGER REFERENCES product_variants(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  variant TEXT DEFAULT '',
  price INTEGER NOT NULL,
  qty INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE order_status_history (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  by_role TEXT,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE delivery_trips (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  courier_id INTEGER NOT NULL REFERENCES users(id),
  accepted_at TIMESTAMPTZ DEFAULT now(),
  picked_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  lat DOUBLE PRECISION,                  -- تتبع حي للمندوب
  lng DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ
);

-- ── المحادثات (الزبون ↔ التاجر) ──
CREATE TABLE conversations (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, store_id)
);

CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id INTEGER NOT NULL REFERENCES users(id),
  sender_role TEXT DEFAULT 'customer',
  body TEXT NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── أسئلة وأجوبة على المنتجات (Q&A) ──
CREATE TABLE product_questions (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  answer TEXT,
  answered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── عجلة الحظ / العناصر التفاعلية ──
CREATE TABLE spin_wins (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  points INTEGER NOT NULL DEFAULT 0,
  day DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, day)
);

-- ── التقييم والإرجاع والمفضلة ──
CREATE TABLE reviews (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE refund_requests (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT DEFAULT '',
  type TEXT DEFAULT 'return' CHECK (type IN ('return','exchange')),
  desired TEXT DEFAULT '',                       -- البديل المطلوب (مثال: أحمر · 32)
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE favorites (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, product_id)
);

-- ── الإعلانات ──
CREATE TABLE ad_packages (
  id SERIAL PRIMARY KEY,
  days INTEGER NOT NULL,
  price INTEGER NOT NULL,
  active BOOLEAN DEFAULT true
);

CREATE TABLE ad_requests (
  id SERIAL PRIMARY KEY,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  art TEXT DEFAULT '🖼',
  gradient TEXT DEFAULT 'linear-gradient(120deg,#1E3A8A,#06B6D4)',
  duration_days INTEGER DEFAULT 7,
  price INTEGER DEFAULT 25000,
  status TEXT DEFAULT 'active' CHECK (status IN ('pending','active','rejected','expired')),
  sort INTEGER DEFAULT 0,
  starts_at TIMESTAMPTZ DEFAULT now(),
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── المال (قاعدة L4: الأرقام صلب) ──
CREATE TABLE wallets (
  id SERIAL PRIMARY KEY,
  store_id INTEGER NOT NULL UNIQUE REFERENCES stores(id) ON DELETE CASCADE,
  available INTEGER DEFAULT 0,
  pending INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE wallet_transactions (
  id SERIAL PRIMARY KEY,
  store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type TEXT CHECK (type IN ('sale','commission','withdraw','ad','refund','adjust')),
  amount INTEGER NOT NULL,
  note TEXT DEFAULT '',
  ref TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE cash_reports (
  id SERIAL PRIMARY KEY,
  courier_id INTEGER NOT NULL REFERENCES users(id),
  report_date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_collected INTEGER NOT NULL DEFAULT 0,
  commission_amount INTEGER NOT NULL DEFAULT 0,
  net INTEGER NOT NULL DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','shortage')),
  approved_by INTEGER REFERENCES users(id),
  receipt_no TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── الإشعارات والسجل ──
CREATE TABLE notifications (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,  -- NULL = لكل الدور
  role TEXT,
  type TEXT DEFAULT 'info',
  title TEXT NOT NULL,
  body TEXT DEFAULT '',
  data JSONB DEFAULT '{}',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT DEFAULT ''
);

CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  admin_id INTEGER REFERENCES users(id),
  action TEXT NOT NULL,
  entity TEXT,
  entity_id INTEGER,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── سجل نقاط مسار المندوب (يرسم المسار الحقيقي للزبون) ──
CREATE TABLE delivery_track_log (
  id SERIAL PRIMARY KEY,
  trip_id INTEGER NOT NULL REFERENCES delivery_trips(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_track_log_trip ON delivery_track_log(trip_id, id);

-- ── ربط رحلة التوصيل الواحدة بجميع طلبات المجموعة (أكثر من محل) ──
CREATE TABLE trip_orders (
  trip_id INTEGER NOT NULL REFERENCES delivery_trips(id) ON DELETE CASCADE,
  order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  PRIMARY KEY (trip_id, order_id)
);
