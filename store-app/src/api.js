export const api = async (path, opts = {}) => {
  const h = { 'Content-Type': 'application/json' };
  if (localStorage.zaboon_token) h.Authorization = 'Bearer ' + localStorage.zaboon_token;
  const r = await fetch(path, { ...opts, headers: { ...h, ...(opts.headers || {}) } });
  let d = {};
  try { d = await r.json(); } catch (_) {}
  if (!r.ok) throw new Error((d && d.error) || 'مشكلة اتصال بالسيرفر');
  return d;
};

export const fmt = (n) => (Number(n) || 0).toLocaleString('ar-IQ') + ' د.ع';
export const priceOf = (p) => (p.has_offer && p.offer_price) ? p.offer_price : p.price;
export const pct = (p) => (p.offer_percent ? Math.round(p.offer_percent)
  : (p.has_offer && p.offer_price && p.price ? Math.round((1 - p.offer_price / p.price) * 100) : 0));
export const U = (s) => s && s.startsWith('data:') ? s : (s && s.startsWith('/') ? s : null);
export const ST = {
  new: 'جديد', pending: 'قيد التحضير', ready: 'جاهز', delivering: 'بالتوصيل',
  delivered: 'تم التسليم', cancelled: 'ملغي', returned: 'مرتجع',
};