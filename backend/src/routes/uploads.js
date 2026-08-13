import { Router } from 'express';
import { auth, roles } from '../middleware.js';
import { storeImage } from '../image-store.js';

const r = Router();

// ── أمان: rate-limit بسيط (30 طلب/دقيقة لكل IP) ──
const hits = new Map();
r.use((req, res, next) => {
  const ip = req.ip || req.socket.remoteAddress || 'x';
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  if (arr.length >= 30) return res.status(429).json({ error: 'كثرة رفع الصور — حاول بعد دقيقة' });
  arr.push(now);
  if (hits.size > 10_000) hits.clear();
  hits.set(ip, arr);
  next();
});

// رفع صور المنتجات/المتاجر:
// تُضغط بالخادم (أقصى 640px + جودة 74%) وتُحفظ كملف مخدوم في public/uploads
// وتُرجع المسار `/uploads/xxx.jpg` — وبدل data-URI في قاعدة البيانات هكذا لا يتضخم الجدول.
// على بيئات مؤقتة القرصي (serverless) ترجع fallback بسورس base64.
r.post('/upload', auth, roles('vendor'), async (req, res) => {
  const files = Array.isArray(req.body?.files) ? req.body.files : [];
  if (!files.length) return res.status(400).json({ error: 'ماكو صورة مرفوعة' });
  const urls = [];
  for (const f of files.slice(0, 8)) {
    const url = await storeImage(f);
    if (url) urls.push(url);
  }
  if (!urls.length) return res.status(400).json({ error: 'الصور غير صالحة — جرّب غيرها' });
  res.json({ urls });
});

export default r;