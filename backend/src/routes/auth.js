import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import { q, one } from '../db.js';
import { signToken, publicUser, auth, roles } from '../middleware.js';
import { sendSms } from '../sms.js';
import { sendOtpViaTelegram, createPhoneVerification } from '../telegram.js';

const r = Router();

const genCode = () => String(Math.floor(1000 + Math.random() * 9000));
const genReferral = () => 'ZB' + String(Math.floor(10000 + Math.random() * 90000));

// ── التسجيل: رقم مكتوب → تأكيد تلغرام (مطابقة + رمز) → الاسم وكلمة المرور ──
// التحقق (OTP) للحساب الجديد فقط — الرقم المسجل مسبقاً يوجّه للدخول مباشرة
// 1) register-start {phone}: فحص الوجود + جلسة تحقق
// 2) البوت: يطابق رقم المشاركة مع الرقم المكتوب → يرسل رمز
// 3) register-code {token, code}: التثبت من الرمز
// 4) register-confirm {token, name, password, referral}: إنشاء الحساب نهائياً
r.post('/register-start', async (req, res) => {
  const phone = String(req.body.phone || '').replace(/\D/g, '');
  if (!/^0[0-9]{9,14}$/.test(phone)) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });

  // الدور مطلوب من الـ placeholder فقط — أي قيمة خارج القائمة تُرفض
  const role = String(req.body.role || 'customer');
  if (!['customer', 'vendor'].includes(role))
    return res.status(400).json({ error: 'نوع الحساب غير صالح' });

  // حساب موجود → لا داعي للتحقق — سجّل دخول مباشرة
  const existing = await one('SELECT id FROM users WHERE phone=$1', [phone]);
  if (existing) return res.status(400).json({ error: 'هذا الرقم عليه حساب — سجّل دخول مباشرة' });

  const ip = (req.headers['x-forwarded-for']?.split(',')[0] || req.ip || '').trim();
  const recent = await one(`SELECT count(*)::int AS n FROM phone_verifications
                            WHERE purpose='register' AND ip=$1 AND created_at > now() - interval '10 minutes'`, [ip]);
  if ((recent?.n || 0) >= 5) return res.status(429).json({ error: 'طلبات كثيرة — جرب بعد 10 دقائق' });

  // تنظيف الحسابات المعلّقة اليتيمة (جلساتها انتهت) — لا تراكم
  await q(`DELETE FROM users WHERE phone LIKE 'tg-await-%' AND verified=false
           AND NOT EXISTS (SELECT 1 FROM phone_verifications pv
                           WHERE pv.user_id=users.id AND pv.status IN ('pending','prompted'))`);

  const placeholder = 'tg-await-' + randomBytes(8).toString('hex');
  const user = (await q(`INSERT INTO users (phone, name, role, verified)
                         VALUES ($1,'',$2,false) RETURNING *`, [placeholder, role]))[0];

  const token = await createPhoneVerification({ userId: user.id, phone, purpose: 'register', ip });
  res.json({ token, bot_username: process.env.TELEGRAM_BOT_USERNAME || 'soog_otp_bot', expires_in: 600 });
});

// ── التثبت من رمز البوت (بعد مطابقة الرقم) ──
r.post('/register-code', async (req, res) => {
  const token = String(req.body.token || '');
  const code = String(req.body.code || '').trim();
  if (!token || !code) return res.status(400).json({ error: 'رمز ناقص' });
  const v = await one(`SELECT * FROM phone_verifications WHERE token=$1 AND purpose='register'`, [token]);
  if (!v || v.status === 'expired') return res.status(401).json({ error: 'الجلسة منتهية — ابدأ التسجيل من جديد' });
  if (v.status !== 'verified') return res.status(400).json({ error: 'لم يكتمل تأكيد البوت بعد — اضغط زر المشاركة داخل تلغرام' });
  if (v.code_ok) return res.json({ ok: true }); // الرمز محسوم سابقاً — لا إعادة
  if (!v.code || !v.code_expires_at || new Date(v.code_expires_at) < new Date())
    return res.status(400).json({ error: 'الرمز منتهي — ابدأ التسجيل من جديد' });
  if (code !== v.code) {
    await q(`UPDATE phone_verifications SET attempts=attempts+1 WHERE token=$1`, [token]);
    return res.status(401).json({ error: 'الرمز غلط — راجع رسالة البوت وجرب' });
  }
  await q(`UPDATE phone_verifications SET code_ok=true WHERE token=$1`, [token]);
  res.json({ ok: true });
});

// ── إتمام التسجيل: رمز مؤكد + الاسم وكلمة المرور → الحساب جاهز ──
r.post('/register-confirm', async (req, res) => {
  const token = String(req.body.token || '');
  const name = String(req.body.name || '').trim();
  const password = String(req.body.password || '');
  const referral = String(req.body.referral || '').trim();
  if (!token) return res.status(400).json({ error: 'token ناقص' });
  if (name.length < 3) return res.status(400).json({ error: 'الاسم قصير جداً' });
  if (password.length < 6) return res.status(400).json({ error: 'كلمة المرور 6 أحرف كحد أدنى' });

  const v = await one(`SELECT * FROM phone_verifications WHERE token=$1 AND purpose='register'`, [token]);
  if (!v || v.status === 'expired') return res.status(401).json({ error: 'الجلسة منتهية — ابدأ التسجيل من جديد' });
  if (v.status !== 'verified' || !v.code_ok) return res.status(400).json({ error: 'اكمل التأكيد والرمز أولاً' });

  const user = await one('SELECT * FROM users WHERE id=$1', [v.user_id]);
  if (!user || user.verified) return res.status(401).json({ error: 'الحساب غير صالح — ابدأ من جديد' });

  // الرقم الصالح: المكتوب بالتطبيق والمطابق لرقم التلغرام من البوت
  const tgPhone = String(v.phone || '');
  if (!/^0[0-9]{9,14}$/.test(tgPhone)) return res.status(400).json({ error: 'الرقم غير صالح' });

  // حماية مزدوجة: حتى لو سبق الرقم — رفض
  const dup = await one('SELECT id FROM users WHERE phone=$1 AND id!=$2', [tgPhone, user.id]);
  if (dup) {
    await q(`UPDATE phone_verifications SET status='expired' WHERE token=$1`, [token]);
    return res.status(409).json({ error: 'هذا الرقم عليه حساب مسبقاً — سجّل دخول مباشرة' });
  }

  let referredById = null;
  if (referral) {
    const inviter = await one('SELECT id FROM users WHERE referral_code=$1', [referral]);
    if (inviter) referredById = inviter.id;
  }

  let referralCode;
  do { referralCode = genReferral(); } while (await one('SELECT id FROM users WHERE referral_code=$1', [referralCode]));
  const hash = await bcrypt.hash(password, 10);
  const done = (await q(`UPDATE users SET phone=$1, name=$2, password=$3, verified=true,
                         referral_code=$4, referred_by=$5
                         WHERE id=$6 RETURNING *`,
    [tgPhone, name, hash, referralCode, referredById, user.id]))[0];

  // مكافأة الدعوة: 100 نقطة للداعي + 50 للمدعو (بعد التحقق الحقيقي فقط)
  if (done.referred_by) {
    await q(`UPDATE users SET points = points + 100 WHERE id=$1`, [done.referred_by]);
    await q(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,100,'bonus','مكافأة دعوة صديق 🎁',$2)`, [done.referred_by, done.id]);
    await q(`UPDATE users SET points = points + 50 WHERE id=$1`, [done.id]);
    await q(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,50,'bonus','انضمام عبر دعوة صديق 🎉',$2)`, [done.id, done.referred_by]);
  }

  // الجلسة تُغلق بعد الاستهلاك — لا إعادة استخدام
  await q(`UPDATE phone_verifications SET status='expired' WHERE token=$1`, [token]);

  res.json({ token: signToken(done), user: publicUser(done) });
});

// ── تسجيل حساب جديد (يتطلب تأكيد الهاتف برمز OTP) ──
r.post('/register', async (req, res) => {
  const { phone, name, password, code, referral } = req.body;
  const cleanPhone = String(phone || '').replace(/\D/g, '');
  if (cleanPhone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });
  if (!name || !password) return res.status(400).json({ error: 'الاسم وكلمة المرور مطلوبين' });
  if (!code) return res.status(400).json({ error: 'أرسل رمز التحقق أولاً وتأكد منه' });
  
  const existing = await one('SELECT id FROM users WHERE phone=$1', [cleanPhone]);
  if (existing) return res.status(400).json({ error: 'هذا الرقم مسجل مسبقاً' });

  const otp = await one(`SELECT * FROM otp_codes WHERE phone=$1 AND code=$2 AND used=false AND expires_at > now() ORDER BY id DESC LIMIT 1`, [cleanPhone, String(code).trim()]);
  if (!otp) return res.status(401).json({ error: 'رمز التحقق غلط أو منتهي — أرسل رمز جديد' });
  await q(`UPDATE otp_codes SET used=true WHERE id=$1`, [otp.id]);

  const hash = await bcrypt.hash(password, 10);
  // الدور ثابت دائماً customer — أي محاولة رفع صلاحية من خارج النظام مرفوضة
  let referredById = null;
  let referralCode = null;
  if (referral) {
    const inviter = await one('SELECT id FROM users WHERE referral_code=$1', [String(referral).trim()]);
    if (inviter) referredById = inviter.id;
  }
  do { referralCode = genReferral(); } while (await one('SELECT id FROM users WHERE referral_code=$1', [referralCode]));
  const user = (await q(`INSERT INTO users (phone, name, password, role, verified, referral_code, referred_by) VALUES ($1,$2,$3,'customer',true,$4,$5) RETURNING *`,
    [cleanPhone, name, hash, referralCode, referredById]))[0];

  // مكافأة الدعوة: 100 نقطة للداعي + 50 نقطة للمدعو
  if (referredById) {
    await q(`UPDATE users SET points = points + 100 WHERE id=$1`, [referredById]);
    await q(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,100,'bonus','مكافأة دعوة صديق 🎁',$2)`, [referredById, user.id]);
    await q(`UPDATE users SET points = points + 50 WHERE id=$1`, [user.id]);
    await q(`INSERT INTO point_transactions (user_id, points, type, note, ref) VALUES ($1,50,'bonus','انضمام عبر دعوة صديق 🎉',$2)`, [user.id, referredById]);
  }

  res.json({ token: signToken(user), user: publicUser(user) });
});

// ── تسجيل الدخول بالباسوورد ──
r.post('/login', async (req, res) => {
  const { phone, password } = req.body;
  const cleanPhone = String(phone || '').replace(/\D/g, '');
  if (!cleanPhone || !password) return res.status(400).json({ error: 'رقم الهاتف وكلمة المرور مطلوبين' });

  const user = await one('SELECT * FROM users WHERE phone=$1', [cleanPhone]);
  if (!user) return res.status(401).json({ error: 'الرقم أو كلمة المرور خطأ' });

  // الحسابات بدون كلمة مرور (ضيوف فقط) لا تدخل بالباسوورد
  if (!user.password || user.password.trim() === '')
    return res.status(401).json({ error: 'ما عندك كلمة مرور مسجلة — تواصل مع الدعم' });
  const ok = await bcrypt.compare(password, user.password);
  if (!ok) return res.status(401).json({ error: 'الرقم أو كلمة المرور خطأ' });

  res.json({ token: signToken(user), user: publicUser(user) });
});

// ── طلب رمز OTP — مسار قديم: للتطوير المحلي فقط، مغلق كلياً فوق السحابة ──
r.post('/request-otp', async (req, res) => {
  // التسجيل الرسمي الآن عبر زر تلغرام — هذا المسار قناة اختبار داخلية
  if (process.env.VERCEL) return res.status(403).json({ error: 'التسجيل عبر رمز مغلق — استخدم زر مشاركة الرقم داخل تلغرام' });

  const phone = String(req.body.phone || '').replace(/\D/g, '');
  if (phone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });

  const existing = await one('SELECT id FROM users WHERE phone=$1', [phone]);
  if (existing) return res.status(400).json({ error: 'هذا الرقم مسجل مسبقاً — سجل دخول مباشرة' });

  const code = genCode();
  // رمز التطوير يُصرّف محلياً فقط — لا يتسرب لسحابة Vercel أبداً
  const dev = process.env.DEV_OTP === 'true' && !process.env.VERCEL;

  // 1) التليجرام (مجاني) — إذا الرقم مربوط بالبوت يوصله فوراً
  const viaTg = await sendOtpViaTelegram(phone, code).catch(() => false);

  // 2) SMS عبر المزود إذا مُهيأ (والتليجرام ما وصل)
  if (!dev && !viaTg) {
    const smsOk = await sendSms(phone, `زبون — رمز التحقق: ${code} (صالح 5 دقائق)`).catch(() => false);
    if (!smsOk) {
      return res.status(400).json({ error: 'رح اربط رقمك ببوت التليجرام من داخل التطبيق أولاً — أو فعّل مزود SMS' });
    }
  }

  await q(`INSERT INTO otp_codes (phone, code, purpose, expires_at) VALUES ($1,$2,'register', now() + interval '5 minutes')`, [phone, code]);
  res.json({
    ok: true,
    via: viaTg ? 'telegram' : (dev ? 'dev' : 'sms'),
    dev_code: dev && !viaTg ? code : undefined,
  });
});

// ── من أنا ──
r.get('/me', auth, async (req, res) => {
  const user = await one('SELECT * FROM users WHERE id=$1', [req.user.id]);
  res.json({ user: publicUser(user) });
});

// ── تحديث الاسم ──
r.patch('/profile', auth, async (req, res) => {
  const name = String(req.body.name || '').slice(0, 60);
  const avatar = String(req.body.avatar || req.user.avatar).slice(0, 4);
  const u = (await q(`UPDATE users SET name=$1, avatar=$2 WHERE id=$3 RETURNING *`, [name, avatar, req.user.id]))[0];
  res.json({ user: publicUser(u) });
});

// ── بحث مستخدمين (للأدمن) ──
r.get('/search', auth, roles('admin'), async (req, res) => {
  const t = `%${req.query.q || ''}%`;
  const rows = await q(`SELECT * FROM users WHERE phone LIKE $1 OR name ILIKE $1 LIMIT 20`, [t]);
  res.json({ users: rows.map(publicUser) });
});

export default r;
