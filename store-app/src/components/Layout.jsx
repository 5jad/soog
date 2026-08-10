import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api } from '../api';
import { M } from '../ui';

export default function Layout() {
  const { me, cartN, favs, notifN, setLoginOpen } = useApp();
  const [storesN, setStoresN] = useState(0);
  const nav = useNavigate();
  const loc = useLocation();
  const p = loc.pathname;
  const is = (x) => p === x || (x !== '/' && p.startsWith(x));

  useEffect(() => { api('/api/stores').then(d => setStoresN((d.stores || []).length)).catch(() => {}); }, []);

  const go = (x) => nav(x);
  const hasRoles = me && me.roles && me.roles.filter(r => r !== 'customer').length;

  return (
    <>
      <header className="top">
        <div className="top-in">
          <div className="top-pill"><M n="location_on" s={14} c="var(--primary)" w={600} />واسط · الكوت</div>
          <span className="top-count">{storesN} متجر متاح</span>
          <div className="top-acts">
            <button className="i-btn" title="الإشعارات" onClick={() => go('/notifications')}><M n="notifications" s={20} w={500} />{notifN ? <span className="badge">{notifN}</span> : null}</button>
            <button className="i-btn" title="السلة" onClick={() => go('/cart')}><M n="shopping_cart" s={20} w={500} />{cartN ? <span className="badge">{cartN}</span> : null}</button>
            <button className="i-btn" title="حسابي" onClick={() => me ? go('/account') : setLoginOpen(true)}>
              <M n={me ? "person" : "person_outline"} s={20} w={500} />
            </button>
          </div>
        </div>
        <div className="dnav">
          <a className={is('/') && !is('/cart') ? 'on' : ''} onClick={() => go('/')}><M n="home" s={17} />الرئيسية</a>
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
        </div>
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