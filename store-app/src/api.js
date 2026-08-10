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
  : (p.has_offer && p.offer_price && p.price ? Math.round(100 - (p.offer_price / p.price) * 100) : 0));
export const U = (s) => s && s.startsWith('data:') ? s : (s && s.startsWith('/') ? s : null);
export const STAT = {
  new: ['جديد', 'st-new'], pending: ['قيد التحضير', 'st-pending'], ready: ['جاهز', 'st-ready'],
  delivering: ['بالتوصيل', 'st-delivering'], delivered: ['تم التسليم', 'st-delivered'],
  cancelled: ['ملغي', 'st-cancelled'], returned: ['مرتجع', 'st-returned'],
};
export const STAT_ORDER = ['new', 'pending', 'ready', 'delivering', 'delivered'];
export const timeAgo = (iso) => {
  if (!iso) return '';
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return 'الآن';
  if (s < 3600) return `منذ ${Math.floor(s / 60)} د`;
  if (s < 86400) return `منذ ${Math.floor(s / 3600)} س`;
  return `منذ ${Math.floor(s / 86400)} يوم`;
};
export const copy = async (txt) => {
  try { await navigator.clipboard.writeText(txt); return true; } catch (_) { return false; }
};