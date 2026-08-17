import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { M } from '../ui';

/* ═══ مصدر واحد للتنقل — يقرأ منه الديسكتوب والموبايل فلا ينحرفان عن بعض ═══ */
const NAV_ALL = [
  ['/', 'الرئيسية', 'home'],
  ['/offers', 'العروض', 'local_fire_department'],
  ['/stores', 'المتاجر', 'storefront'],
  ['/fav', 'المفضلة', 'favorite'],
  ['/account', 'حسابي', 'person'],
];
/* الشريط السفلي (موبايل/تابلت): 4 مسارات + زر «المزيد» — القائمة تجلب الباقي من NAV_ALL */
const BNAV_PINNED = [['/', 'home'], ['/stores', 'storefront'], ['/cart', 'shopping_cart'], ['/fav', 'favorite']];

function AccountDropdown() {
  const { me, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [open, setOpen] = useState(false);

  const adminUrl = import.meta.env.VITE_ADMIN_URL;

  if (!me) {
    return (
      <button className="icon-btn" title="حسابي" onClick={() => setLoginOpen(true)}>
        <M n="person_outline" s={20} w={500} />
      </button>
    );
  }

  const isVendor = me.roles && me.roles.includes('vendor');
  const isDelivery = me.roles && me.roles.includes('delivery');
  const isAdmin = me.roles && me.roles.includes('admin');

  return (
    <div className="dropdown" onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button className="icon-btn" title="حسابي" onClick={() => setOpen(!open)}>
        <M n="person" s={20} w={500} />
      </button>
      {open && (
        <div className="dropdown-menu">
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
          <div className="dd-div" />
          <a className="danger" onClick={() => { localStorage.clear(); window.location.href = '/'; }}><M n="logout" s={17} c="var(--danger)" /> تسجيل الخروج</a>
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
      <header className={'topbar' + (scrolled ? ' glass' : '')}>
        <div className="topbar-in">
          <a className="brand" title="زبون — الرئيسية" onClick={() => go('/')}>
            <span className="brand-logo">ز</span>
            <span className="brand-name">زبون</span>
          </a>
          <form className="search search-desktop" onSubmit={doSearch} role="search">
            <M n="search" s={19} c="var(--muted)" w={600} cls="ic" />
            <input value={sq} onChange={e => setSq(e.target.value)} placeholder="ابحث عن منتج أو متجر…" aria-label="بحث" />
            <button type="submit" className="search-go" aria-label="بحث"><M n="arrow_forward" s={18} w={600} /></button>
          </form>
          <div className="topbar-actions">
            <button className="icon-btn" title="الإشعارات" onClick={() => go('/notifications')}><M n="notifications" s={20} w={500} />{notifN ? <span className="badge-count">{notifN}</span> : null}</button>
            <button className="icon-btn d-hide-m" title="السلة" onClick={() => go('/cart')}>
              <span id="cartSink" key={cartN}><M n="shopping_cart" s={20} w={500} /></span>
              {cartN ? <span className="badge-count">{cartN}</span> : null}
            </button>
            <AccountDropdown />
          </div>
        </div>
        <form className="search search-mobile" onSubmit={doSearch} role="search">
          <M n="search" s={19} c="var(--muted)" w={600} cls="ic" />
          <input value={sq} onChange={e => setSq(e.target.value)} placeholder="ابحث عن منتج أو متجر…" aria-label="بحث" />
          <button type="submit" className="search-go" aria-label="بحث"><M n="arrow_forward" s={18} w={600} /></button>
        </form>
        <nav className="nav-desktop" aria-label="التنقل الرئيسي">
          {NAV_ALL.map(([to, t]) => {
            const act = is(to) && !(to === '/' && p.startsWith('/cart')) && !(to === '/stores' && p.startsWith('/stores/'));
            return (
              <a key={to} className={act ? 'on' : ''}
                onClick={() => to === '/account' && !me ? setLoginOpen(true) : go(to)}>{t}</a>
            );
          })}
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
  /* قائمة «المزيد» — الباقي من مصدر التنقل الواحد NAV_ALL + مناطق الأدوار */
  const moreList = NAV_ALL.filter(([to]) => to !== '/' && to !== '/stores' && to !== '/fav' && to !== '/cart');

  return (
    <>
      {moreOpen && (
        <>
          <div className="bnav-overlay" onClick={() => setMoreOpen(false)} />
          <div className="bnav-more">
            {moreList.map(([to, t, ic]) => (
              <a key={to} onClick={() => { setMoreOpen(false); to === '/account' && !me ? setLoginOpen(true) : nav(to); }}><M n={ic} s={17} /> {t}</a>
            ))}
            {me && <a onClick={() => { setMoreOpen(false); nav('/orders'); }}><M n="receipt_long" s={17} /> طلباتي</a>}
            {me && <a onClick={() => { setMoreOpen(false); nav('/points'); }}><M n="stars" s={17} /> نقاطي</a>}
            {isVendor && <a onClick={() => { setMoreOpen(false); nav('/vendor'); }}><M n="store" s={17} /> لوحة التاجر</a>}
            {isDelivery && <a onClick={() => { setMoreOpen(false); nav('/delivery'); }}><M n="two_wheeler" s={17} /> لوحة المندوب</a>}
            {isAdmin && (
              <a href={adminUrl || '#'} className={!adminUrl ? 'disabled' : ''} target="_blank" rel="noreferrer">
                <M n="shield" s={17} /> لوحة الإدارة
              </a>
            )}
            <div className="dd-div" />
            {me ? (
              <a style={{ color: 'var(--danger)' }} onClick={() => { localStorage.clear(); window.location.href = '/'; }}><M n="logout" s={17} c="var(--danger)" /> تسجيل الخروج</a>
            ) : (
              <a onClick={() => { setMoreOpen(false); setLoginOpen(true); }}><M n="login" s={17} /> تسجيل الدخول</a>
            )}
          </div>
        </>
      )}
      <nav className="bottom-nav">
        <div className="bnav-in">
          {BNAV_PINNED.map(([to, ic]) => (
            <button key={to} className={`bnav-btn ${on(to) && !(to === '/' && on('/cart')) ? 'on' : ''}`} onClick={() => nav(to)}>
              <span className="bv">
                <M n={ic} s={22} fill={on(to) && !(to === '/' && on('/cart'))} w={on(to) && !(to === '/' && on('/cart')) ? 600 : 400} />
                {to === '/cart' && cartN ? <span className="badge-count">{cartN}</span> : null}
                {to === '/fav' && favs.length ? <span className="badge-count">{favs.length}</span> : null}
              </span>
              {to === '/' ? 'الرئيسية' : to === '/stores' ? 'المتاجر' : to === '/cart' ? 'السلة' : 'المفضلة'}
            </button>
          ))}
          <button className={`bnav-btn ${moreOpen || (!on('/') && !on('/stores') && !on('/cart') && !on('/fav')) ? 'on' : ''}`} onClick={() => setMoreOpen(!moreOpen)}>
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
      <span className="badge-count">{cartN}</span>
    </button>
  );
}