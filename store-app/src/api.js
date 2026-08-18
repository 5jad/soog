/* ═══════════════════════════════════════════════════════════════════════════
   API — الطبقة المركزية الوحيدة للشبكة + أدوات العرض
   كل طلب يمر من هنا ولا http مباشر في الصفحات
   ═══════════════════════════════════════════════════════════════════════════ */

export const TOKEN_KEY = 'zaboon_token';

export const api = async (path, opts = {}) => {
  const h = { 'Content-Type': 'application/json' };
  const t = localStorage.getItem(TOKEN_KEY);
  if (t) h.Authorization = 'Bearer ' + t;
  const r = await fetch(path, { ...opts, headers: { ...h, ...(opts.headers || {}) } });
  let d = {};
  try { d = await r.json(); } catch (_) { /* رد غير JSON */ }
  if (!r.ok) throw new Error((d && d.error) || 'مشكلة اتصال بالسيرفر');
  return d;
};

/* تحويل الأرقام العربية (٠-٩ / ۰-۹) إلى إنجليزية — نمط whitelist إلزامي */
export const norm = (v) => String(v || '').replace(/[٠-٩]/g, (c) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).replace(/[۰-۹]/g, (c) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c))).trim();

export const fmt = (n) => (Number(n) || 0).toLocaleString('ar-IQ') + ' د.ع';
export const num = (n) => Number(n).toLocaleString('ar-IQ');

/* السعر الفعلي بعد العرض */
export const priceOf = (p) => (p?.has_offer && p.offer_price) ? Number(p.offer_price) : Number(p?.price || 0);

/* نسبة الخصم */
export const pct = (a, b) => {
  if (typeof a === 'object' && a !== null) {
    if (a.offer_percent) return Math.round(a.offer_percent);
    if (a.has_offer && a.offer_price && a.price) return Math.round(100 - (Number(a.offer_price) / Number(a.price)) * 100);
    return 0;
  }
  const x = Number(a), y = Number(b);
  return x && y && y > 0 && y < x ? Math.round(100 - (y / x) * 100) : 0;
};

/* مصدر صورة: يقبل data:/رابط/مسار أو base64 خام (/9j…) */
export const S = (v) => {
  if (!v) return '';
  if (v.startsWith('data:') || v.startsWith('/') || v.startsWith('http')) return v;
  if (v.length > 30 && /^[A-Za-z0-9+/=]+$/.test(v)) return 'data:image/jpeg;base64,' + v;
  return '';
};

/* هل الصورة base64 خام؟ (عرض emoji بدلها قبل اكتمال التحميل) */
export const isRaw = (v) => !!(v && v.length > 30 && /^\/9j/.test(v));

/* أيقونة / وجبة للمنتجات بلا صور */
export const emojiOf = (p) => {
  const name = String(p?.name || p?.category_name || '');
  if (/لباس|قميص|بلوزه|تيشيرت|جاكيت|عباية|فستان|بجامه|هدوم|بنطلون|جينز|سوت|شرشف/i.test(name)) return '👕';
  if (/مكياج|ميكب|روج|ظلال|أحمر شفاه|عرايس|بادي|كريم|شعر|عطور|مسك|عنايه|عناية/i.test(name)) return '💄';
  if (/لعبه|لعبة|بلاي|دريل|حديد|ليجو|بيبي/i.test(name)) return '🧸';
  if (/جوال|موبايل|ايفون|سامسونج|شاحن|سماعه|سماعة|لابتوب|تابلت|كمبيوتر|شاشه|شاشة|باور/i.test(name)) return '📱';
  if (/ساعه|ساعة|اكسسوار|حقيبه|حقيبة|محفظه|مفاتيح|نظاره|نظارة|خواتم|اساور/i.test(name)) return '🛍️';
  if (/حلويات|شوكولاته|شوكولاتة|بسكويت|سناكس|شبس|حلو|كيك|كيكه/i.test(name)) return '🍫';
  if (/منظف|تنظيف|صابون|شامبو|معطر|ديتول|كلور/i.test(name)) return '🧴';
  if (/مطبخ|قدور|طبخ|صحون|طاسات|قدر/i.test(name)) return '🍳';
  if (/كهرباء|لمبه|لمبة|خلاط|مكوى|مكواة|سخان|مروحه|مروحة|كونكت|اسلاك|محول/i.test(name)) return '🔌';
  if (/رياضه|رياضة|دمبل|ادوات|كوره|كرة|دراجه|دراجة/i.test(name)) return '⚽';
  return '📦';
};

export const STAT = {
  new: ['جديدة', 'st-new'], pending: ['قيد التحضير', 'st-pending'], ready: ['جاهزة', 'st-ready'],
  delivering: ['بالتوصيل', 'st-delivering'], delivered: ['تم التسليم', 'st-delivered'],
  cancelled: ['ملغاة', 'st-cancelled'], returned: ['مرتجعة', 'st-returned'],
};
export const STAT_ORDER = ['new', 'pending', 'ready', 'delivering', 'delivered'];
export const st = (s) => STAT[s] || [s, ''];

export const timeAgo = (iso) => {
  if (!iso) return '';
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return 'الآن';
  if (diff < 3600) return `منذ ${Math.floor(diff / 60)} د`;
  if (diff < 86400) return `منذ ${Math.floor(diff / 3600)} س`;
  return `منذ ${Math.floor(diff / 86400)} يوم`;
};

export const copy = async (txt) => {
  try { await navigator.clipboard.writeText(txt); return true; } catch (_) { return false; }
};

/* فتح المتجر (open now) يرجع لكل متجر من السيرفر */
export const openNow = (s) => !!(s && (s.is_open || s.open_now));

export const fmtDate = (iso) => {
  if (!iso) return '';
  try { return new Date(iso).toLocaleString('ar-IQ', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }); }
  catch (_) { return String(iso).slice(0, 16); }
};