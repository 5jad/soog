import { createContext, useContext, useRef, useState, useCallback, useEffect } from 'react';
import { api } from './api';

const Ctx = createContext(null);
export const useApp = () => useContext(Ctx);

export function AppProvider({ children }) {
  const [token, setToken] = useState(localStorage.zaboon_token || '');
  const [me, setMe] = useState(() => { try { return JSON.parse(localStorage.zaboon_me || 'null'); } catch (_) { return null; } });
  const [cartN, setCartN] = useState(0);
  const [favs, setFavs] = useState([]);
  const [toast, setToast] = useState(null);
  const [prodId, setProdId] = useState(null);
  const [cartOpen, setCartOpen] = useState(false);
  const [loginOpen, setLoginOpen] = useState(false);
  const tt = useRef();

  const notify = useCallback((msg, kind = '') => {
    setToast({ msg, kind });
    clearTimeout(tt.current);
    tt.current = setTimeout(() => setToast(null), 3200);
  }, []);

  const login = useCallback((d) => {
    localStorage.zaboon_token = d.token;
    localStorage.zaboon_me = JSON.stringify(d.user || d.me || null);
    setToken(d.token); setMe(d.user || d.me || null);
    setLoginOpen(false);
    notify('مرحباً بك 👋', 'ok');
  }, [notify]);

  const logout = useCallback(() => {
    delete localStorage.zaboon_token; delete localStorage.zaboon_me;
    setToken(''); setMe(null); setCartN(0); setFavs([]);
    notify('خرجت من الحساب');
  }, [notify]);

  const refreshCart = useCallback(async () => {
    if (!localStorage.zaboon_token) { setCartN(0); return; }
    try {
      const d = await api('/api/customer/cart');
      setCartN(d.items.reduce((a, b) => a + b.qty, 0));
    } catch (_) {}
  }, []);

  const refreshFav = useCallback(async () => {
    if (!localStorage.zaboon_token) { setFavs([]); return; }
    try {
      const d = await api('/api/customer/favorites');
      setFavs((d.favorites || d.products || []).map(x => x.product_id ?? x.id));
    } catch (_) {}
  }, []);

  useEffect(() => { refreshCart(); refreshFav(); }, [token, refreshCart, refreshFav]);

  const toggleFav = useCallback(async (id) => {
    if (!localStorage.zaboon_token) { setLoginOpen(true); notify('سجّل دخولك أولاً', 'err'); return; }
    try {
      const on = favs.includes(id);
      if (on) { await api('/api/customer/favorites/' + id, { method: 'DELETE' }); setFavs(f => f.filter(x => x !== id)); notify('أزيلت من المفضلة'); }
      else { await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: id }) }); setFavs(f => [...f, id]); notify('أضيفت للمفضلة ❤️', 'ok'); }
    } catch (e) { notify(e.message, 'err'); }
  }, [favs, notify]);

  const addToCart = useCallback(async (pid, variantId = null, label = null, qty = 1) => {
    if (!localStorage.zaboon_token) { setLoginOpen(true); notify('سجّل دخولك أولاً', 'err'); return false; }
    try {
      const d = await api('/api/customer/cart', { method: 'POST', body: JSON.stringify({ product_id: pid, variant_id: variantId, variant_label: label, qty }) });
      setCartN(d.count);
      notify('أضيف للسلة ✓', 'ok');
      return true;
    } catch (e) { notify(e.message, 'err'); return false; }
  }, [notify]);

  const v = {
    token, me, cartN, favs, toast, prodId, cartOpen, loginOpen,
    notify, login, logout, refreshCart, refreshFav, toggleFav, addToCart,
    setProdId, setCartOpen, setLoginOpen,
  };
  return <Ctx.Provider value={v}>{children}</Ctx.Provider>;
}