/* ═══════════════════════════════════════════════════════════════════════════
   STATE — الحالة المركزية للتطبيق (نوع composable واحد)
   auth: المستخدم والرمز · cart: عداد + فتح الدراور · ui: نوافذ/بحث/توست
   ═══════════════════════════════════════════════════════════════════════════ */
import { reactive } from 'vue';
import { api, TOKEN_KEY, S } from './api';

const state = reactive({
  user: null,
  cartCount: 0,
  favsCount: 0,          // عداد المفضلة — شارة تبويب المفضلة
  loginOpen: false,
  cartDrawer: false,
  searchOpen: false,     // بحث الجوال: سطر إضافي بالهيدر
  searchText: '',
});

const toasts = reactive([]);

let toastId = 0;
export const toast = (msg, ok = true) => {
  const id = ++toastId;
  toasts.push({ id, msg, ok });
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === id);
    if (i > -1) toasts.splice(i, 1);
  }, 2800);
};

const loadMe = async () => {
  const t = localStorage.getItem(TOKEN_KEY);
  if (!t) { state.user = null; return null; }
  try {
    const { user } = await api('/api/auth/me');
    state.user = user;
    return user;
  } catch (_) {
    localStorage.removeItem(TOKEN_KEY);
    state.user = null;
    return null;
  }
};

const setToken = (t) => {
  if (t) localStorage.setItem(TOKEN_KEY, t); else localStorage.removeItem(TOKEN_KEY);
};

const logout = () => { setToken(null); state.user = null; state.cartCount = 0; };

const refreshCartCount = async () => {
  const t = localStorage.getItem(TOKEN_KEY);
  if (!t) { state.cartCount = 0; return; }
  try {
    const d = await api('/api/customer/cart');
    state.cartCount = d.items.reduce((a, b) => a + Number(b.qty || 0), 0);
  } catch (_) { /* سلة فاضية/مشكلة */ }
};

/* عداد السلة بعد أي تغيير (إضافة/إزالة/دخول) */
const bumpCart = (n) => { state.cartCount = Math.max(0, state.cartCount + (Number(n) || 0)); };

/* عداد المفضلة — يُجلب عند الإقلاع ويُحدَّث على أي إضافة/إزالة */
const refreshFavsCount = async () => {
  const t = localStorage.getItem(TOKEN_KEY);
  if (!t) { state.favsCount = 0; return; }
  try {
    const d = await api('/api/customer/favorites');
    state.favsCount = (d.products || []).length;
  } catch (_) {}
};
const bumpFavs = (n) => { state.favsCount = Math.max(0, state.favsCount + (Number(n) || 0)); };

export function useApp() {
  return {
    state,           /* حي مباشر — المكونات تعدّل نوافذ UI منه */
    toasts,
    toast,
    loadMe,
    setToken,
    logout,
    refreshCartCount,
    bumpCart,
    refreshFavsCount,
    bumpFavs,
    closeAll() { state.loginOpen = false; state.cartDrawer = false; },
  };
}

/* بيانات جاهزة (تصنيفات — تُجلب مرة واحدة) */
const cache = reactive({ categories: null, settings: null });
export const loadCategories = async (force = false) => {
  if (cache.categories && !force) return cache.categories;
  try {
    const d = await api('/api/categories');
    cache.categories = d.categories || [];
  } catch (_) { cache.categories = []; }
  return cache.categories;
};
export const categories = cache;   /* readonly عبر الـ ref نفسه */

export { S };