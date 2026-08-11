import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api } from '../api';
import { M } from '../ui';

export default function Layout() {
  const { me, cartN, favs, notifN, setLoginOpen } = useApp();
  const [storesN, setStoresN] = useState(0);
  const [sq, setSq] = useState('');
  const nav = useNavigate();
  const loc = useLocation();
  const p = loc.pathname;
  const is = (x) => p === x || (x !== '/' && p.startsWith(x));

  useEffect(() => { api('/api/stores').then(d => setStoresN((d.stores || []).length)).catch(() => {}); }, []);

  const go = (x) => nav(x);
  const hasRoles = me && me.roles && me.roles.filter(r => r !== 'customer').length;
  const doSearch = (e) => {
    e.preventDefault();
    const q = sq.trim();
    if (!q) return;
    setSq('');
    nav('/search?q=' + encodeURIComponent(q));
  };

  return (
    <>
      <header className="top">
        <div className="top-in">
          <a className="hbrand" title="زبون — الرئيسية" onClick={() => go('/')}>
            <span className="hb-logo">ز</span>
            <span className="hb-t">زبون</span>
          </a>
          <div className="top-pill"><M n="location_on" s={14} c="var(--primary)" w={600} />واسط · الكوت</div>
          <span className="top-count">{storesN} متجر متاح</span>
          <form className="hsearch" onSubmit={doSearch} role="search">
            <M n="search" s={19} c="var(--muted)" w={600} />
            <input value={sq} onChange={e => setSq(e.target.value)} placeholder="ابحث عن منتج أو متجر…" aria-label="بحث" />
            <button type="submit" aria-label="بحث"><M n="arrow_forward" s={18} w={600} /></button>
          </form>
          <div className="top-acts">
            <button className="i-btn" title="الإشعارات" onClick={() => go('/notifications')}><M n="notifications" s={20} w={500} />{notifN ? <span className="badge">{notifN}</span> : null}</button>
            <button className="i-btn" title="السلة" onClick={() => go('/cart')}>
              <span id="cartSink" key={cartN} className="cart-sink"><M n="shopping_cart" s={20} w={500} /></span>
              {cartN ? <span className="badge">{cartN}</span> : null}
            </button>
            <button className="i-btn" title="حسابي" onClick={() => me ? go('/account') : setLoginOpen(true)}>
              <M n={me ? "person" : "person_outline"} s={20} w={500} />
            </button>
          </div>
        </div>
        <nav className="dnav" aria-label="التنقل الرئيسي">
          <a className={is('/') && !is('/cart') ? 'on' : ''} onClick={() => go('/')}><M n="home" s={17} />الرئيسية</a>
          <a className={is('/prods') ? 'on' : ''} onClick={() => go('/prods')}><M n="inventory_2" s={17} />المنتجات</a>
          <a className={is('/offers') ? 'on' : ''} onClick={() => go('/offers')}><M n="local_fire_department" s={17} />العروض</a>
          <a className={is('/stores') && !is('/stores/') ? 'on' : ''} onClick={() => go('/stores')}><M n="storefront" s={17} />المتاجر</a>
          <a className={is('/cart') ? 'on' : ''} onClick={() => go('/cart')}><M n="shopping_cart" s={17} />السلة{cartN ? ` (${cartN})` : ''}</a>
          <a className={is('/fav') ? 'on' : ''} onClick={() => go('/fav')}><M n="favorite" s={17} fill={is('/fav')} />المفضلة{favs.length ? ` (${favs.length})` : ''}</a>
          <a className={is('/orders') ? 'on' : ''} onClick={() => go('/orders')}><M n="receipt_long" s={17} />طلباتي</a>
          <a className={is('/points') ? 'on' : ''} onClick={() => go('/points')}><M n="stars" s={17} />نقاطي</a>
          <a className={is('/account') ? 'on' : ''} onClick={() => go('/account')}><M n="person" s={17} />حسابي</a>
          {hasRoles ? hasRoles.map(r => (
            <a key={r} onClick={() => go('/' + (r === 'vendor' ? 'vendor' : r === 'delivery' ? 'delivery' : 'admin'))}>
              <M n={r === 'vendor' ? 'store' : r === 'delivery' ? 'two_wheeler' : 'shield'} s={17} />
              لوحة {r === 'vendor' ? 'التاجر' : r === 'delivery' ? 'المندوب' : 'الأدمن'}
            </a>
          )) : null}
        </nav>
      </header>
      <BottomNav />
      <CartFab />
    </>
  );
}

function BottomNav() {
  const loc = useLocation();
  const nav = useNavigate();
  const { cartN, favs } = useApp();
  const p = loc.pathname;
  const on = (x) => p === x || (x !== '/' && p.startsWith(x));
  const items = [
    ['home', 'الرئيسية', '/', on('/') && !['/cart'].includes(p)],
    ['storefront', 'المتاجر', '/stores', on('/stores')],
    ['shopping_cart', 'السلة', '/cart', on('/cart'), cartN],
    ['favorite', 'المفضلة', '/fav', on('/fav'), favs.length],
    ['person', 'حسابي', '/account', on('/account') || on('/orders')],
  ];
  return (
    <nav className="bnav">
      <div className="bnav-in">
        {items.map(([ic, l, to, selected, badge]) => (
          <button key={to} className={`bnav-b ${selected ? 'on' : ''}`} onClick={() => nav(to)}>
            <span className="bv">
              <M n={ic} s={22} fill={selected} w={selected ? 600 : 400} h={0} />
              {badge ? <span className="cb">{badge}</span> : null}
            </span>
            {l}
          </button>
        ))}
      </div>
    </nav>
  );
}

function CartFab() {
  const { cartN } = useApp();
  const nav = useNavigate();
  const loc = useLocation();
  if (!cartN || loc.pathname === '/cart') return null;
  return (
    <button className="fab" onClick={() => nav('/cart')}>
      <M n="shopping_cart" s={26} c="#fff" w={600} />
      <span className="cb">{cartN}</span>
    </button>
  );
}