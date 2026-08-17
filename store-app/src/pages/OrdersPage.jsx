import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, M, useTitle } from '../ui';

const STAT = { new: ['قيد الانتظار', 'pill--bg'], preparing: ['قيد التحضير', 'pill--ok'], ready: ['جاهز للتسليم', 'pill--sky'], delivering: ['بالتوصيل', 'pill--sky'], delivered: ['تم التسليم', 'pill--ok'], cancelled: ['ملغي', 'pill--err'], returned: ['مرتجع', 'pill--err'] };
const STAT_IC = { new: 'schedule', preparing: 'restaurant', ready: 'inventory_2', delivering: 'local_shipping', delivered: 'verified', cancelled: 'cancel', returned: 'assignment_return' };

export default function OrdersPage() {
  useTitle('طلباتي', 'كل طلباتك من زبون');
  const { token, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [t, setT] = useState('all');
  const [orders, setOrders] = useState(null);

  useEffect(() => { if (!token) { setLoginOpen(true); return; } api('/api/customer/orders').then(d => setOrders(d.orders || [])).catch(() => setOrders([])); }, []);

  const show = (orders || []).filter(o => t === 'all' || o.status === t);

  return (
    <section className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="sect-head">
        <button className="icon-btn" onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={16} w={600} /></button>
        <h2><M n="receipt_long" s={19} c="var(--primary)" /> طلباتي</h2>
      </div>
      <div className="grid-cats">
        {[['all', 'الكل (' + (orders ? orders.length : 0) + ')'], ['new', 'بانتظار الموافقة'], ['preparing', 'قيد التحضير'], ['ready', 'جاهزة'], ['delivering', 'بالتوصيل'], ['delivered', 'مكتملة'], ['cancelled', 'ملغية']].map(([k, l]) => (
          <span key={k} className={`chip ${t === k ? 'on' : ''}`} onClick={() => setT(k)}>{l}</span>
        ))}
      </div>
      {!orders ? <Loader />
        : show.length ? <div className="orders-list" style={{ marginBlockStart: 8 }}>{show.map(o => {
            const [label, cls] = STAT[o.status] || [o.status, 'pill--bg'];
            return (
              <div key={o.id} className="order-card" onClick={() => nav('/orders/' + o.id)}>
                <div className="ord-top">
                  <span style={{ fontWeight: 800 }}><M n="receipt_long" s={13} c="var(--muted)" /> #{o.order_no || o.id}</span>
                  <span className={`pill ${cls}`}><M n={STAT_IC[o.status] || 'receipt_long'} s={11} c="inherit" /> {label}</span>
                </div>
                <div className="ord-body">
                  <span className="muted" style={{ fontSize: 12.5 }}>{new Date(o.created_at).toLocaleDateString('ar-IQ')} — {o.store_name || ''}</span>
                  {o.platform === 'app' || o.platform === 'store' ? <span className="pin"><M n="smartphone" s={12} w={600} /> {o.platform === 'store' ? 'ويب' : 'تطبيق'}</span> : null}
                  <b>{fmt(o.total)}</b>
                </div>
                <div className="ord-actions">
                  {o.status === 'delivering' ? <button className="btn btn--navy btn--sm" onClick={(e) => { e.stopPropagation(); nav('/track/' + o.id); }}><M n="near_me" s={14} /> تتبع مندوبي</button> : null}
                  {o.status === 'new' ? <button className="btn btn--outline btn--sm" onClick={(e) => { e.stopPropagation(); api('/api/customer/orders/' + o.id + '/cancel', { method: 'POST' }).then(() => { setOrders(orders.map(x => x.id === o.id ? { ...x, status: 'cancelled' } : x)); }).catch((er) => {}); }}><M n="close" s={13} /> إلغاء الطلب</button> : null}
                  {o.status === 'delivered' ? <button className="btn btn--outline btn--sm" onClick={(e) => { e.stopPropagation(); nav('/orders/' + o.id + '?review=1'); }}><M n="star" s={13} /> قيّم الطلب</button> : null}
                </div>
              </div>
            );
          })}</div>
        : <Empty icon="📦" msg="ماكو طلبات بهذا التصنيف" sub="عندك مصطفة جاهزة؟ سوّي طلبك الأول" lottie="/animations/empty_orders.json" action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/')}>تسوق الآن</button>} />}
    </section>
  );
}