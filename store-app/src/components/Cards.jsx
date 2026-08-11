import React from 'react';
import { useNavigate } from 'react-router-dom';
import { fmt, priceOf, pct, U } from '../api';
import { useApp } from '../ctx';
import { Img, M } from '../ui';
import { flyToCart, srcRectOf } from '../fly';

export const DOT = (name) => {
  const n = String(name || '').toLowerCase().trim();
  const map = {
    'أحمر': '#E7352B', 'احمر': '#E7352B', 'red': '#E7352B',
    'أزرق': '#2453CB', 'ازرق': '#2453CB', 'blue': '#2453CB',
    'أسود': '#202126', 'اسود': '#202126', 'black': '#202126',
    'أبيض': '#F5F5F5', 'ابيض': '#F5F5F5', 'white': '#F5F5F5',
    'أخضر': '#1E8A4C', 'اخضر': '#1E8A4C', 'green': '#1E8A4C',
    'أصفر': '#F2C513', 'اصفر': '#F2C513', 'yellow': '#F2C513',
    'بنفسجي': '#7C3AED', 'بنفسجية': '#7C3AED', 'purple': '#7C3AED',
    'وردي': '#F472B6', 'وردية': '#F472B6', 'pink': '#F472B6',
    'رمادي': '#9CA3AF', 'رمادية': '#9CA3AF', 'grey': '#9CA3AF',
    'بني': '#7C4A23', 'بنية': '#7C4A23', 'brown': '#7C4A23',
    'برتقالي': '#F97316', 'برتقالية': '#F97316', 'orange': '#F97316',
    'بيج': '#E5CBB0', 'ذهبي': '#D4AF37',
  };
  for (const k of Object.keys(map)) if (n.includes(k)) return map[k];
  return '#D9DEE7';
};

/* ═══ بطاقة منتج — شبكة 2×2 مثل التطبيق: صورة 3:4 + خصم + نقاط ألوان + زر برتقالي ═══ */
export function ProductCard({ p, cols = 2 }) {
  const nav = useNavigate();
  const { addToCart, notify, setLoginOpen, token } = useApp();
  const off = p.has_offer ? pct(p.price, p.offer_price) : 0;
  const variants = p.variants && p.variants.length ? p.variants : [];
  const dots = [];
  for (const v of variants) {
    const c = DOT(v.color || (v.name || ''));
    if (!dots.includes(c)) dots.push(c);
  }
  const quick = async (e) => {
    e.stopPropagation();
    if (variants.length) { nav('/product/' + p.id); return; }
    if (!token) { notify('سجل دخولك أولاً', 'err'); setLoginOpen(true); return; }
    flyToCart(srcRectOf(e.currentTarget), U(p.image) ? p.image : null);
    await addToCart(p.id, null, null, 1);
  };
  return (
    <div className="pc" onClick={() => nav('/product/' + p.id)}>
      <div className="pc-img">
        {U(p.image) ? <img src={p.image} alt={p.name} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>{p.image || '🛍️'}</span>}
        {off ? <span className="pc-badge">خصم {off}%</span> : null}
        {p.out_of_stock ? <span className="pc-badge dark">نفد</span> : null}
      </div>
      <div className="pc-in">
        <div className="pc-n">{p.name}</div>
        {dots.length ? (
          <div className="pc-dots">
            {dots.slice(0, 4).map((c, i) => <span key={i} className="pc-dot" style={{ background: c }} />)}
            {dots.length > 4 ? <span className="more">+{dots.length - 4}</span> : null}
          </div>
        ) : null}
        {p.has_offer ? <div className="pc-old">{fmt(p.price)}</div> : null}
        <div className="pc-row">
          <span className="pc-p">{fmt(priceOf(p))}</span>
          <button className={`add-mini ${p.has_offer ? '' : ''}`} onClick={quick} title="أضف للسلة">
            <M n="add" s={17} c="#fff" w={700} />
          </button>
        </div>
      </div>
    </div>
  );
}

/* ═══ بطاقة محل مصغرة — الغلاف يملأ البوكس (132×122) ═══ */
export function StoreCard({ s, cover }) {
  const nav = useNavigate();
  const hasCover = U(s.cover);
  return (
    <div className="sm" onClick={() => nav('/stores/' + s.id)}>
      {hasCover ? <img className="sm-cover" src={s.cover} alt={s.name} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <div className="sm-cover" style={{ background: cover }} />}
      <div className="sm-ov" />
      <div className="sm-logo">
        {U(s.logo) ? <img src={s.logo} alt="" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span style={{ fontSize: 16 }}>{s.logo || '🏪'}</span>}
      </div>
      <div className="sm-info">
        <div className="sm-n">{s.name}</div>
        <div className="sm-r">
          <M n="star" fill s={12} c="var(--star)" w={700} />
          <span className="rc">{Number(s.rating || 0).toFixed(1)}</span>
          <span className="rv">• {s.reviews_count || 0} تقييم</span>
        </div>
      </div>
    </div>
  );
}

/* ═══ بطاقة عرض مصغرة — شريط عروض اليوم ═══ */
export function DealCard({ d }) {
  const nav = useNavigate();
  const { addToCart, notify, setLoginOpen, token } = useApp();
  const prod = d.product || d;
  const variants = prod.variants && prod.variants.length ? prod.variants : [];
  const add = (e) => {
    e.stopPropagation();
    if (variants.length) { nav('/product/' + prod.id); return; }
    if (!token) { setLoginOpen(true); return; }
    flyToCart(srcRectOf(e.currentTarget), U(prod.image) ? prod.image : null);
    addToCart(prod.id, null, null, 1);
  };
  return (
    <div className="card deal-c" onClick={() => nav('/product/' + prod.id)} style={{ cursor: 'pointer', position: 'relative' }}>
      {prod.has_offer ? <span className="deal-badge">خصم {pct(prod.price, prod.offer_price)}%</span> : null}
      <div className="deal-img">
        {U(prod.image) ? <img src={prod.image} alt={prod.name} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 15 }} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>{prod.image || '🛍️'}</span>}
      </div>
      <div className="deal-n">{prod.name}</div>
      <div className="deal-s">{d.store_name || 'متجر'}</div>
      <div className="deal-row">
        <span className="deal-p">{fmt(priceOf(prod))}</span>
        <button className="add-mini" onClick={add}><M n="add" s={17} c="#fff" w={700} /></button>
      </div>
    </div>
  );
}

/* ═══ شريحة فئة ═══ */
export const CatIcon = ({ c, on, onClick }) => (
  <span className={`chipg ${on ? 'on' : ''}`} onClick={onClick}>
    <span className="ce">{c.icon || '🛍️'}</span>{c.name}
  </span>
);