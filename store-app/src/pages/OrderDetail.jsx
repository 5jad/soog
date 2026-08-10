import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader } from '../ui';
import { STATUS, OrderCard, reorder } from './Orders';

const STEPS = { pending: 0, accepted: 1, processing: 2, assigned: 3, on_the_way: 4, delivered: 5 };
const STEP_T = ['تم الإرسال ✅', 'استلمه المتجر', 'قيد التحضير', 'مع المندوب 🛵', 'في الطريق إليك 🚚', 'تم التوصيل 🎉'];

export default function OrderDetail() {
  const { id } = useParams();
  const { token, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [o, setO] = useState(null);
  const [track, setTrack] = useState(null);

  useEffect(() => {
    if (!token) return;
    api('/api/customer/orders/' + id).then(setO).catch(e => notify(e.message, 'err'));
    api('/api/customer/orders/' + id + '/track').then(setTrack).catch(() => {});
  }, [token, id]);

  if (!token) {
    return <div className="sect" style={{ textAlign: 'center', padding: 60 }}>
      <button className="btn btn-p" onClick={() => setLoginOpen(true)}>تسجيل الدخول لعرض الطلب</button>
    </div>;
  }
  if (!o) return <Loader />;

  const st = STATUS[o.status] || STATUS.pending;
  const cur = STEPS[o.status] ?? 0;
  const bad = ['rejected', 'cancelled'].includes(o.status);
  const live = track && track.code;

  const cancel = async () => {
    try {
      const d = await api('/api/customer/orders/' + id + '/cancel', { method: 'POST', body: JSON.stringify({}) });
      notify(d.message || 'تم الإلغاء', 'ok');
      setO({ ...o, status: 'cancelled' });
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <div className="sect" style={{ maxWidth: 680 }}>
      <div className="sect-head"><h2><span className="ln" />#{o.code}</h2>
        <span className={`pill ${st.c}`}>{st.e} {st.t}</span></div>

      {live && (
        <div className="card lm-live" style={{ padding: 16, marginBottom: 14 }}>
          <div style={{ fontWeight: 900, marginBottom: 6 }}>🛰️ تتبع حي {track.courier_name ? `— المندوب ${track.courier_name}` : ''}</div>
          {track.courier_id ? (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button className="btn btn-p btn-sm" onClick={() => nav('/track/' + id)}>🗺️ فتح الخريطة الحية</button>
              <a className="btn btn-o btn-sm" href={'tel:' + track.courier_phone}>📞 {track.courier_phone}</a>
              <button className="btn btn-o btn-sm" onClick={() => { api('/api/customer/conversations', { method: 'POST', body: JSON.stringify({ courier_id: track.courier_id }) }).then(d => nav('/chat?id=' + d.conversation.id)).catch(e => notify(e.message, 'err')); }}>💬 شات</button>
            </div>
          ) : <div className="note" style={{ fontSize: 13 }}>🕐 بانتظار تعيين مندوب…</div>}
        </div>
      )}

      <div className="card" style={{ padding: 18, marginBottom: 14 }}>
        <div className="timeline">
          {STEP_T.map((s, i) => (
            <div key={s} className={`tl-step ${i <= cur && !bad ? 'done' : ''} ${i === cur && !bad ? 'now' : ''}`}>
              <div className="tl-dot">{i <= cur && !bad ? '✓' : i + 1}</div>
              <span>{s}</span>
            </div>
          ))}
        </div>
        {bad ? <div className="note" style={{ marginTop: 12, color: 'var(--err)' }}>
          {o.status === 'rejected' ? '❌ رُفض الطلب — تأكد من العنوان أو راسل المحل.' : '🚫 الطلب ملغي.'}</div> : null}
      </div>

      <OrderCard o={o} nav={nav} mini />

      <div className="card" style={{ padding: 16, marginBottom: 14, fontSize: 13 }}>
        <div className="sect-head" style={{ marginBottom: 6 }}><h2 style={{ fontSize: 13 }}>📍 العنوان</h2></div>
        <div>{o.address_full || '—'}</div>
        {o.note ? <div className="note" style={{ marginTop: 6 }}>📝 ملاحظتك: {o.note}</div> : null}
      </div>

      <div className="card" style={{ padding: 16, marginBottom: 14, fontSize: 13 }}>
        <div className="tot-row"><span>المنتجات</span><b>{fmt(o.subtotal)}</b></div>
        {o.base_discount ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>خصم فوق 50 ألف</span><b>-{fmt(o.base_discount)}</b></div> : null}
        {o.coupon_discount ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>كوبون {o.coupon_code}</span><b>-{fmt(o.coupon_discount)}</b></div> : null}
        {o.points_discount ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>نقاط زبون</span><b>-{fmt(o.points_discount)}</b></div> : null}
        <div className="tot-row"><span>التوصيل</span><b>{fmt(o.delivery_fee || 0)}</b></div>
        <div className="tot-row grand"><span>الإجمالي</span><b>{fmt(o.total)}</b></div>
        <div className="note" style={{ marginTop: 8 }}>💵 الدفع عند الاستلام {timeAgo(o.created_at)}</div>
      </div>

      <div className="oc-actions" style={{ justifyContent: 'center' }}>
        {o.status === 'pending' && <button className="btn btn-o-err" disabled={false} onClick={cancel}>إلغاء الطلب</button>}
        {o.status === 'delivered' && <button className="btn btn-p" onClick={() => reorder(o, nav)}>🔄 أعد الطلب</button>}
        <button className="btn btn-o" onClick={() => nav('/stores/' + o.store_id)}>🏬 صفحة المتجر</button>
      </div>
    </div>
  );
}