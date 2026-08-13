import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

// ═══════════ تخزين صور مركزي: base64 → ملف مخدوم في public/uploads ═══════════
// يستخدمه routes/uploads.js (رفع مباشر) وscripts/migrate-images.js (تحويل الموجودة)
// على بيئات read-only (serverless) نرجع data-URI كـ fallback حتى لا تنكسر الدالة.

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const UPLOAD_DIR = path.join(__dirname, 'public', 'uploads');
export const UPLOAD_BASE = '/uploads/';
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const MAX_RAW_BYTES = 6 * 1024 * 1024;

/** هل القيمة صورة base64 مخزنة (data-URI أو /9j القديم)؟ */
export function isBase64Image(v) {
  return typeof v === 'string' && (v.startsWith('data:image/') || v.startsWith('/9j'));
}

/** الشكل القياسي المخزن: `/uploads/xxx.jpg` أو إيموجي/نص (يبقى كما هو) */
export function isStoredPath(v) {
  return typeof v === 'string' && (v.startsWith(UPLOAD_BASE) || v.startsWith('data:image/') || v.startsWith('/9j'));
}

/** ضغط base64 → كتابة ملف وإرجاع مساره، أو null عند الفشل */
export async function storeImage(dataUri) {
  if (!isBase64Image(dataUri) || dataUri.length < 100) return null;
  const m = dataUri.match(/^data:image\/(png|jpe?g|webp);base64,(.+)$/is);
  const b64 = m ? m[2] : dataUri;
  if (b64.length > MAX_RAW_BYTES * 1.34) return null;
  const raw = Buffer.from(b64, 'base64');
  if (!raw.length || raw.length > MAX_RAW_BYTES) return null;
  try {
    const info = await sharp(raw).rotate().metadata();
    const maxDim = Math.max(info.width || 0, info.height || 0);
    let img = sharp(raw).rotate();
    if (maxDim > 640) img = img.resize({ width: 640, height: 640, fit: 'inside', withoutEnlargement: true });
    const out = await img.jpeg({ quality: 74 }).toBuffer();
    const name = `img_${Date.now()}_${crypto.randomBytes(8).toString('hex')}.jpg`;
    let url = `${UPLOAD_BASE}${name}`;
    try {
      await fs.promises.writeFile(path.join(UPLOAD_DIR, name), out);
    } catch (_) {
      url = `data:image/jpeg;base64,${out.toString('base64')}`;
    }
    return url;
  } catch (_) {
    return null;
  }
}

/** تحويل قيمة واحدة (نص أو مصفوفة نصوص) — يرجع القيمة الجديدة أو null إن لم تتغير */
export async function convertValue(v) {
  if (typeof v === 'string') {
    if (!isBase64Image(v)) return null;
    const url = await storeImage(v);
    return url || '📦';
  }
  if (Array.isArray(v)) {
    let changed = false;
    const out = [];
    for (const x of v) {
      if (isBase64Image(x)) {
        const url = await storeImage(x);
        if (url) { out.push(url); changed = true; continue; }
      }
      out.push(x);
    }
    return changed ? out : null;
  }
  return null;
}