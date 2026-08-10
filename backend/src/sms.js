// ═══════════ إرسال SMS — جاهز للمزودات ═══════════
// أول ما تجيب حساب عند مزود (مثال Twilio):
//   SMS_PROVIDER=twilio
//   TWILIO_SID=...   TWILIO_TOKEN=...   TWILIO_FROM=+1xxxxxxxxxx
// أرجع "true" إذا انرسلت، و"false" إذا ماكو مزود (الوضع التجريبي)

export async function sendSms(phone, text) {
  if (process.env.SMS_PROVIDER === 'twilio') {
    const sid = process.env.TWILIO_SID;
    const token = process.env.TWILIO_TOKEN;
    const from = process.env.TWILIO_FROM;
    if (!sid || !token || !from) throw new Error('ناقص متغيرات Twilio');
    const params = new URLSearchParams({ To: phone, From: from, Body: text });
    const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });
    if (!r.ok) throw new Error('فشل إرسال SMS: ' + r.status);
    return true;
  }
  // بدون مزود: الرمز يطبع بالسجل (وضع تطوير)
  console.log(`📲 SMS (بدون مزود — تطويري): ${phone} ← ${text}`);
  return false;
}