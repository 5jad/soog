// ═══════════ بوت تليجرام (grammy) — توصيل OTP مجاني وآمن ═══════════
// الأمان: الرقم ما يكتب أبداً — التطبيق يولّد رمز ربط سري (telegram_bindings)
// ويفتح التليجرام برابط  https://t.me/<bot>?start=<رمز>
// الزبون يضغط Start فقط → البوت يربط الـ chat بالرقم (telegram_links) → الرموز تجيه
//
// التهيئة:
//   TELEGRAM_BOT_TOKEN=123456:ABC...   (من @BotFather) — إجباري

import { Bot, Keyboard } from 'grammy';
import { randomBytes } from 'crypto';
import dotenv from 'dotenv';
dotenv.config();
import { q, one } from './db.js';

export const bot = process.env.TELEGRAM_BOT_TOKEN ? new Bot(process.env.TELEGRAM_BOT_TOKEN) : null;

export function maskPhone(phone) {
  return phone.slice(0, 4) + '•••' + phone.slice(-3);
}

// ── تحقق الهاتف عبر تليجرام (request_contact) — جلسة مربوطة بالمستخدم ──
export const normPhone = (raw) => {
  let d = String(raw || '').replace(/\D/g, '');
  if (d.startsWith('964')) d = d.slice(3);   // +9647901234567 → 7901234567
  if (d.length === 10) d = '0' + d;          // 7901234567 → 07901234567
  return d;
};

export async function createPhoneVerification({ userId, phone, purpose = 'order', ip = '' }) {
  // للتسجيل: الرقم الحقيقي غير معروف بعد — placeholder داخلي يمنع NULL
  const p = purpose === 'register' ? phone : normPhone(phone);
  // كل محاولة جديدة تُجهض المعلّقة السابقة لنفس المستخدم — لا جلسات أيتام
  await q(`UPDATE phone_verifications SET status='expired'
           WHERE user_id=$1 AND status IN ('pending','prompted')`, [userId]);
  const token = 'ZV' + randomBytes(6).toString('hex');
  await q(`INSERT INTO phone_verifications (token, user_id, phone, purpose, ip, expires_at)
           VALUES ($1,$2,$3,$4,$5, now() + interval '10 minutes')`, [token, userId, p, purpose, ip]);
  return token;
}

if (bot) {
  // /start بدون رمز → شرح الارتباط
  bot.command('start', async (ctx) => {
    const payload = String(ctx.match || '');
    if (!payload) {
      await ctx.reply('أهلاً بك في بوت «زبون» 🛒\n\nلربط حسابك: افتح تطبيق زبون، ومن شاشة الدخول اضغط «استلام الرمز عبر تليجرام» — البوت يوصلك الرمز تلقائياً هنيه 🔐', { parse_mode: 'HTML' });
      return;
    }
    // ── الطريق الجديد: جلسة تحقق request_contact ──
    const sess = await one(`SELECT * FROM phone_verifications
                            WHERE token=$1 AND status IN ('pending','prompted') AND expires_at > now()`,
                           [payload]);
    if (sess) {
      await q(`UPDATE phone_verifications SET status='prompted', chat_id=$1 WHERE token=$2`,
              [ctx.chat.id, payload]);
      await ctx.reply('مرحباً بك في «زبون» 🛒\nلتأكيد رقمك: اضغط الزر بالأسفل — يشارك رقم هاتفك بضغطة وحدة، بدون كتابة، وتلغرام نفسه يضمن صحته ✓', {
        reply_markup: new Keyboard().requestContact('📱 مشاركة رقم هاتفي').oneTime().resized(),
      });
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

  // يسبق هاندلر الرسائل العام — حتى لا يعترضه رد "ما دزو لي أمر معروف"
  bot.on('message:contact', async (ctx) => {
    const room = await one(`SELECT * FROM phone_verifications
                            WHERE chat_id=$1 AND status='prompted' AND expires_at > now()
                            ORDER BY created_at DESC LIMIT 1`, [ctx.chat.id]);
    if (!room) {
      await ctx.reply('ماكو طلب تحقق مفتوح هنيه — ارجع للتطبيق وجرب مرة ثانية');
      return;
    }
    const incoming = normPhone(ctx.message.contact.phone_number);
    // ── جلسة تسجيل: الرقم الوارد هو رقم الحساب حرفياً — بلا مقارنة ──
    // تلغرام يشارك رقم صاحب الحساب فقط، فماكو رقم مكتوب يقارن به أصلاً
    if (room.purpose === 'register') {
      await q(`UPDATE phone_verifications
               SET status='verified', phone=$2, contact_phone=$2, verified_at=now()
               WHERE token=$1`, [room.token, incoming]);
      await ctx.reply('✅ تم تسجيلك في «زبون» بنجاح! ارجع للتطبيق واضغط «متابعة» لإكمال الدخول');
      return;
    }
    if (incoming !== room.phone) {
      await q(`UPDATE phone_verifications SET attempts=attempts+1, status='mismatch', contact_phone=$2
               WHERE token=$1`, [room.token, incoming]);
      await ctx.reply('❌ الرقم اللي شاركته ما يطابق رقم حسابك بالتطبيق — ارجع للتطبيق وجرب من جديد');
      return;
    }
    await q(`UPDATE phone_verifications SET status='verified', contact_phone=$2, verified_at=now()
             WHERE token=$1`, [room.token, incoming]);
    await ctx.reply('✅ تم تأكيد رقمك بنجاح! ارجع للتطبيق وتابع طلبك');
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