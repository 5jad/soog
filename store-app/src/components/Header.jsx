import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useApp } from '../ctx';

export default function Header() {
  const { me, cartN, favs, setCartOpen, setLoginOpen, logout } = useApp();
  const [q, setQ] = useState('');
  const [menu, setMenu] = useState(false);
  const nav = useNavigate();
  const loc = useLocation();

  const go = (p) => { nav(p); setMenu(false); };
  const doSearch = (ev) => { ev.preventDefault(); if (q.trim()) nav('/search?q=' + encodeURIComponent(q.trim())); };
  const is = (p) => loc.pathname === p;
  const tab = (p, l, on) => <a className={on ? 'on' : ''} onClick={() => go(p)} href={'#' + p}>{l}</a>;

  return (
    <header className="top">
      <div className="row1">
        <a className="brand" href="#/" onClick={(e) => { e.preventDefault(); nav('/'); }}>
          <span className="brand-ic">🛍️</span><span className="brand-tt">زبون</span>
        </a>
        <form className="search" onSubmit={doSearch}>
          <input value={q} onChange={(e) => setQ(e.target.value)} type="search" placeholder="ابحث عن منتج أو محل…" />
          <button type="submit">🔍</button>
        </form>
        <div className="acts">
          <button title="المفضلة" onClick={() => go('/fav')}>❤️{favs.length ? <span className="badge">{favs.length}</span> : null}</button>
          <button title="السلة" onClick={() => setCartOpen(true)}>🛒{cartN ? <span className="badge">{cartN}</span> : null}</button>
          <button className="userb" onClick={() => me ? setMenu(!menu) : setLoginOpen(true)}>
            👤<span>{me ? ' ' + me.name.split(' ')[0] : ''}</span>
          </button>
        </div>
      </div>
      <div className="row2"><div className="row2-in">
        {tab('/', 'الرئيسية', loc.pathname === '/')}
        {tab('/stores', 'المتاجر', is('/stores') || loc.pathname.startsWith('/stores/'))}
        {tab('/prods', 'كل المنتجات', is('/prods'))}
        {tab('/offers', '🔥 العروض', is('/offers'))}
        <a href="/">الصفحة الرسمية</a>
      </div></div>
      {menu && (
        <div className="user-pop">
          <a href="#/orders" onClick={() => go('/orders')}>📦 طلباتي</a>
          <a href="#/fav" onClick={() => go('/fav')}>❤️ المفضلة</a>
          <a href="#/profile" onClick={() => go('/profile')}>👤 حسابي</a>
          <a href="#logout" onClick={() => { logout(); go('/'); }}>🚪 خروج</a>
        </div>
      )}
    </header>
  );
}