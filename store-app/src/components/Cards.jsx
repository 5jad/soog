import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { fmt, priceOf, pct } from '../api';
import { Img, Stars } from '../ui';

export const ProductCard = ({ p, fire = false }) => {
  const { favs, toggleFav, setProdId } = useApp();
  const nav = useNavigate();
  const on = favs.includes(p.id);
  const d = pct(p);
  return (
    <div className="pcard">
      {d ? <span className="dc">-{d}%</span> : null}
      {fire ? <span className="dc" style={{ top: 44, background: 'var(--grad-sky)' }}>🔥</span> : null}
      <div className="img" onClick={() => setProdId(p.id)}><Img src={p.image} /></div>
      <button className={`heart ${on ? 'on' : ''}`} title="مفضلة" onClick={() => toggleFav(p.id)}>{on ? '❤️' : '♡'}</button>
      <button className="add" title="أضف للسلة" onClick={() => setProdId(p.id)}>+</button>
      <div className="b">
        <div className="pn" onClick={() => setProdId(p.id)}>{p.name}</div>
        <div className="ps" onClick={() => nav('/stores/' + p.store_id)}>🏬 {p.store_name}</div>
        <div className="pr"><b>{fmt(priceOf(p))}</b>{p.old_price && Number(p.old_price) > Number(priceOf(p)) ? <s>{fmt(p.old_price)}</s> : null}</div>
      </div>
    </div>
  );
};

export const StoreCard = ({ st }) => {
  const nav = useNavigate();
  const open = st.is_open && !st.on_vacation;
  return (
    <div className="shop" onClick={() => nav('/stores/' + st.id)}>
      <div className="lg"><Img src={st.logo} fontSize="28px" /></div>
      <div className="n">{st.name}</div>
      <div className="m"><Stars n={st.rating} size={11} /> {st.rating || '5.0'} · {st.reviews_count || 0} تقييم</div>
      <div className="m">{st.governorate_name}{st.district_name ? ' — ' + st.district_name : ''}</div>
      {!open ? <span className="pill st-cancelled" style={{ marginTop: 8 }}>مغلق حالياً</span> : <span className="pill st-delivered" style={{ marginTop: 8 }}>مفتوح</span>}
    </div>
  );
};

export const DealCard = ({ p }) => {
  const { setProdId } = useApp();
  return (
    <div className="deal" onClick={() => setProdId(p.id)}>
      <div className="img"><Img src={p.image} /></div>
      <span className="dc">-{Math.round(p.offer_percent || pct(p))}%</span>
      <div className="b">
        <div className="n">{p.name}</div>
        <div className="p"><b>{fmt(priceOf(p))}</b><s>{fmt(p.price)}</s></div>
      </div>
    </div>
  );
};

export const CatIcon = ({ c, on, onClick }) => (
  <div className={`cat ${on ? 'on' : ''}`} onClick={onClick}>
    <i>{c.icon || '📦'}</i>{c.name}
  </div>
);