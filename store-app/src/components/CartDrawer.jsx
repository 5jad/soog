import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, priceOf } from '../api';
import { Img } from '../ui';

export default function CartDrawer({ open, onClose }) {
  const { token, refreshCart, notify } = useApp();
  const [items, setItems] = useState(null);
  const [stores, setStores] = useState([]);
  const [coupons, setCoupons] = useState({});
  const [codes, setCodes] = useState({});
  const [busy, setBusy] = useState({});
  const [couponErr, setCouponErr] = useState({});
  const nav = useNavigate();

  const load = () => {
    setItems(null);
    api('/api/customer/cart').then(d => setItems(d.items || [])).catch(() => setItems([]));
    api('/api/stores').then(d => setStores(d.stores || [])).catch(() => {});
  };
  useEffect(() => { if (open) load(); }, [open, token]);

  if (!open) return null;
  const storeMap = {};
  for (const s of stores) storeMap[s.id] = s;
  const groups = {};
  for (const it of (items || [])) (groups[it.store_id] = groups[it.store_id] || { items: [] }).items.push(it);

  const mut = async (fn) => {
    try { await fn(); load(); refreshCart(); } catch (e) { notify(e.message, 'err'); }
  };
  const applyCoupon = async (sid) => {
    const g = groups[sid];
    if (!g) return;
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    setBusy({ ...busy, [sid]: true });
    setCouponErr({ ...couponErr, [sid]: '' });
    try {
      const d = await api('/api/customer/cart/apply-coupon', { method: 'POST', body: JSON.stringify({ store_id: sid, code: codes[sid], subtotal: sub }) });
      setCoupons({ ...coupons, [sid]: d });
      notify('الكوبون فعّل ✓', 'ok');
    } catch (e) { setCouponErr({ ...couponErr, [sid]: e.message }); }
    setBusy({ ...busy, [sid]: false });
  };

  let total = 0, fees = 0;

  return (
    <>
      <div className="overlay" onClick={onClose} />
      <aside className={`drawer ${open ? 'open' : ''}`}>
        <div className="drawer-head"><b>سلة التسوق 🛒</b><button className="icon-btn" onClick={onClose}><M n="close" s={18} w={700} /></button></div>
        <div className="drawer-body">
          {!items ? <div className="centerload"><div className="spin" /></div>
          : !items.length ? <div className="empty-state"><span className="e">🛒</span><h4>سلتك فاضية — ابدأ التسوق!</h4></div>
          : Object.entries(groups).map(([sid, g]) => {
              const s = storeMap[+sid] || {};
              const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
              const freeMin = s.free_delivery_min || 50000;
              const free = sub >= freeMin;
              const fee = free ? 0 : (s.delivery_fee || 0);
              const coup = coupons[+sid];
              const coupD = coup ? coup.discount : 0;
              total += sub + fee - coupD;
              fees += fee;
              const P = Math.min(100, Math.round((sub / freeMin) * 100));
              return <div key={sid} className="cgroup">
                <div className="cgroup-t"><Img src={g.items[0].logo} fontSize="14px" /> {g.items[0].store_name}</div>
                <div className="threshold" style={{ marginBlockEnd: 0, marginBottom: 10 }}>
                  <div className="bs"><i className="bf" style={{ width: P + '%' }} /></div>
                  <div className="msg">{free ? '🎉 التوصيل مجاني لهذا المحل' : `شحن مجاني عند ${fmt(freeMin)} — باقي ${fmt(Math.max(0, freeMin - sub))}`}</div>
                </div>
                {g.items.map(it => (
                  <div key={it.id} className="citem">
                    <div className="img"><Img src={it.image} fontSize="23px" /></div>
                    <div className="c">
                      <div className="nm">{it.name}</div>
                      {it.variant ? <div className="v">{it.variant}</div> : null}
                      <div className="rowf" style={{ gap: 8, marginTop: 6 }}>
                        <div className="qty" style={{ height: 34 }}>
                          <button style={{ width: 30, height: 30 }} onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'PATCH', body: JSON.stringify({ qty: it.qty + 1 }) }))}><M n="add" s={14} w={700} /></button>
                          <b>{it.qty}</b>
                          <button style={{ width: 30, height: 30 }} onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'PATCH', body: JSON.stringify({ qty: it.qty - 1 }) }))}><M n="remove" s={14} w={700} /></button>
                        </div>
                        <div className="p">{fmt(priceOf(it) * it.qty)}</div>
                        <button className="x" onClick={() => mut(() => api('/api/customer/cart/' + it.id, { method: 'DELETE' }))} title="حذف"><M n="delete" s={15} w={500} /></button>
                      </div>
                    </div>
                  </div>
                ))}
                {coup ? <div className="coupon-tag">🎟️ كوبون {coup.code} — خصم {fmt(coup.discount)} <button onClick={() => setCoupons({ ...coupons, [sid]: null })}><M n="close" s={13} /></button></div> : (
                  <div className="coupon-row">
                    <input className="inp" placeholder="كود الكوبون (إن وجد)" value={codes[+sid] || ''} onChange={(e) => setCodes({ ...codes, [sid]: e.target.value })} />
                    <button className="btn btn--outline btn--sm" disabled={busy[sid]} onClick={() => applyCoupon(+sid)}>فعّل</button>
                  </div>
                )}
                {couponErr[sid] ? <p style={{ color: 'var(--danger)', fontSize: 11.5, fontWeight: 700, marginBottom: 10 }}>{couponErr[sid]}</p> : null}
                <div className="tot-row"><span>المجموع</span><b>{fmt(sub)}</b></div>
                {fee ? <div className="tot-row"><span>التوصيل</span><b>{fmt(fee)}</b></div> : null}
                {coupD ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>الخصم</span><b>-{fmt(coupD)}</b></div> : null}
              </div>;
            })}
        </div>
        {items && items.length ? (
          <div className="drawer-foot">
            <div className="tot-row grand"><span>الإجمالي</span><span>{fmt(total)}</span></div>
            <button className="btn btn--cta btn--lg btn--block" style={{ marginTop: 10 }} onClick={() => { onClose(); nav('/checkout'); }}>إتمام الطلب <M n="arrow_back" s={17} w={800} /></button>
            <div className="note" style={{ marginTop: 10 }}>💵 الدفع عند الاستلام · 🧾 يصلك {Object.keys(groups).length} طلب من {Object.keys(groups).length} محل برحلة واحدة</div>
          </div>
        ) : null}
      </aside>
    </>
  );
}