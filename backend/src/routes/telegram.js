import { Router } from 'express';
import { randomBytes } from 'crypto';
import { webhookCallback } from 'grammy';
import { q, one } from '../db.js';
import { auth } from '../middleware.js';
import { bot, createPhoneVerification, maskPhone } from '../telegram.js';

const r = Router();

// ── بدء جلسة تحقق: الرقم من التوكن (req.user.phone) — لا يُقبل رقم من البادي أبداً ──
r.post('/verify-start', auth, async (req, res) => {
  const recent = await one(`SELECT count(*)::int AS n FROM phone_verifications
                            WHERE user_id=$1 AND created_at > now() - interval '10 minutes'`, [req.user.id]);
  if ((recent?.n || 0) >= 5) return res.status(429).json({ error: 'طلبات كثيرة — جرب بعد 10 دقائق' });

  const token = await createPhoneVerification({ userId: req.user.id, phone: req.user.phone });
  res.json({ token, bot_username: process.env.TELEGRAM_BOT_USERNAME || 'soog_otp_bot', expires_in: 600 });
});

// ── حالة الجلسة (polling كل 2.5 ثانية) — مقيدة بالتوكن + المستخدم نفسه ──
r.get('/verify-status', auth, async (req, res) => {
  const token = String(req.query.token || '');
  if (!token) return res.status(400).json({ error: 'token ناقص' });
  const v = await one(`SELECT status, phone FROM phone_verifications WHERE token=$1 AND user_id=$2`,
                      [token, req.user.id]);
  if (!v) return res.json({ status: 'expired' });
  res.json({ status: v.status, phone: v.status === 'verified' ? maskPhone(v.phone) : undefined });
});

// ── ربط OTP قديم — بعد إصلاح أمني: يتطلب دخولاً، والرقم من التوكن لا من البادي ──
// (كان عاماً ويقبل أي رقم → أي مهاجم يربط هاتف الضحية بحسابه ويخطف الرموز)
r.post('/bind-token', auth, async (req, res) => {
  const phone = String(req.user.phone || '').replace(/\D/g, '');
  if (phone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });

  await q(`DELETE FROM telegram_bindings WHERE phone=$1 AND used=false`, [phone]);
  const token = 'ZB' + randomBytes(6).toString('hex');
  await q(`INSERT INTO telegram_bindings (token, phone, expires_at) VALUES ($1,$2, now() + interval '10 minutes')`, [token, phone]);
  res.json({ token, bot_username: process.env.TELEGRAM_BOT_USERNAME || 'soog_otp_bot' });
});

// ── حالة جلسة التسجيل — عام (لا حساب بعد)؛ حمايته: التوكن نفسه سري (48 بت عشوائي) ──
r.get('/register-status', async (req, res) => {
  const token = String(req.query.token || '');
  if (!token) return res.status(400).json({ error: 'token ناقص' });
  const v = await one(`SELECT status FROM phone_verifications WHERE token=$1 AND purpose='register'`, [token]);
  if (!v) return res.json({ status: 'expired' });
  res.json({ status: v.status });
});

// نقطة الـ webhook — Vercel يرسل تحديثات البوت هنا (معالجة grammy الجاهزة)
if (bot) {
  r.post('/webhook', webhookCallback(bot, 'express'));
} else {
  r.post('/webhook', (_req, res) => res.json({ ok: false, error: 'البوت غير مهيأ' }));
}

export default r;