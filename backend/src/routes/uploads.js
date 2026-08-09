import { Router } from 'express';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import { auth, roles } from '../middleware.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const UPLOAD_DIR = path.join(__dirname, '..', 'public', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const r = Router();

// رفع صور المنتجات — يُرسل التطبيق صور base64 (JSON) ونحفظها كملفات
r.post('/upload', auth, roles('vendor'), async (req, res) => {
  const files = Array.isArray(req.body?.files) ? req.body.files : [];
  if (!files.length) return res.status(400).json({ error: 'ماكو صورة مرفوعة' });
  const urls = [];
  for (const f of files.slice(0, 8)) {
    if (typeof f !== 'string' || f.length < 100) continue;
    const m = f.match(/^data:image\/(png|jpe?g|webp);base64,(.+)$/is);
    const b64 = m ? m[2] : f;
    const ext = m ? (m[1] === 'jpe?g' || m[1] === 'jpeg' ? 'jpg' : m[1]) : 'png';
    const data = Buffer.from(b64, 'base64');
    if (!data.length || data.length > 10 * 1024 * 1024) continue;
    const name = `img_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.${ext}`;
    fs.writeFileSync(path.join(UPLOAD_DIR, name), data);
    urls.push(`/uploads/${name}`);
  }
  if (!urls.length) return res.status(400).json({ error: 'الصور غير صالحة — جرّب غيرها' });
  res.json({ urls });
});

export default r;