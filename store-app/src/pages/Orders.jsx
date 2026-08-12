import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, useTitle } from '../ui';

export const STATUS = {
  pending: { t: 'في الانتظار', e: '🕐', c: 'pill-bg' },
  accepted: { t: 'تم عنده المتجر', e: '✅', c: 'pill-bg' },
  processing: { t: 'قيد التحضير', e: '👨‍🍳', c: 'pill-bg' },
  assigned: { t: 'مع المندوب الآن', e: '🛵', c: 'pill-sky' },
  on_the_way: { t: 'في الطريق إليك', e: '🚚', c: 'pill-sun' },
  delivered: { t: 'تم التوصيل', e: '📦', c: 'pill-ok' },
  rejected: { t: 'رُفض', e: '❌', c: 'pill-err' },
  cancelled: { t: 'ملغي', e: '🚫', c: 'pill-err' },
};
export const OKISH = ['accepted', 'processing', 'assigned', 'on_the_way', 'delivered'];

export default function Orders() {
  useTitle('طلباتي');
  const { token, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [orders, setOrders] = useState(null);

  useEffect(() => {
    if (!token) return;
    api('/api/customer/orders').then(async (d) => {
      const list = d.orders || [];
      const rich = await Promise.all(list.slice(0, 4).map(o => api('/api/customer/orders/' + o.id).catch(() => o)));
      setOrders(rich);
    }).catch(() => setOrders([]));
  }, [token]);

  if (!token) {
    return <div className="sect"><Empty icon="🔐" msg="سجّل دخولك لعرض طلباتك"
      action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  }
  if (!orders) return <Loader />;
  if (!orders.length) return <div className="sect"><Empty icon="📦" msg="لا توجد طلبات بعد"
    lottie="/animations/empty_state.json"
    action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => nav('/')}>ابدأ التسوق</button>} /></div>;

  return (
    <div className="sect" style={{ maxWidth: 680 }}>
      <div className="sect-head"><h2><span className="ln" />📦 طلباتي</h2></div>
      {orders.map(o => <OrderCard key={o.id} o={o} nav={nav} />)}
    </div>
  );
}

export function OrderCard({ o, nav, mini }) {
  const st = STATUS[o.status] || STATUS.pending;
  return (
    <div className="card" style={{ padding: 16, marginBottom: 12 }}>
      <div className="oc-top">
        <div><b style={{ fontSize: 15 }}>{o.store_name}</b>
          <div style={{ fontSize: 11, color: 'var(--muted)' }}>#{o.code} • {timeAgo(o.created_at)}</div>
        </div>
        <span className={`pill ${st.c}`}>{st.e} {st.t}</span>
      </div>
      <div className="oc-items">
        {(o.items || []).slice(0, 3).map(it => (
          <div key={it.id} className="oc-item" onClick={() => nav('/product/' + it.product_id)}>
            <div className="oc-img">{it.image ? <img src={it.image} alt="" loading="lazy" /> : <span>🛍️</span>}</div>
            <div className="oc-inf">
              <div className="n">{it.name} {it.variant ? <b className="v">{it.variant}</b> : null}</div>
              <div className="s">× {it.qty}</div>
            </div>
            <span className="oc-p">{fmt(it.price)}</span>
          </div>
        ))}
        {(o.items || []).length > 3 ? <div className="oc-more">+{(o.items || []).length - 3} منتجات أخرى</div> : null}
      </div>
      {!mini && (
        <div className="oc-actions">
          <button className="btn btn-o btn-sm" onClick={() => nav('/orders/' + o.id)}>🔍 تفاصيل وتتبع</button>
          {['pending', 'accepted', 'processing'].includes(o.status) && <button className="btn btn-o-err btn-sm" onClick={() => nav('/orders/' + o.id)}>إلغاء</button>}
          {['delivered', 'cancelled', 'rejected'].includes(o.status) &&
            <button className="btn btn-p btn-sm" onClick={() => reorder(o, nav)}>🔄 أعد الطلب</button>}
        </div>
      )}
    </div>
  );
}

export async function reorder(o, nav) {
  for (const it of o.items || []) {
    await api('/api/customer/cart', { method: 'POST', body: JSON.stringify({ product_id: it.product_id, qty: it.qty }) }).catch(() => {});
  }
  nav('/checkout');
}