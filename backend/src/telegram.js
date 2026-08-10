// ═══════════ بوت تليجرام (grammy) — توصيل OTP مجاني وآمن ═══════════
// الأمان: الرقم ما يكتب أبداً — التطبيق يولّد رمز ربط سري (telegram_bindings)
// ويفتح التليجرام برابط  https://t.me/<bot>?start=<رمز>
// الزبون يضغط Start فقط → البوت يربط الـ chat بالرقم (telegram_links) → الرموز تجيه
//
// التهيئة:
//   TELEGRAM_BOT_TOKEN=123456:ABC...   (من @BotFather) — إجباري

import { Bot } from 'grammy';
import dotenv from 'dotenv';
dotenv.config();
import { q, one } from './db.js';

export const bot = process.env.TELEGRAM_BOT_TOKEN ? new Bot(process.env.TELEGRAM_BOT_TOKEN) : null;

function maskPhone(phone) {
  return phone.slice(0, 4) + '•••' + phone.slice(-3);
}

if (bot) {
  // /start بدون رمز → شرح الارتباط
  bot.command('start', async (ctx) => {
    const payload = String(ctx.match || '');
    if (!payload) {
      await ctx.reply('أهلاً بك في بوت «زبون» 🛒\n\nلربط حسابك: افتح تطبيق زبون، ومن شاشة الدخول اضغط «استلام الرمز عبر تليجرام» — البوت يوصلك الرمز تلقائياً هنيه 🔐', { parse_mode: 'HTML' });
      return;
    }
    // /start <رمز> صادر من التطبيق → ربط آمن
    const row = await one(`SELECT * FROM telegram_bindings WHERE token=$1 AND used=false AND expires_at > now()`, [payload]);
    if (!row) {
      await ctx.reply('هذا الرابط منتهي أو غير صالح ❌\nارجع للتطبيق واضغط زر الارتباط مرة ثانية');
      return;
    }
    await q(`UPDATE telegram_bindings SET used=true WHERE token=$1`, [payload]);
    await q(`INSERT INTO telegram_links (chat_id, phone) VALUES ($1,$2)
             ON CONFLICT (phone) DO UPDATE SET chat_id = EXCLUDED.chat_id`, [ctx.chat.id, row.phone]);
    await ctx.reply(`تم ربط حسابك «${maskPhone(row.phone)}» بنجاح ✓\nمن اليوم رموز التحقق ترد إلك هنا مباشرة 🔐`);
  });

  bot.on('message', async (ctx) => {
    if (!ctx.message.text) return;
    await ctx.reply('ما دزو لي أمر معروف 🤔\nاستخدم زر الارتباط من داخل تطبيق زبون، أو اضغط /start');
  });

  bot.catch((err) => console.error('❌ بوت تليجرام:', err.error?.message || err.message));
}

// إرسال رمز OTP عبر التليجرام — يرجع true إذا انرسل
export async function sendOtpViaTelegram(phone, code) {
  if (!bot) return false;
  const row = await one('SELECT chat_id FROM telegram_links WHERE phone=$1', [phone]);
  if (!row) return false;
  const user = await one('SELECT name FROM users WHERE phone=$1', [phone]);
  await bot.api.sendMessage(row.chat_id,
    `رمز التحقق 🔐\n\n<b>${code}</b>\n\nلطلب ${user ? `«${user.name}» — ` : ''}صالح لمدة 5 دقائق، لا تشاركه مع أي أحد.`,
    { parse_mode: 'HTML' });
  return true;
}

// ── سؤال مستمر (Local فقط — Vercel يستخدم الـ webhook) ──
export function startLocalBot() {
  if (!bot) return;
  bot.start();
  console.log('🟢 بوت تليجرام (grammy) شغال بالوضع المحلي');
}