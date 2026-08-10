import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, ST } from '../api';
import { useApp } from '../ctx';

export default function Orders() {
  const { token, setLoginOpen } = useApp();
  const [orders, setOrders] = useState(null);
  const nav = useNavigate();

  useEffect(() => {
    if (!token) { setOrders([]); return; }
    api('/api/customer/orders').then(d => setOrders(d.orders || [])).catch(() => setOrders([]));
  }, [token]);

  if (!token) {
    return (
      <section className="sect"><div className="noprod">
        <span className="e">🔐</span>شاهد طلباتك يتطلب تسجيل دخول
        <br /><button className="lbtn" style={{ maxWidth: 260, margin: '14px auto 0' }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>
      </div></section>
    );
  }
  return (
    <section className="sect" style={{ marginTop: 24 }}>
      <div className="sect-head"><h2><span className="ln" />📦 <em style={{ color: 'var(--navy)' }}>طلباتي</em></h2></div>
      {!orders ? <p className="empty">جاري التحميل…</p>
        : !orders.length ? <div className="noprod"><span className="e">📦</span>ماكو طلبات بعد — ابدأ التسوق!</div>
        : orders.map(o => (
          <div key={o.id} className="ord">
            <div className="ord-top">
              <b>{o.code} · {o.store_name}</b>
              <span className={`st ${o.status}`}>{ST[o.status] || o.status}</span>
            </div>
            <div className="ord-items">{(o.items || []).map((i, k) => <span key={k}>{k ? ' • ' : ''}{i.name} × {i.qty} — {fmt(i.price)}</span>)}</div>
            <div className="tot">الإجمالي: <em>{fmt(o.total)}</em> {o.delivery_fee ? `(توصيل ${fmt(o.delivery_fee)})` : ''}</div>
          </div>
        ))}
    </section>
  );
}