import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, priceOf } from '../api';
import { useApp } from '../ctx';
import { Empty, Loader, M, useTitle } from '../ui';

export default function CartPage() {
  useTitle('سلة التسوق');
  const { token, cartN, setCartN, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [items, setItems] = useState(null);
  const [coupons, setCoupons] = useState({});
  const [codes, setCodes] = useState({});

  const load = () => {
    api('/api/customer/cart').then(d => {
      const its = d.items || [];
      setItems(its);
      setCartN(its.length);
    }).catch(() => setItems([]));
  };
  useEffect(() => { if (token) load(); }, [token]);
  useEffect(() => { if (token) { const iv = setInterval(() => { if (document.visibilityState === 'visible') load(); }, 8000); return () => clearInterval(iv); } }, [token]);

  if (!token) {
    return <div className="sect"><Empty icon="🛒" msg="سجّل دخولك لعرض سلتك"
      action={<button className="btn btn-p btn-lg" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}><M n="lock" s={18} />تسجيل الدخول</button>} /></div>;
  }
  if (!items) return <Loader />;
  if (!items.length) {
    return <div className="sect"><Empty icon="🛒" msg="سلتك فاضية — أضف ما يعجبك"
      action={<button className="btn btn-p btn-lg" style={{ marginTop: 14 }} onClick={() => nav('/')}>ابدأ التسوق</button>} /></div>;
  }

  const groups = {};
  for (const it of items) (groups[it.store_id] = groups[it.store_id] || { name: it.store_name, logo: it.logo, fee: it.delivery_fee, freeMin: it.free_delivery_min, items: [] }).items.push(it);

  const chg = async (id, qty) => {
    if (qty < 1) return;
    const prev = items;
    setItems(items.map(x => x.id === id ? { ...x, qty } : x));
    try {
      const d = await api('/api/customer/cart', { method: 'PATCH', body: JSON.stringify({ cart_id: id, qty }) });
      setItems(d.items || prev);
      setCartN((d.items || prev).length);
    } catch (e) { setItems(prev); notify(e.message, 'err'); }
  };

  const del = async (id) => {
    try {
      const d = await api('/api/customer/cart', { method: 'DELETE', body: JSON.stringify({ cart_id: id }) });
      setItems(d.items || items.filter(x => x.id !== id));
      setCartN((d.items || items.filter(x => x.id !== id)).length);
    } catch (e) { notify(e.message, 'err'); }
  };

  const applyCoup = async (sid) => {
    const g = groups[sid];
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    try {
      const d = await api('/api/customer/cart/apply-coupon', { method: 'POST', body: JSON.stringify({ store_id: +sid, code: codes[sid], subtotal: sub }) });
      setCoupons({ ...coupons, [sid]: d });
      notify('فعّل الكوبون ✓', 'ok');
    } catch (e) { notify(e.message, 'err'); }
  };

  const totals = {};
  let grand = 0;
  for (const [sid, g] of Object.entries(groups)) {
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    const freeMin = g.freeMin || 50000;
    const fee = sub >= freeMin ? 0 : (g.fee || 0);
    const base = sub >= 50000 ? 5000 : 0;
    const coup = coupons[sid] ? coupons[sid].discount : 0;
    const t = { sub, fee, base, coup, total: Math.max(0, sub + fee - base - coup) };
    totals[sid] = t;
    grand += t.total;
  }

  return (
    <div className="sect" style={{ maxWidth: 880, paddingTop: 16 }}>
      <div className="sect-head"><h2><M n="shopping_cart" s={19} c="var(--primary)" /> سلتي</h2>
        <span style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 800 }}>{items.length} صنف</span></div>

      {Object.entries(groups).map(([sid, g]) => {
        const t = totals[sid];
        const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
        const prog = Math.min(100, Math.round(sub / (g.freeMin || 50000) * 100));
        const need = (g.freeMin || 50000) - sub;
        return (
          <div key={sid} className="card cg">
            <div className="cg-t">
              <span className="lg">{g.logo ? <img src={g.logo} alt="" /> : '🏪'}</span>
              <b>{g.name}</b>
              {sub >= (g.freeMin || 50000) ? <span className="free">توصيل مجاني ✓</span> : null}
            </div>
            <div className="cg-bar"><i style={{ width: prog + '%' }} /></div>
            {need > 0 ? <div className="note" style={{ margin: '0 14px 12px' }}>🚚 أضف {fmt(need)} ليصبح التوصيل مجانياً!</div> : null}
            {g.items.map(it => (
              <div key={it.id} className="citem">
                <div className="im">{it.image ? <img src={it.image} alt="" loading="lazy" /> : '🛍️'}</div>
                <div className="mi">
                  <div className="n">{it.name}</div>
                  {it.variant ? <div className="v">{it.variant}</div> : null}
                  <div className="pr">{fmt(priceOf(it))}</div>
                </div>
                <div className="qty">
                  <button onClick={() => chg(it.id, it.qty - 1)}><M n="remove" s={16} w={600} /></button>
                  <b>{it.qty}</b>
                  <button className="plus" onClick={() => chg(it.id, it.qty + 1)}><M n="add" s={16} w={600} /></button>
                </div>
                <button className="x" onClick={() => del(it.id)}><M n="close" s={17} w={500} /></button>
              </div>
            ))}
            <div style={{ padding: '6px 14px 12px', borderTop: '1px dashed var(--line)', margin: '0 14px', paddingTop: 10 }}>
              {!coupons[sid] ? (
                <div className="coupon-in">
                  <input className="inp" placeholder="كود كوبون هذا المحل" value={codes[sid] || ''} onChange={(e) => setCodes({ ...codes, [sid]: e.target.value })} />
                  <button className="btn btn-o btn-sm" onClick={() => applyCoup(sid)}><M n="confirmation_number" s={15} />فعّل</button>
                </div>
              ) : (
                <div className="coupon-tag">🎟️ {coupons[sid].code} — خصم {fmt(coupons[sid].discount)} <button onClick={() => setCoupons({ ...coupons, [sid]: null })}><M n="close" s={13} /></button></div>
              )}
              <div className="tot-row" style={{ marginTop: 8 }}><span>المنتجات</span><b>{fmt(t.sub)}</b></div>
              {t.base ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>خصم فوق 50 ألف 🎉</span><b>-{fmt(t.base)}</b></div> : null}
              {t.coup ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>الكوبون</span><b>-{fmt(t.coup)}</b></div> : null}
              <div className="tot-row"><span>التوصيل</span><b>{t.fee ? fmt(t.fee) : 'مجاني ✓'}</b></div>
              <div className="tot-row grand"><span>إجمالي المحل</span><b>{fmt(t.total)}</b></div>
            </div>
          </div>
        );
      })}

      <div className="cart-foot" style={{ maxWidth: 880, margin: '0 auto', borderRadius: '16px 16px 0 0' }}>
        <div className="cart-total">
          <b>الإجمالي ({items.length} صنف)</b>
          <span>{fmt(grand)}</span>
        </div>
        <button className="btn btn-lg" style={{ flex: 1 }} onClick={() => nav('/checkout')}>
          إتمام الطلب <M n="arrow_back" s={17} w={800} />
        </button>
      </div>
    </div>
  );
}