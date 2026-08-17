// ═══════════ حساب حالة الدوام التلقائي للمتاجر ═══════════
// العمل: if the store has work_hours enabled → compute open/closed from current Baghdad time.
// العراق بلا توقيت صيفي (UTC+3 ثابت)

const BAGHDAD_OFFSET_MIN = 3 * 60;

/// "10:30" → 630 دقيقة | يعيد null لو الصيغة خاطئة
export function parseHour(str) {
  if (!str) return null;
  const m = String(str).trim().match(/^(\d{1,2}):([0-5]\d)$/);
  if (!m) return null;
  const h = Number(m[1]);
  if (h > 23) return null;
  return h * 60 + Number(m[2]);
}

/// الدقائق الحالية بتوقيت بغداد (0..1439)
export function nowBaghdadMin() {
  const now = new Date(Date.now() + BAGHDAD_OFFSET_MIN * 60000);
  return now.getUTCHours() * 60 + now.getUTCMinutes();
}

/// المتجر مفتوح حالياً؟
/// - عليه إجازة → مغلق دائماً
/// - عنده work_hours مفعّل → حسب الوقت الحالي (يدعم دوام يقطع منتصف الليل)
/// - غير ذلك → is_open اليدوي (إعداد الأدمن/التاجر)
export function isOpenNow(store) {
  if (!store) return false;
  if (store.on_vacation) return false;
  const wh = store.work_hours;
  if (!wh || wh.enabled === false) return store.is_open !== false;
  const open = parseHour(wh.open);
  const close = parseHour(wh.close);
  if (open == null || close == null) return store.is_open !== false;
  if (open === close) return true; // 24 ساعة
  const nowMin = nowBaghdadMin();
  if (open < close) return nowMin >= open && nowMin < close;
  return nowMin >= open || nowMin < close; // يقطع منتصف الليل
}

/// يعكس الحالة المحسوبة على is_open لكل متجر — بعد الجلب مباشرة
export function withOpenNow(stores) {
  for (const s of stores) s.is_open = isOpenNow(s);
  return stores;
}