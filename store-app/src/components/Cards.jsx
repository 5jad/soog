import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { fmt, priceOf, pct, U } from '../api';
import { Img } from '../ui';

export function ProductCard({ p, fire = false }) {
  const { favs, toggleFav, setProdId } = useApp();
  const nav = useNavigate();
  const on = favs.includes(p.id);
  const d = pct(p);
  return (
    <div className="pcard">
      {d ? <span className="dc">-{d}%</span> : null}
      {fire ? <span className="dc" style={{ top: 44, background: 'linear-gradient(135deg,#f59e0b,#fbbf24)', color: '#3d2b00' }}>🔥 عرض</span> : null}
      <div className="img" onClick={() => setProdId(p.id)}><Img src={p.image} fontSize="46px" /></div>
      <button className={`heart ${on ? 'on' : ''}`} onClick={() => toggleFav(p.id)}>{on ? '❤️' : '♡'}</button>
      <button className="add" onClick={() => setProdId(p.id)}>+</button>
      <div className="b">
        <div className="pn" onClick={() => setProdId(p.id)}>{p.name}</div>
        <div className="ps" onClick={() => nav('/stores/' + p.store_id)}>🏬 {p.store_name}</div>
        <div className="pr"><b>{fmt(priceOf(p))}</b>{p.old_price && priceOf(p) < p.old_price ? <s>{fmt(p.old_price)}</s> : null}</div>
      </div>
    </div>
  );
}

export function StoreCard({ st }) {
  const nav = useNavigate();
  return (
    <div className="shop" onClick={() => nav('/stores/' + st.id)}>
      <div className="lg"><Img src={st.logo} fontSize="30px" /></div>
      <div className="n">{st.name}</div>
      <div className="m">⭐ {st.rating_avg || '5.0'} · {st.products_count || 0} منتج{st.address ? ` · ${st.address}` : ''}</div>
      <span className="go">زيارة المحل ←</span>
    </div>
  );
}

export function DealCard({ p }) {
  const { setProdId } = useApp();
  return (
    <div className="deal" onClick={() => setProdId(p.id)}>
      <div className="img"><Img src={p.image} fontSize="34px" /></div>
      <span className="dc">-{Math.round(p.offer_percent || pct(p))}%</span>
      <div className="b">
        <div className="n">{p.name}</div>
        <div className="p"><b>{fmt(priceOf(p))}</b><s>{fmt(p.price)}</s></div>
      </div>
    </div>
  );
}

export function CatIcon({ c, on, onClick }) {
  return (
    <div className={`cat ${on ? 'on' : ''}`} onClick={onClick}>
      <i>{c.icon || '📦'}</i>{c.name}
    </div>
  );
}

export function SkelGrid({ n = 10 }) {
  return (
    <div className="skgrid">
      {Array.from({ length: n }).map((_, i) => (
        <div key={i} className="sk">
          <i className="skimg" /><i className="skln w60" /><i className="skln w40" /><i className="skln w80" />
        </div>
      ))}
    </div>
  );
}