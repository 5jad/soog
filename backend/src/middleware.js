import jwt from 'jsonwebtoken';
import { one } from './db.js';

// المفتاح إجباري — بدون JWT_SECRET السيرفر يرفض الإقلاع بدل الإقلاع بمفتاح معروف للعموم
const SECRET = process.env.JWT_SECRET;
if (!SECRET) throw new Error('JWT_SECRET غير مضبوط — السيرفر رفض الإقلاع. اضبط المفتاح في متغيرات البيئة');

export const signToken = (user) =>
  jwt.sign({ id: user.id, phone: user.phone, role: user.role, name: user.name }, SECRET, { expiresIn: '7d' });

export const publicUser = (u) => u && ({
  id: u.id, phone: u.phone, name: u.name, role: u.role, avatar: u.avatar,
  verified: u.verified, blocked: u.blocked, created_at: u.created_at,
  points: u.points ?? 0, referral_code: u.referral_code,
});

export const auth = async (req, res, next) => {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'سجل دخولك أول' });
  try {
    const payload = jwt.verify(token, SECRET);
    const user = await one('SELECT * FROM users WHERE id=$1', [payload.id]);
    if (!user || user.blocked) return res.status(401).json({ error: 'الحساب محظور أو غير موجود' });
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'الرمز منتهي — سجل دخولك مرة ثانية' });
  }
};

export const roles = (...allowed) => (req, res, next) => {
  if (!req.user || !allowed.includes(req.user.role))
    return res.status(403).json({ error: 'ما عندك صلاحية بهذا الدور' });
  next();
};
