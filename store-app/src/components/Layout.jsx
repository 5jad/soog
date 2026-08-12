import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { M } from '../ui';

function AccountDropdown() {
  const { me, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [open, setOpen] = useState(false);
  
  const adminUrl = import.meta.env.VITE_ADMIN_URL;

  if (!me) {
    return (
      <button className="i-btn" title="حسابي" onClick={() => setLoginOpen(true)}>
        <M n="person_outline" s={20} w={500} />
      </button>
    );
  }

  const isVendor = me.roles && me.roles.includes('vendor');
  const isDelivery = me.roles && me.roles.includes('delivery');
  const isAdmin = me.roles && me.roles.includes('admin');

  return (
    <div className="acc-drop" onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button className="i-btn" title="حسابي" onClick={() => setOpen(!open)}>
        <M n="person" s={20} w={500} />
      </button>
      {open && (
        <div className="acc-menu glass-panel">
          <a onClick={() => { setOpen(false); nav('/account'); }}><M n="person" s={17} /> الملف الشخصي</a>
          <a onClick={() => { setOpen(false); nav('/orders'); }}><M n="receipt_long" s={17} /> طلباتي</a>
          <a onClick={() => { setOpen(false); nav('/points'); }}><M n="stars" s={17} /> نقاطي</a>
          {isVendor && <a onClick={() => { setOpen(false); nav('/vendor'); }}><M n="store" s={17} /> لوحة التاجر</a>}
          {isDelivery && <a onClick={() => { setOpen(false); nav('/delivery'); }}><M n="two_wheeler" s={17} /> لوحة المندوب</a>}
          {isAdmin && (
            <a href={adminUrl || '#'} className={!adminUrl ? 'disabled' : ''} target="_blank" rel="noreferrer">
              <M n="shield" s={17} /> لوحة الإدارة
            </a>
          )}
          <div className="acc-menu-div" />
          <a onClick={() => { localStorage.clear(); window.location.href = '/'; }} style={{ color: 'var(--danger)' }}><M n="logout" s={17} c="var(--danger)" /> تسجيل الخروج</a>
        </div>
      )}
    </div>
  );
}

export default function Layout() {
  const { cartN, notifN, me, setLoginOpen } = useApp();
  const [sq, setSq] = useState('');
  const nav = useNavigate();
  const loc = useLocation();
  const p = loc.pathname;
  const is = (x) => p === x || (x !== '/' && p.startsWith(x));

  // زجاج الهيدر يظهر فقط بعد التمرير — خلفية صلبة عند أعلى الصفحة (قاعدة التباين)
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 0);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const go = (x) => nav(x);
  const doSearch = (e) => {
    e.preventDefault();
    const q = sq.trim();
    if (!q) return;
    setSq('');
    nav('/search?q=' + encodeURIComponent(q));
  };

  return (
    <>
      <header className={'top' + (scrolled ? ' glass-panel' : '')}>
        <div className="top-in">
          <a className="hbrand" title="زبون — الرئيسية" onClick={() => go('/')}>
            <span className="hb-logo">ز</span>
            <span className="hb-t">زبون</span>
          </a>
          <form className="hsearch desktop-search" onSubmit={doSearch} role="search">
            <M n="search" s={19} c="var(--muted)" w={600} />
            <input value={sq} onChange={e => setSq(e.target.value)} placeholder="ابحث عن منتج أو متجر…" aria-label="بحث" />
            <button type="submit" aria-label="بحث"><M n="arrow_forward" s={18} w={600} /></button>
          </form>
          <div className="top-acts">
            <button className="i-btn" title="الإشعارات" onClick={() => go('/notifications')}><M n="notifications" s={20} w={500} />{notifN ? <span className="badge">{notifN}</span> : null}</button>
            <button className="i-btn d-hide-m" title="السلة" onClick={() => go('/cart')}>
              <span id="cartSink" key={cartN} className="cart-sink"><M n="shopping_cart" s={20} w={500} /></span>
              {cartN ? <span className="badge">{cartN}</span> : null}
            </button>
            <AccountDropdown />
          </div>
        </div>
        <form className="hsearch mobile-search" onSubmit={doSearch} role="search">
          <M n="search" s={19} c="var(--muted)" w={600} />
          <input value={sq} onChange={e => setSq(e.target.value)} placeholder="ابحث عن منتج أو متجر…" aria-label="بحث" />
          <button type="submit" aria-label="بحث"><M n="arrow_forward" s={18} w={600} /></button>
        </form>
        <nav className="desktop-nav" aria-label="التنقل الرئيسي">
          <a className={is('/') && !is('/cart') ? 'on' : ''} onClick={() => go('/')}>الرئيسية</a>
          <a className={is('/offers') ? 'on' : ''} onClick={() => go('/offers')}>العروض</a>
          <a className={is('/stores') && !is('/stores/') ? 'on' : ''} onClick={() => go('/stores')}>المتاجر</a>
          <a className={is('/fav') ? 'on' : ''} onClick={() => go('/fav')}>المفضلة</a>
          <a className={is('/account') ? 'on' : ''} onClick={() => me ? go('/account') : setLoginOpen(true)}>حسابي</a>
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
  const { me, cartN, favs, setLoginOpen } = useApp();
  const [moreOpen, setMoreOpen] = useState(false);
  const p = loc.pathname;
  const on = (x) => p === x || (x !== '/' && p.startsWith(x));
  
  const isVendor = me?.roles?.includes('vendor');
  const isDelivery = me?.roles?.includes('delivery');
  const isAdmin = me?.roles?.includes('admin');
  const adminUrl = import.meta.env.VITE_ADMIN_URL;

  return (
    <>
      {moreOpen && (
        <>
          <div className="bnav-overlay" onClick={() => setMoreOpen(false)} />
          <div className="bnav-more-menu">
            <a onClick={() => { setMoreOpen(false); nav('/offers'); }}><M n="local_fire_department" s={17} /> العروض</a>
            {me && <a onClick={() => { setMoreOpen(false); nav('/orders'); }}><M n="receipt_long" s={17} /> طلباتي</a>}
            {me && <a onClick={() => { setMoreOpen(false); nav('/points'); }}><M n="stars" s={17} /> نقاطي</a>}
            {isVendor && <a onClick={() => { setMoreOpen(false); nav('/vendor'); }}><M n="store" s={17} /> لوحة التاجر</a>}
            {isDelivery && <a onClick={() => { setMoreOpen(false); nav('/delivery'); }}><M n="two_wheeler" s={17} /> لوحة المندوب</a>}
            {isAdmin && (
              <a href={adminUrl || '#'} className={!adminUrl ? 'disabled' : ''} target="_blank" rel="noreferrer">
                <M n="shield" s={17} /> لوحة الإدارة
              </a>
            )}
            <div className="acc-menu-div" />
            {me ? (
               <a onClick={() => { localStorage.clear(); window.location.href = '/'; }} style={{ color: 'var(--danger)' }}><M n="logout" s={17} c="var(--danger)" /> تسجيل الخروج</a>
            ) : (
               <a onClick={() => { setMoreOpen(false); setLoginOpen(true); }}><M n="login" s={17} /> تسجيل الدخول</a>
            )}
          </div>
        </>
      )}
      <nav className="bnav">
        <div className="bnav-in">
          <button className={`bnav-b ${on('/') && !on('/cart') ? 'on' : ''}`} onClick={() => nav('/')}>
            <span className="bv"><M n="home" s={22} fill={on('/') && !on('/cart')} w={on('/') && !on('/cart') ? 600 : 400} /></span>
            الرئيسية
          </button>
          <button className={`bnav-b ${on('/stores') ? 'on' : ''}`} onClick={() => nav('/stores')}>
            <span className="bv"><M n="storefront" s={22} fill={on('/stores')} w={on('/stores') ? 600 : 400} /></span>
            المتاجر
          </button>
          <button className={`bnav-b ${on('/cart') ? 'on' : ''}`} onClick={() => nav('/cart')}>
            <span className="bv">
              <M n="shopping_cart" s={22} fill={on('/cart')} w={on('/cart') ? 600 : 400} />
              {cartN ? <span className="cb">{cartN}</span> : null}
            </span>
            السلة
          </button>
          <button className={`bnav-b ${on('/fav') ? 'on' : ''}`} onClick={() => nav('/fav')}>
            <span className="bv">
              <M n="favorite" s={22} fill={on('/fav')} w={on('/fav') ? 600 : 400} />
              {favs.length ? <span className="cb">{favs.length}</span> : null}
            </span>
            المفضلة
          </button>
          <button className={`bnav-b ${moreOpen || (!on('/') && !on('/stores') && !on('/cart') && !on('/fav')) ? 'on' : ''}`} onClick={() => setMoreOpen(!moreOpen)}>
            <span className="bv"><M n="more_horiz" s={22} w={600} /></span>
            المزيد
          </button>
        </div>
      </nav>
    </>
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
