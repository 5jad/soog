import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { q, one } from '../db.js';
import { signToken, publicUser, auth, roles } from '../middleware.js';
import { sendSms } from '../sms.js';

const r = Router();

const genCode = () => String(Math.floor(1000 + Math.random() * 9000));
const genReferral = () => 'ZB' + String(Math.floor(10000 + Math.random() * 90000));

// ── تسجيل حساب جديد بالباسوورد ──
r.post('/register', async (req, res) => {
  const { phone, name, password, referral } = req.body;
  const cleanPhone = String(phone || '').replace(/\D/g, '');
  if (cleanPhone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });
  if (!name || !password) return res.status(400).json({ error: 'الاسم وكلمة المرور مطلوبين' });
  
  const existing = await one('SELECT id FROM users WHERE phone=$1', [cleanPhone]);
  if (existing) return res.status(400).json({ error: 'هذا الرقم مسجل مسبقاً' });

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

  // الحسابات بدون كلمة مرور (ضيوف فقط) لا تدخل بالباسوورد — بكود OTP
  if (!user.password || user.password.trim() === '')
    return res.status(401).json({ error: 'ما عندك كلمة مرور مسجلة — استخدم "نسيت الباسوورد"' });
  const ok = await bcrypt.compare(password, user.password);
  if (!ok) return res.status(401).json({ error: 'الرقم أو كلمة المرور خطأ' });

  res.json({ token: signToken(user), user: publicUser(user) });
});

// ── إعادة تعيين كلمة المرور عبر OTP ──
r.post('/reset-password', async (req, res) => {
  const { phone, code, new_password } = req.body;
  const cleanPhone = String(phone || '').replace(/\D/g, '');
  
  const otp = await one(`SELECT * FROM otp_codes WHERE phone=$1 AND code=$2 AND used=false AND expires_at > now() ORDER BY id DESC LIMIT 1`, [cleanPhone, String(code || '')]);
  if (!otp) return res.status(401).json({ error: 'الرمز غلط أو منتهي' });
  
  await q(`UPDATE otp_codes SET used=true WHERE id=$1`, [otp.id]);
  
  const user = await one('SELECT * FROM users WHERE phone=$1', [cleanPhone]);
  if (!user) return res.status(404).json({ error: 'الحساب غير موجود' });
  
  const hash = await bcrypt.hash(new_password, 10);
  await q(`UPDATE users SET password=$1 WHERE id=$2`, [hash, user.id]);
  
  res.json({ token: signToken(user), user: publicUser(user) });
});

// ── طلب رمز OTP (يُستخدم للتأكيد ونسيت كلمة المرور) ──
r.post('/request-otp', async (req, res) => {
  const phone = String(req.body.phone || '').replace(/\D/g, '');
  if (phone.length < 10) return res.status(400).json({ error: 'رقم الهاتف غير صحيح' });

  if (req.body.role === 'admin') {
    const user = await one('SELECT * FROM users WHERE phone=$1 AND role=$2', [phone, 'admin']);
    if (!user) return res.status(404).json({ error: 'ماكو حساب أدمن بهذا الرقم' });
    return res.json({ ok: true, mode: 'password' });
  }

  const code = genCode();
  const dev = process.env.DEV_OTP === 'true';

  // في الإنتاج: يرسل SMS حقيقي عبر المزود — ثم ما يرجع dev_code أبداً
  if (!dev) {
    try {
      await sendSms(phone, `زبون — رمز التحقق: ${code} (صالح 5 دقائق)`);
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  } else {
    try { await sendSms(phone, `زبون — رمز التحقق: ${code}`); } catch (_) {}
  }

  await q(`INSERT INTO otp_codes (phone, code, purpose, expires_at) VALUES ($1,$2,'reset', now() + interval '5 minutes')`, [phone, code]);
  res.json({ ok: true, dev_code: dev ? code : undefined });
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
