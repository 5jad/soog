import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, priceOf } from '../api';
import { Img } from '../ui';

export default function CartDrawer({ open, onClose }) {
  const { token, notify, refreshCart } = useApp();
  const [items, setItems] = useState(null);
  const nav = useNavigate();

  useEffect(() => {
    if (!open) return;
    if (!token) return;
    api('/api/customer/cart').then(d => setItems(d.items || [])).catch(() => setItems([]));
  }, [open, token]);

  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} />
      <aside className="cart open">
        <div className="cart-head"><b>سلة التسوق 🛒</b><button onClick={onClose}>✕</button></div>
        <div className="cart-body">
          {!items ? <p className="empty"><span style={{ display: 'inline-block', width: 34, height: 34, borderRadius: 8, background: '#eef3fb', animation: 'sp .8s linear infinite' }} /></p>
          : !items.length ? <div className="empty"><span className="e">🛒</span>سلتك فاضية — ابدأ التسوق!</div>
          : <CartList items={items} setItems={setItems} />}
        </div>
        {items && items.length ? <CartFoot items={items} /> : null}
      </aside>
    </>
  );
}

function CartList({ items, setItems }) {
  const { notify, refreshCart } = useApp();
  const groups = {};
  for (const it of items) (groups[it.store_id] = groups[it.store_id] || { name: it.store_name, logo: it.logo, fee: it.delivery_fee, min: it.free_delivery_min || 50000, items: [] }).items.push(it);
  const mut = async (fn, okMsg) => { try { const d = await fn(); setItems((d && d.items) || []); refreshCart(); if (okMsg) notify(okMsg, 'ok'); } catch (e) { notify(e.message, 'err'); } };
  return Object.values(groups).map(g => {
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    const free = sub >= g.min;
    return (
      <div key={g.name} className="cgroup">
        <div className="cgroup-t"><Img src={g.logo} fontSize="15px" className="lg-t" /> {g.name}</div>
        {g.items.map(it => (
          <div key={it.id} className="citem">
            <div className="img"><Img src={it.image} fontSize="24px" /></div>
            <div className="c">
              <div className="n">{it.name}</div>
              {it.variant ? <div className="v">{it.variant}</div> : null}
              <div className="row">
                <div className="q">
                  <button onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'PATCH', body: JSON.stringify({ qty: it.qty + 1 }) }))}>+</button>
                  <b>{it.qty}</b>
                  <button onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'PATCH', body: JSON.stringify({ qty: it.qty - 1 }) }))}>−</button>
                </div>
                <div className="p">{fmt(priceOf(it) * it.qty)}</div>
                <button className="del" onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'DELETE' }))}>حذف</button>
              </div>
            </div>
          </div>
        ))}
        <div className="cgroup-s">التوصيل {free ? <b>مجاني ✓</b> : fmt(g.fee)} {free ? '' : `(مجاني عند ${fmt(g.min)})`}</div>
      </div>
    );
  });
}

function CartFoot({ items }) {
  const { setCartOpen } = useApp();
  const nav = useNavigate();
  const groups = {};
  for (const it of items) (groups[it.store_id] = groups[it.store_id] || { fee: it.delivery_fee, min: it.free_delivery_min || 50000, items: [] }).items.push(it);
  const total = items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
  const fees = Object.values(groups).reduce((a, g) => a + (g.items.reduce((s, b) => s + priceOf(b) * b.qty, 0) >= g.min ? 0 : g.fee), 0);
  return (
    <div className="cart-foot">
      <div className="tot"><span>الإجمالي</span><span>{fmt(total + fees)}</span></div>
      <button onClick={() => { setCartOpen(false); nav('/checkout'); }}>إتمام الطلب ←</button>
    </div>
  );
}