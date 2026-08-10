import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, priceOf } from '../api';
import { Img, Modal } from '../ui';

export default function ProductModal({ id, onClose }) {
  const { addToCart } = useApp();
  const [p, setP] = useState(null);
  const [varI, setVarI] = useState(0);
  const [qty, setQty] = useState(1);
  const [busy, setBusy] = useState(false);
  const nav = useNavigate();

  useEffect(() => {
    if (!id) return;
    setP(null); setQty(1); setVarI(0);
    api('/api/products/' + id).then(d => setP(d.product)).catch(e => { onClose(); });
  }, [id]);

  if (!id) return null;
  const vars = p ? (p.variants || []) : [];
  const varSel = vars.length ? (vars[varI] && vars[varI].stock > 0 ? vars[varI] : vars.find(v => v.stock > 0) || null) : null;
  const price = p ? priceOf(p) : 0;

  return (
    <Modal open={!!id && !!p} onClose={onClose} lg>
      {p && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 22 }}>
          <div style={{ flex: '1 1 260px', minWidth: 240 }}>
            <div style={{ aspectRatio: 1, borderRadius: 16, background: '#EEF3FB', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 72, overflow: 'hidden', position: 'relative' }}>
              <Img src={p.image} fontSize="72px" />
              {p.has_offer ? <span className="dc" style={{ position: 'absolute', top: 10, right: 10 }}>-{Math.round(p.offer_percent)}%</span> : null}
            </div>
          </div>
          <div style={{ flex: '1 1 300px' }}>
            <h2 style={{ fontSize: 19, fontWeight: 900 }}>{p.name}</h2>
            <div className="sname" onClick={() => { onClose(); nav('/stores/' + p.store_id); }}>🏬 {p.store_name}</div>
            <div className="prices"><b>{fmt(price)}</b>{Number(p.old_price) > price ? <s>{fmt(p.old_price)}</s> : null}</div>
            {p.description ? <div className="desc" style={{ padding: '10px 14px', marginBottom: 12 }}>{p.description}</div> : null}
            {vars.length ? (
              <div className="vars">
                {vars.map((v, i) => (
                  <span key={i} className={`var ${v.stock === 0 ? 'off' : i === varI ? 'on' : ''}`} onClick={() => v.stock > 0 && setVarI(i)}>
                    {v.color ? v.color + ' · ' : ''}{v.name}{v.stock === 0 ? ' (نفد)' : ''}
                  </span>
                ))}
              </div>
            ) : null}
            <div className="qty">
              <button onClick={() => setQty(Math.max(1, qty - 1))}>−</button><b>{qty}</b>
              <button onClick={() => setQty(qty + 1)}>+</button>
            </div>
            <button className="btn btn-p btn-lg btn-block" style={{ fontSize: 15 }} disabled={busy}
              onClick={async () => {
                setBusy(true);
                const ok = await addToCart(p.id, varSel ? varSel.id : null, null, qty);
                setBusy(false);
                if (ok) onClose();
              }}>🛒 أضف للسلة — {fmt(price)}</button>
            <div className="note" style={{ marginTop: 12 }}>💵 الدفع عند الاستلام · 🚚 توصيل سريع داخل الكوت · 🔁 إرجاع خلال {p.warranty_days || 3} أيام</div>
          </div>
        </div>
      )}
    </Modal>
  );
}