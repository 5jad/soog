import { Router } from 'express';
import sharp from 'sharp';
import { auth, roles } from '../middleware.js';

const r = Router();

// رفع صور المنتجات/المتاجر:
// تُضغط بالخادم (أقصى 640px + جودة 74%) وتُرجع data-URI يُحفظ داخل قاعدة البيانات
// هكذا الصورة تدوم على السحابة (Vercel/Neon) ولا تعتمد على قرص مؤقت أو حاسوب
r.post('/upload', auth, roles('vendor'), async (req, res) => {
  const files = Array.isArray(req.body?.files) ? req.body.files : [];
  if (!files.length) return res.status(400).json({ error: 'ماكو صورة مرفوعة' });
  const urls = [];
  for (const f of files.slice(0, 8)) {
    if (typeof f !== 'string' || f.length < 100) continue;
    const m = f.match(/^data:image\/(png|jpe?g|webp);base64,(.+)$/is);
    const b64 = m ? m[2] : f;
    const raw = Buffer.from(b64, 'base64');
    if (!raw.length) continue;
    try {
      const info = await sharp(raw).rotate().metadata();
      const maxDim = Math.max(info.width || 0, info.height || 0);
      let img = sharp(raw).rotate();
      if (maxDim > 640) img = img.resize({ width: 640, height: 640, fit: 'inside', withoutEnlargement: true });
      const out = await img.jpeg({ quality: 74 }).toBuffer();
      urls.push(`data:image/jpeg;base64,${out.toString('base64')}`);
    } catch (_) { /* صورة تالفة — نتخطاها */ }
  }
  if (!urls.length) return res.status(400).json({ error: 'الصور غير صالحة — جرّب غيرها' });
  res.json({ urls });
});

export default r;