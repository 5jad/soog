import express from 'express';
import cors from 'cors';
import http from 'http';
import path from 'path';
import { fileURLToPath } from 'url';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ADMIN_DIST = path.join(__dirname, '../../admin-dashboard');
const LANDING_DIST = path.join(__dirname, '../../landing');

import authRoutes from './routes/auth.js';
import publicRoutes from './routes/public.js';
import customerRoutes from './routes/customer.js';
import vendorRoutes from './routes/vendor.js';
import deliveryRoutes from './routes/delivery.js';
import routingRoutes from './routes/routing.js';
import adminRoutes from './routes/admin.js';
import uploadRoutes from './routes/uploads.js';

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true }));

// الصور المرفوعة من معرض الجهاز
app.use('/uploads', express.static(path.join(__dirname, 'public', 'uploads')));
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
app.get('/site', (_req, res) => res.sendFile(path.join(LANDING_DIST, 'index.html')));
app.use('/site', express.static(LANDING_DIST));
app.get('/download', (_req, res) => res.download(path.join(LANDING_DIST, 'downloads', 'zaboon-app.apk'), 'zaboon-app.apk'));

// داشبورد الإدارة (ويب) — نفس السيرفر
app.use('/admin', express.static(ADMIN_DIST));
app.get('/admin', (_req, res) => res.sendFile(path.join(ADMIN_DIST, 'index.html')));
app.get('/', (_req, res) => res.redirect('/admin'));

app.use((err, _req, res, _next) => {
  console.error('❌', err.message);
  res.status(500).json({ error: 'صارت مشكلة بالسيرفر — جرب مرة ثانية' });
});

io.on('connection', (socket) => {
  const { token } = socket.handshake.auth || {};
  socket.on('join', (role) => socket.join(`role:${role}`));
  socket.on('order:new', () => io.to('role:vendor').emit('orders:refresh'));
  socket.on('order:ready', () => io.to('role:delivery').emit('orders:refresh'));
  socket.on('order:update', () => io.emit('orders:update'));
});

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`🚀 سيرفر زبون شغال: http://localhost:${PORT}`);
  console.log(`   Health: /api/health`);
});
