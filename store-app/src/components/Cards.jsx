import React from 'react';
import { useNavigate } from 'react-router-dom';
import { fmt, priceOf, pct, U, S } from '../api';
import { useApp } from '../ctx';
import { Img, M } from '../ui';
import { flyToCart, srcRectOf } from '../fly';

export const DOT = (name) => {
  const n = String(name || '').toLowerCase().trim();
  const map = {
    'أحمر': '#E7352B', 'احمر': '#E7352B', 'red': '#E7352B',
    'أزرق': '#2453CB', 'ازرق': '#2453CB', 'blue': '#2453CB',
    'أسود': '#202126', 'اسود': '#202126', 'black': '#202126',
    'أبيض': 'var(--bg-soft)', 'ابيض': 'var(--bg-soft)', 'white': 'var(--bg-soft)',
    'أخضر': '#1E8A4C', 'اخضر': '#1E8A4C', 'green': '#1E8A4C',
    'أصفر': '#F2C513', 'اصفر': '#F2C513', 'yellow': '#F2C513',
    'بنفسجي': '#7C3AED', 'بنفسجية': '#7C3AED', 'purple': '#7C3AED',
    'وردي': '#F472B6', 'وردية': '#F472B6', 'pink': '#F472B6',
    'رمادي': '#9CA3AF', 'رمادية': '#9CA3AF', 'grey': '#9CA3AF',
    'بني': '#7C4A23', 'بنية': '#7C4A23', 'brown': '#7C4A23',
    'برتقالي': 'var(--accent-light)', 'برتقالية': 'var(--accent-light)', 'orange': 'var(--accent-light)',
    'بيج': '#E5CBB0', 'ذهبي': '#D4AF37',
  };
  for (const k of Object.keys(map)) if (n.includes(k)) return map[k];
  return '#D9DEE7';
};

/* ═══ بطاقة منتج — شبكة auto-fill: صورة 3:4 + خصم + نقاط ألوان + زر برتقالي ═══ */
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
    <div className="pcard" onClick={() => nav('/product/' + p.id)}>
      <div className="pcard-img">
        {U(p.image) ? <img src={p.image} alt={p.name} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>{p.image || '🛍️'}</span>}
        {off ? <span className="pcard-off">خصم {off}%</span> : null}
        {p.out_of_stock ? <span className="pcard-tag"><M n="block" s={10} c="#fff" w={800} />نفد</span>
          : (p.stock != null && p.stock > 0 && p.stock <= 5) ? <span className="pcard-stock pcard-stock--low">متبقي {p.stock}</span>
          : null}
      </div>
      <div className="pcard-in">
        <div className="pcard-name">{p.name}</div>
        {dots.length ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, paddingBlock: 4 }}>
            {dots.slice(0, 4).map((c, i) => <span key={i} style={{ width: 8, height: 8, borderRadius: '50%', background: c, border: '1px solid var(--line-strong)' }} />)}
            {dots.length > 4 ? <span style={{ fontSize: 9, fontWeight: 800, color: 'var(--muted)' }}>+{dots.length - 4}</span> : null}
          </div>
        ) : null}
        {p.has_offer ? <div className="pcard-old">{fmt(p.price)}</div> : null}
        <div className="pcard-row">
          <span className="pcard-price">{fmt(priceOf(p))}</span>
          <button className="add-mini" onClick={quick} title="أضف للسلة">
            <M n="add" s={17} c="#fff" w={700} />
          </button>
        </div>
      </div>
    </div>
  );
}

/* ═══ بطاقة محل — الغلاف يملأ البوكس (16:9) ═══ */
export function StoreCard({ s, cover, w }) {
  const nav = useNavigate();
  const hasCover = !!S(s.cover);
  const coverSrc = S(s.cover) || cover;
  const logoSrc = S(s.logo);
  return (
    <div className="scard" style={w ? { width: w, flex: 'none' } : undefined} onClick={() => nav('/stores/' + s.id)}>
      {hasCover ? <img className="scard-cover" src={coverSrc} alt={s.name} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <div className="scard-cover" style={{ background: cover }} />}
      <div className="scard-ov" />
      <div className="scard-logo">
        {logoSrc ? <img src={logoSrc} alt="" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span style={{ fontSize: 16 }}>{s.logo || '🏪'}</span>}
      </div>
      <div className="scard-info">
        <div className="scard-name">{s.name}</div>
        <div className="scard-r">
          <M n="star" fill s={12} c="var(--star)" w={700} />
          <span>{Number(s.rating || 0).toFixed(1)}</span>
          <span>• {s.reviews_count || 0} تقييم</span>
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
    if (!token) { notify('سجل دخولك أولاً', 'err'); setLoginOpen(true); return; }
    flyToCart(srcRectOf(e.currentTarget), U(prod.image) ? prod.image : null);
    addToCart(prod.id, null, null, 1);
  };
  return (
    <div className="dcard" onClick={() => nav('/product/' + prod.id)}>
      {prod.has_offer ? <span className="pcard-off">خصم {pct(prod.price, prod.offer_price)}%</span> : null}
      <div className="dcard-img">
        {U(prod.image) ? <img src={prod.image} alt={prod.name} loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>{prod.image || '🛍️'}</span>}
      </div>
      <div className="dcard-name">{prod.name}</div>
      <div className="dcard-s">{d.store_name || 'متجر'}</div>
      <div className="dcard-row">
        <span className="pcard-price" style={{ fontSize: 'var(--t-body)' }}>{fmt(priceOf(prod))}</span>
        <button className="add-mini" onClick={add}><M n="add" s={17} c="#fff" w={700} /></button>
      </div>
    </div>
  );
}

/* ═══ شريحة فئة ═══ */
export const CatIcon = ({ c, on, onClick }) => (
  <span className={`chip ${on ? 'on' : ''}`} onClick={onClick}>
    <span className="ce">{c.icon || '🛍️'}</span>{c.name}
  </span>
);