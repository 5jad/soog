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
            <div style={{ aspectRatio: 1, borderRadius: 16, background: 'var(--bg-blue-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 72, overflow: 'hidden', position: 'relative' }}>
              <Img src={p.image} fontSize="72px" />
              {p.has_offer ? <span className="pcard-off" style={{ top: 10, insetInlineStart: 10 }}>-{Math.round(p.offer_percent)}%</span> : null}
            </div>
          </div>
          <div style={{ flex: '1 1 300px' }}>
            <h2 className="modal-title" style={{ fontSize: 19 }}>{p.name}</h2>
            <div className="pd-store" style={{ marginBlock: 6 }} onClick={() => { onClose(); nav('/stores/' + p.store_id); }}>🏬 {p.store_name}</div>
            <div className="pd-old-row" style={{ alignItems: 'baseline' }}><span className="pd-price" style={{ fontSize: 'var(--t-h2)' }}>{fmt(price)}</span>{Number(p.old_price) > price ? <span className="pd-old">{fmt(p.old_price)}</span> : null}</div>
            {p.description ? <div className="note" style={{ marginBlock: 12 }}>{p.description}</div> : null}
            {vars.length ? (
              <div className="vars" style={{ marginBlock: 8 }}>
                {vars.map((v, i) => (
                  <span key={i} className={`var ${v.stock === 0 ? 'off' : i === varI ? 'on' : ''}`} onClick={() => v.stock > 0 && setVarI(i)}>
                    {v.color ? v.color + ' · ' : ''}{v.name}{v.stock === 0 ? ' (نفد)' : ''}
                  </span>
                ))}
              </div>
            ) : null}
            <div className="rowf" style={{ gap: 12, marginBlock: 12 }}>
              <div className="qty">
                <button onClick={() => setQty(Math.max(1, qty - 1))}><M n="remove" s={16} w={600} /></button><b>{qty}</b>
                <button className="plus" onClick={() => setQty(qty + 1)}><M n="add" s={16} w={600} /></button>
              </div>
            </div>
            <button className="btn btn--navy btn--lg btn--block" disabled={busy}
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