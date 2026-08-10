import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';

export default function BottomNav() {
  const loc = useLocation();
  const nav = useNavigate();
  const { cartN, setCartOpen } = useApp();
  const p = loc.pathname;
  const T = (to, ic, l, on, extra = null) => (
    <button className={on ? 'on' : ''} onClick={() => { if (extra) extra(); else nav(to); }}>
      <span className="ic">{ic}</span>{l}
      {extra && cartN ? <span className="cbadge">{cartN}</span> : null}
    </button>
  );
  return (
    <nav className="bnav"><div className="in">
      {T('/', '🏠', 'الرئيسية', p === '/')}
      {T('/stores', '🏬', 'المتاجر', p === '/stores' || p.startsWith('/stores/'))}
      {T('/', '🛒', 'السلة', false, () => setCartOpen(true))}
      {T('/fav', '❤️', 'المفضلة', p === '/fav')}
      {T('/profile', '👤', 'حسابي', p === '/profile')}
    </div></nav>
  );
}