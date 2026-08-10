import React, { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api } from '../api';

export default function Layout() {
  const { me, cartN, favs, notifN, setCartOpen, setLoginOpen, logout } = useApp();
  const [q, setQ] = useState('');
  const [cats, setCats] = useState([]);
  const [menu, setMenu] = useState(false);
  const nav = useNavigate();
  const loc = useLocation();
  const is = (p) => loc.pathname === p || (p !== '/' && loc.pathname.startsWith(p));

  useEffect(() => { api('/api/categories').then(d => setCats((d.categories || []).slice(0, 8))).catch(() => {}); }, []);

  const doSearch = (ev) => { ev.preventDefault(); if (q.trim()) nav('/search?q=' + encodeURIComponent(q.trim())); };
  const go = (p) => { setMenu(false); nav(p); };

  const tabs = [
    ['/', 'الرئيسية', is('/') && !is('/prods') && !is('/stores') && !is('/fav') && !is('/orders') && !is('/account') && !is('/points') && !is('/notifications')],
    ['/prods', 'كل المنتجات', is('/prods') || is('/cat') || is('/search') || is('/offers')],
    ['/stores', 'المتاجر', is('/stores')],
    ['/fav', 'المفضلة', is('/fav')],
    ['/points', 'نقاطي', is('/points')],
  ];
  const hasRoles = me && me.roles && me.roles.filter(r => r !== 'customer').length;

  return (
    <header className="top">
      <div className="row1">
        <a className="brand" onClick={() => go('/')}>
          <span className="brand-ic">🛍️</span><span className="brand-tt">زبون</span>
        </a>
        <form className="search" onSubmit={doSearch}>
          <input value={q} onChange={(e) => setQ(e.target.value)} type="search" placeholder="ابحث عن منتج أو محل…" />
          <button type="submit">🔍</button>
        </form>
        <div className="acts">
          <button className="i-btn" title="الإشعارات" onClick={() => go('/notifications')}>🔔{notifN ? <span className="badge">{notifN}</span> : null}</button>
          <button className="i-btn" title="السلة" onClick={() => setCartOpen(true)}>🛒{cartN ? <span className="badge">{cartN}</span> : null}</button>
          <button className="i-btn user-btn" onClick={() => me ? setMenu(!menu) : setLoginOpen(true)}>
            👤<span>{me ? me.name.split(' ')[0] : 'دخول'}</span>
          </button>
        </div>
      </div>
      <div className="row2"><div className="row2-in">
        {tabs.map(([p, t, on]) => <a key={p} className={`nav-l ${on ? 'on' : ''}`} onClick={() => go(p)}>{t}</a>)}
        {cats.map(c => <a key={c.id} className="nav-l" onClick={() => go('/cat/' + c.id)}>
          <span className="em">{c.icon || '📦'}</span>{c.name}</a>)}
        {hasRoles ? hasRoles.map(r => (
          <a key={r} className="nav-l" onClick={() => go('/' + (r === 'vendor' ? 'vendor' : r === 'delivery' ? 'delivery' : 'admin'))}>
            {r === 'vendor' ? '🏪' : r === 'delivery' ? '🛵' : '🛡️'} لوحة {r === 'vendor' ? 'التاجر' : r === 'delivery' ? 'المندوب' : 'الأدمن'}
          </a>
        )) : null}
      </div></div>
      {menu && (
        <div className="pop">
          <a onClick={() => go('/orders')}>📦 طلباتي</a>
          <a onClick={() => go('/fav')}>❤️ المفضلة</a>
          <a onClick={() => go('/points')}>🎁 نقاطي</a>
          <a onClick={() => go('/chat')}>💬 المحادثات</a>
          <a onClick={() => go('/account')}>👤 حسابي</a>
          <a className="danger" onClick={() => logout()}>🚪 خروج</a>
        </div>
      )}
      <BottomNav />
    </header>
  );
}

function BottomNav() {
  const loc = useLocation();
  const nav = useNavigate();
  const { cartN, setCartOpen, notifN } = useApp();
  const p = loc.pathname;
  const b = (to, ic, l, on, extra) => (
    <button className={on ? 'on' : ''} onClick={() => extra ? extra() : nav(to)}>
      <span className="ic">{ic}</span>{l}
      {extra && cartN ? <span className="cbadge">{cartN}</span> : null}
      {to === '/notifications' && !extra && notifN ? <span className="cbadge">{notifN}</span> : null}
    </button>
  );
  return (
    <nav className="bnav"><div className="in">
      {b('/', '🏠', 'الرئيسية', p === '/')}
      {b('/stores', '🏬', 'المتاجر', p.startsWith('/stores'))}
      {b('/', '🛒', 'السلة', false, () => setCartOpen(true))}
      {b('/fav', '❤️', 'المفضلة', p === '/fav')}
      {b('/account', '👤', 'حسابي', p === '/account' || p === '/orders')}
    </div></nav>
  );
}