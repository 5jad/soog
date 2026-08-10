// ═══════════ بوت تليجرام — توصيل OTP مجاني ═══════════
// التهيئة:
//   TELEGRAM_BOT_TOKEN=123456:ABC...   (من @BotFather)
//   WEBHOOK_URL=https://soog-delta.vercel.app  (لفعل الـ webhook — اختياري عند التشغيل المحلي)
//
// التجربة:
//   1) الزبون يفتح البوت ويضغط /start
//   2) يرسل رقمه (07701234567) → يرتبط الحساب بالبوت (جدول telegram_links)
//   3) أي طلب OTP لاحق: الرمز يوصله رسالة تليجرام فوراً — مجاني ولانهاية

import { q, one } from './db.js';

const TOKEN = () => process.env.TELEGRAM_BOT_TOKEN || '';
const FBOT = () => `https://api.telegram.org/bot${TOKEN()}`;

async function tgSend(chatId, text) {
  const token = TOKEN();
  if (!token) return false;
  const r = await fetch(`${FBOT()}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: String(chatId), text, parse_mode: 'HTML' }),
  });
  if (!r.ok) {
    const e = await r.json().catch(() => ({}));
    throw new Error('تليغرام: ' + (e.description || r.status));
  }
  return true;
}

// معالجة رسالة واردة من الزبون (حالياً: ربط الرقم بالبوت)
async function handleUpdate(update) {
  const msg = update.message;
  if (!msg || msg.text === undefined) return;

  const chatId = msg.chat.id;
  const text = String(msg.text).trim().toLowerCase();

  if (['/start', '/begin', 'ابدأ', 'هلو', 'هلا', 'سلام'].includes(text)) {
    return tgSend(chatId, 'أهلاً بك في بوت «زبون» 🛒\n\nأرسل رقم هاتفك (مثال: <b>07701234567</b>) مرة وحدة، وكل رمز تحقق سيجيك هنا مباشرة ✓');
  }

  const digits = String(msg.text).trim().replace(/\D/g, '');
  if (/^07\d{9}$/.test(digits)) {
    await q(`INSERT INTO telegram_links (chat_id, phone) VALUES ($1,$2)
             ON CONFLICT (phone) DO UPDATE SET chat_id = EXCLUDED.chat_id`, [chatId, digits]);
    return tgSend(chatId, 'تم ربط حسابك بالبوت ✓\n\nمن اليوم رمز OTP الخاص بك يوصلك هذه الرسالة فوراً 🔐');
  }

  return tgSend(chatId, 'ما فهمت رسالتك 🤔\nأرسل رقم هاتفك فقط بصيغة: <b>07701234567</b>\nأو اضغط /start');
}

// إرسال رمز OTP عبر التليجرام — يرجع true إذا انرسل
export async function sendOtpViaTelegram(phone, code) {
  const token = TOKEN();
  if (!token) return false;
  const row = await one('SELECT chat_id FROM telegram_links WHERE phone=$1', [phone]);
  if (!row) return false;
  const user = await one('SELECT name FROM users WHERE phone=$1', [phone]);
  await tgSend(row.chat_id,
    `رمز التحقق 🔐\n\n<b>${code}</b>\n\nلطلب ${user ? `«${user.name}» — ` : ''}صالح لمدة 5 دقائق، لا تشاركه مع أي أحد.`);
  return true;
}

// ── Webhook (ممكن على Vercel مباشرة بدون أي خادم دائم) ──
export async function handleWebhook(body) {
  if (!body || !body.update_id) return;
  try { await handleUpdate(body); } catch (e) { console.error('❌ تليغرام:', e.message); }
}

// ── سؤال مستمر (Local فقط — Vercel يستخدم الـ webhook) ──
export function startTelegramPolling() {
  if (!TOKEN()) return;
  let offset = 0;
  let running = true;
  const loop = async () => {
    if (!running) return;
    try {
      const r = await fetch(`${FBOT()}/getUpdates?timeout=30&offset=${offset}`);
      if (r.ok) {
        const data = await r.json();
        for (const u of data.result || []) {
          offset = u.update_id + 1;
          await handleWebhook(u);
        }
      }
    } catch (_) {}
    setTimeout(loop, 1500);
  };
  loop();
  console.log('🟢 بوت تليجرام شغال (سؤال محلي)');
}