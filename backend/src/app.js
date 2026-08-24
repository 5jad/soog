import express from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
dotenv.config();

import { ensureDb } from './bootstrap.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.join(__dirname, 'public');
// لوحة الأدمن: النسخة المقدَّمة بـ backend/public/admin أولاً، ثم src/public، ثم مصدر الجذر (محلي)
const ADMIN_DIST = fs.existsSync(path.join(__dirname, '../public/admin'))
  ? path.join(__dirname, '../public/admin')
  : fs.existsSync(path.join(PUBLIC_DIR, 'admin')) ? path.join(PUBLIC_DIR, 'admin')
  : path.join(__dirname, '../../admin-dashboard');
const LANDING_DIST = fs.existsSync(path.join(PUBLIC_DIR, 'landing')) ? path.join(PUBLIC_DIR, 'landing')
  : path.join(__dirname, '../../landing');

import authRoutes from './routes/auth.js';
import publicRoutes from './routes/public.js';
import customerRoutes from './routes/customer.js';
import telegramRoutes from './routes/telegram.js';
import vendorRoutes from './routes/vendor.js';
import deliveryRoutes from './routes/delivery.js';
import routingRoutes from './routes/routing.js';
import adminRoutes from './routes/admin.js';
import uploadRoutes from './routes/uploads.js';

// تهيئة القاعدة (آمنة: تعمل مرة وحدة، ما تمسح شي موجود)
try { await ensureDb(); } catch (e) { console.error('⚠️ bootstrap:', e.message); }

const app = express();

app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true }));

// الصور المرفوعة من معرض الجهاز — ملفات القرص أولاً، ثم القاعدة (بيئات serverless)
app.get('/uploads/:name', async (req, res) => {
  const file = path.join(PUBLIC_DIR, 'uploads', path.basename(req.params.name));
  if (fs.existsSync(file)) return res.sendFile(file);
  try {
    const { one } = await import('./db.js');
    const row = await one(
      'SELECT bytes, mime FROM uploaded_images WHERE name=$1',
      [req.params.name],
    );
    if (!row) return res.status(404).json({ error: 'الصورة غير موجودة' });
    res.setHeader('Content-Type', row.mime || 'image/jpeg');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.send(Buffer.isBuffer(row.bytes) ? row.bytes : Buffer.from(row.bytes));
  } catch (e) {
    res.status(500).json({ error: 'تعذر جلب الصورة' });
  }
});
app.use('/uploads', express.static(path.join(PUBLIC_DIR, 'uploads')));
app.use('/api/uploads', uploadRoutes);

app.get('/api/health', (_req, res) => res.json({ ok: true, name: 'زبون — منصة متاجر الكوت', time: new Date().toISOString() }));

app.use('/api/auth', authRoutes);
app.use('/api', publicRoutes);
app.use('/api/customer', customerRoutes);
app.use('/api/vendor', vendorRoutes);
app.use('/api/delivery', deliveryRoutes);
app.use('/api/routing', routingRoutes);
app.use('/api/admin', adminRoutes);

// الموقع التعريفي + تحميل التطبيق
if (fs.existsSync(LANDING_DIST)) {
  app.get('/site', (_req, res) => res.sendFile(path.join(LANDING_DIST, 'index.html')));
  app.use('/site', express.static(LANDING_DIST));
  app.get('/download', (_req, res) => res.download(path.join(LANDING_DIST, 'downloads', 'zaboon-app.apk'), 'zaboon-app.apk'));
}

// داشبورد الإدارة (ويب) — نفس السيرفر
if (fs.existsSync(ADMIN_DIST)) {
  app.use('/admin', express.static(ADMIN_DIST));
  app.get('/admin', (_req, res) => res.sendFile(path.join(ADMIN_DIST, 'index.html')));
}

// المتجر الإلكتروني — الواجهة الرسمية للزبائن (حاسوب / جوال / آيباد)
const STORE_DIST = fs.existsSync(path.join(PUBLIC_DIR, 'store')) ? path.join(PUBLIC_DIR, 'store')
  : path.join(__dirname, '../../storefront');
if (fs.existsSync(STORE_DIST)) {
  app.use('/store', express.static(STORE_DIST));
  app.get('/store', (_req, res) => res.sendFile(path.join(STORE_DIST, 'index.html')));
  app.get('/store/*splat', (_req, res) => res.sendFile(path.join(STORE_DIST, 'index.html')));
}

// الصفحة الرسمية: / = المتجر مباشرة (الواجهة الاحترافية للمتصفح بنفس ألوان وخط التطبيق)،
// واللاندينغ القديم يبقى متاح على /site
if (fs.existsSync(STORE_DIST)) {
  app.get('/', (_req, res) => res.redirect('/store'));
} else if (fs.existsSync(LANDING_DIST)) {
  app.get('/', (_req, res) => res.sendFile(path.join(LANDING_DIST, 'index.html')));
} else {
  app.get('/', (_req, res) => res.redirect('/admin'));
}

// بوت تليجرام (توصيل OTP مجاني)
app.use('/api/telegram', telegramRoutes);

app.use((err, _req, res, _next) => {
  console.error('❌', err.message);
  res.status(500).json({ error: 'صارت مشكلة بالسيرفر — جرب مرة ثانية' });
});

export default app;