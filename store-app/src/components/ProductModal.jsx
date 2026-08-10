import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, priceOf } from '../api';
import { Img } from '../ui';

export default function ProductModal({ id, onClose }) {
  const { addToCart } = useApp();
  const [p, setP] = useState(null);
  const [varI, setVarI] = useState(0);
  const [qty, setQty] = useState(1);
  const nav = useNavigate();

  useEffect(() => {
    if (!id) return;
    setP(null); setQty(1); setVarI(0);
    api('/api/products/' + id).then(d => setP(d.product)).catch(() => onClose());
  }, [id]);

  if (!id || !p) return null;
  const vars = p.variants || [];
  const varSel = vars[varI] && vars[varI].stock > 0 ? vars[varI] : vars.find(v => v.stock > 0) || null;
  const price = priceOf(p);

  return (
    <>
      <div className="overlay" onClick={onClose} />
      <div className="pmodal">
        <div className="box">
          <div className="g">
            <Img src={p.image} fontSize="90px" />
            {p.has_offer ? <span className="dc">-{Math.round(p.offer_percent)}%</span> : null}
            <span className="x" onClick={onClose}>✕</span>
          </div>
          <div className="i">
            <h2>{p.name}</h2>
            <div className="sname" onClick={() => { onClose(); nav('/stores/' + p.store_id); }}>🏬 {p.store_name}</div>
            <div className="prices"><b>{fmt(price)}</b>{p.old_price && price < p.old_price ? <s>{fmt(p.old_price)}</s> : null}</div>
            {p.description ? <div className="desc">{p.description}</div> : null}
            {vars.length ? (
              <div className="vars">
                {vars.map((v, i) => (
                  <span key={i} className={`var ${v.stock === 0 ? 'off' : i === varI ? 'on' : ''}`} onClick={() => v.stock > 0 && setVarI(i)}>
                    {v.color ? v.color + ' · ' : ''}{v.name} {v.stock === 0 ? '(نفد)' : ''}
                  </span>
                ))}
              </div>
            ) : null}
            <div className="qty">
              <button onClick={() => setQty(Math.max(1, qty - 1))}>−</button><b>{qty}</b>
              <button onClick={() => setQty(qty + 1)}>+</button>
            </div>
            <button className="addbig" onClick={async () => {
              const ok = await addToCart(p.id, varSel ? varSel.id : null, null, qty);
              if (ok) onClose();
            }}>🛒 أضف للسلة — {fmt(price)}</button>
            <div className="lnote" style={{ marginTop: 10 }}>💵 الدفع عند الاستلام · 🚚 توصيل سريع داخل الكوت</div>
          </div>
        </div>
      </div>
    </>
  );
}