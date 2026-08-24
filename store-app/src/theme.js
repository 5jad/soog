/* ═══ الوضع الليلي/النهاري — مصدر واحد للتحكم ═══
   الأولوية: اختيار المستخدم المحفوظ ← تفضيل النظام */
const KEY = 'zaboon_theme';

export const getTheme = () => {
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === 'dark' || saved === 'light') return saved;
  } catch (_) {}
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
};

export const applyTheme = (t) => {
  document.documentElement.classList.toggle('dark', t === 'dark');
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', t === 'dark' ? '#14172A' : '#23273E');
};

export const setTheme = (t) => {
  applyTheme(t);
  try { localStorage.setItem(KEY, t); } catch (_) {}
};

export const toggleTheme = () => {
  const next = document.documentElement.classList.contains('dark') ? 'light' : 'dark';
  setTheme(next);
  return next;
};

/* تهيئة مبكرة — تُستدعى قبل mount حتى ما يصير وميض */
export const initTheme = () => applyTheme(getTheme());
