import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, M, useTitle } from '../ui';

/* حالات الطلبات حسب قاعدة البيانات الفعلية */
export const STATUS = {
  new: { t: 'في الانتظار', e: '🕐', c: 'pill--bg' },
  preparing: { t: 'قيد التحضير', e: '👨‍🍳', c: 'pill--ok' },
  ready: { t: 'جاهز للتسليم', e: '📦', c: 'pill--sky' },
  delivering: { t: 'بالتوصيل إليك', e: '🛵', c: 'pill--sky' },
  delivered: { t: 'تم التوصيل', e: '✅', c: 'pill--ok' },
  cancelled: { t: 'ملغي', e: '🚫', c: 'pill--err' },
  returned: { t: 'مرتجع', e: '↩️', c: 'pill--err' },
};
export const OKISH = ['preparing', 'ready', 'delivering', 'delivered'];

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
    return <div className="container section"><Empty icon="🔐" msg="سجّل دخولك لعرض طلباتك"
      action={<button className="btn btn--navy" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  }
  if (!orders) return <Loader />;
  if (!orders.length) return <div className="container section"><Empty icon="📦" msg="لا توجد طلبات بعد"
    lottie="/animations/empty_orders.json"
    action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/')}>ابدأ التسوق</button>} /></div>;

  return (
    <div className="container section" style={{ maxWidth: 680, paddingBlockStart: 12 }}>
      <div className="sect-head"><h2><M n="receipt_long" s={19} c="var(--primary)" /> طلباتي</h2></div>
      {orders.map(o => <OrderCard key={o.id} o={o} nav={nav} />)}
    </div>
  );
}

export function OrderCard({ o, nav, mini }) {
  const st = STATUS[o.status] || STATUS.new;
  return (
    <div className="order-card" onClick={() => nav('/orders/' + o.id)}>
      <div className="ord-top">
        <div>
          <b style={{ fontSize: 15 }}>{o.store_name}</b>
          <div style={{ fontSize: 11, color: 'var(--muted)' }}>#{o.code} • {timeAgo(o.created_at)}</div>
        </div>
        <span className={`pill ${st.c}`}>{st.e} {st.t}</span>
      </div>
      <div className="ord-body">
        {(o.items || []).slice(0, 3).map(it => (
          <div key={it.id} className="citem" onClick={(e) => { e.stopPropagation(); nav('/product/' + it.product_id); }}>
            {it.image ? <img className="img" src={it.image} alt="" loading="lazy" /> : <div className="img"><M n="image" s={16} c="var(--muted)" /></div>}
            <div className="c">
              <div className="nm">{it.name}{it.variant ? <span className="muted" style={{ fontSize: 10.5, fontWeight: 600 }}> · {it.variant}</span> : null}</div>
              <div className="v">× {it.qty}</div>
            </div>
            <div className="p"><b>{fmt(it.price)}</b></div>
          </div>
        ))}
        {(o.items || []).length > 3 ? <div style={{ fontSize: 11.5, fontWeight: 800, color: 'var(--muted)', padding: '2px 14px' }}>+{(o.items || []).length - 3} منتجات أخرى</div> : null}
      </div>
      {!mini && (
        <div className="ord-actions">
          <button className="btn btn--outline btn--sm" onClick={(e) => { e.stopPropagation(); nav('/orders/' + o.id); }}><M n="search" s={13} /> تفاصيل وتتبع</button>
          {o.status === 'new' && <button className="btn btn--outline btn--sm" style={{ color: 'var(--danger)', borderColor: 'var(--danger-light)' }} onClick={(e) => { e.stopPropagation(); nav('/orders/' + o.id); }}><M n="close" s={13} /> إلغاء</button>}
          {['delivered', 'cancelled', 'returned'].includes(o.status) &&
            <button className="btn btn--navy btn--sm" onClick={(e) => { e.stopPropagation(); reorder(o, nav); }}><M n="restart_alt" s={13} /> أعد الطلب</button>}
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