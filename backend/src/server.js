import http from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
dotenv.config();

import app from './app.js';
import { startTelegramPolling } from './telegram.js';

// على Vercel (serverless) ما نفتح سيرفر ولا Socket.io — فقط نصدّر الـ app
if (!process.env.VERCEL) {
  const server = http.createServer(app);
  const io = new Server(server, { cors: { origin: '*' } });

  io.on('connection', (socket) => {
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

  // بوت تليجرام محلي (لو ما عنده webhook منصوب)
  if (!process.env.WEBHOOK_URL) startTelegramPolling();
}