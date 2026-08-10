import { Router } from 'express';
import { randomBytes } from 'crypto';
import { webhookCallback } from 'grammy';
import { q } from '../db.js';
import { bot } from '../telegram.js';

const r = Router();

// يصدر رمز ربط سري للهاتف — التطبيق يفتح به البوت (t.me/<bot>?start=الرمز)
// الرقم لا يرسل أبداً للنص — فقط بالرمز السري الذي يملكه صاحب الهاتف
r.post('/bind-token', async (req, res) => {
  const phone = String(req.body.phone || '').replace(/\D/g, '');
  if (phone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });

  await q(`DELETE FROM telegram_bindings WHERE phone=$1 AND used=false`, [phone]);
  const token = 'ZB' + randomBytes(6).toString('hex');
  await q(`INSERT INTO telegram_bindings (token, phone, expires_at) VALUES ($1,$2, now() + interval '10 minutes')`, [token, phone]);
  res.json({ token, bot_username: process.env.TELEGRAM_BOT_USERNAME || 'soog_otp_bot' });
});

// نقطة الـ webhook — Vercel يرسل تحديثات البوت هنا (معالجة grammy الجاهزة)
if (bot) {
  r.post('/webhook', webhookCallback(bot, 'express'));
} else {
  r.post('/webhook', (_req, res) => res.json({ ok: false, error: 'البوت غير مهيأ' }));
}

export default r;