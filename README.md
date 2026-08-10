# زبون — الكوت 🗺

منصة عرض وتوصيل متاجر محافظة واسط (الكوت) — تتوسع لأي محافظة. نظام متكامل:

- **باك اند**: Node.js + Express 5 + PostgreSQL (مخصص)
- **لوحة تحكم**: ويب RTL للآدمن (نفس السيرفر)
- **تطبيق**: Flutter (Android) لـ 4 أدوار: زبون، تاجر، مندوب، آدمن
- **الدفع**: كاش عند الاستلام فقط 💵

## 🚀 التشغيل

### 1) قاعدة البيانات (محلية — بدون sudo)

```bash
# أول مرة فقط:
cd infra
initdb -D pgdata -U postgres --auth=trust > /dev/null
pg_ctl -D pgdata -o "-p 5434 -k /tmp" -l pg.log start
```

### 2) الباك اند

```bash
cd backend
npm install
npm run db:init   # إنشاء الجداول
npm run db:seed   # بيانات الكوت التجريبية
npm run dev       # السيرفر على http://localhost:4000
```

- لوحة التحكم: http://localhost:4000/admin
- تكوين: `backend/.env` (`DEV_OTP=true` يطبع الرمز في الرد بدل SMS)

### 3) التطبيق

```bash
cd app
flutter pub get
flutter build apk --debug   # APK: app/build/app/outputs/flutter-apk/
```

**مهم**: جهّز هاتفك على نفس شبكة الجهاز، وغير في `app/lib/api.dart`:
```dart
static String base = 'http://192.168.1.X:4000'; // IP جهازك — للمحاكي يبقى 10.0.2.2
```

## ☁️ الرفع على الإنترنت مجاناً (Vercel + Neon)

بدون بطاقة بنكية، مجاني دائم. الكود جاهز (bootstrap يبني الجداول ويحقن الأدمن تلقائياً عند أول تشغيل).

1. **قاعدة البيانات — Neon** (app.neon.tech → سجل بحساب GitHub/Google):
   - New Project → اسم `zaboon` → انسخ **connection string** (يبدأ بـ `postgresql://...`).
   - (خيار عاجل بدون تسجيل: https://neon.new — لكن الأفضل حساب عادي)

2. **الرفع — Vercel (**بدون مجلد GitHub**):**
   ```bash
   cd backend
   npm i -g vercel
   vercel          # أول مرة: يتصل بحسابك ويسأل Project Name ← اكتب soog
   ```
   - أو من صفحة Vercel عند استيراد GitHub: **Root Directory = `backend`**

3. **المتغيرات (Project → Settings → Environment Variables):**
   | المفتاح | القيمة |
   |---|---|
   | `DATABASE_URL` | رابط Neon (مع `?sslmode=require`) |
   | `PGSSL` | `true` |
   | `JWT_SECRET` | سلسلة عشوائية طويلة |
   | `DEV_OTP` | `true` (بعد ما تجيب مزود SMS تغيّرها `false`) |

4. `vercel --prod` → الموقع يصير: `https://soog-delta.vercel.app`
   - لوحة الأدمن: `https://soog-delta.vercel.app/admin` — دخول: `07900000000` / `admin123`
   - التطبيق: غيّر في `app/lib/api.dart` → `Api.base = 'https://soog-delta.vercel.app'` وأعد البناء.

ملاحظات الخطة المجانية: Vercel Hobby (حد 4.5MB بالطلبات) + Neon ينام بعد 5 دقايق خمول (أول طلب يستيقظه خلال ~1 ثانية).

## 🔑 حسابات التجربة (seed)

| الدور | الهاتف | الدخول |
|---|---|---|
| آدمن | 07900000000 | كلمة سر: `admin123` |
| زبون | 07731234567 | OTP (يظهر في رد الـ API) |
| تاجر (الأصيل) | 07701112233 | OTP |
| مندوب (حسين) | 07705556677 | OTP |

## 🏗 البنية

```
backend/               الباك اند (Express 5 + PostgreSQL + Socket.io)
  src/schema.sql       الجداول (27 جدول)
  src/seed.js          بيانات الكوت: واسط+8 أحياء، بغداد، 10 أقسام، 5 متاجر
  src/routes/          auth · public · customer · vendor · delivery · admin
admin-dashboard/       لوحة آدمن ويب (هوية أفق، RTL، HTML/JS نقي)
app/                   تطبيق Flutter (هوية أفق، زجاجي، 4 أدوار)
infra/                 قاعدة بيانات المشروع المحلية (منفذ 5434)
```

## 🗺 خط التوسعة

1. **داخل واسط**: أضف أحياء من لوحة التحكم → المحافظات.
2. **محافظات جديدة**: أضف المحافظة من اللوحة → التطبيق يشتغل بها مباشرة.
3. **جدا**: غيّر `governorate_name` في الإعدادات + غيّر `Api.base` عند رفع السيرفر.

## 🧪 الاختبار

- الباك اند: اتبع دورة كاملة — سلة → طلب → قبول التاجر → جاهز → مندوب → تسليم → محفظة.
- Flutter: `flutter analyze` نظيف (0 أخطاء) + `flutter test`.
- قاعدة البيانات المعزولة على `5434` — لا تتأثر بالنظامية (5432) ولا بمشاريع أخرى (5433).

## 📦 إصدار نسخة جديدة (الزبون يحمّل الأحدث من الموقع دائماً)

النظام: التطبيق يستعلم `GET /api/app/version` ويقارنها — إذا طلعت أحدث يعرض شريط "حمّل" يفتح رابط الموقع مباشرة.

```bash
./scripts/publish.sh 1.1.0 "وصف التحديث الجديد"
cd . && git add -A && git commit -m "إصدار 1.1.0: ..." && git push
```

السكربت يرفع الإصدار في: الكود (`kAppVersion`)، ملف السيرفر (`app-version.json`)، يبني الـ APK، وينسخه لمجلد الموقع → Vercel يتحدث تلقائياً → الموقع والتطبيق يوصلان بنفس النسخة.
