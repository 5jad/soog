import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, M, useTitle } from '../ui';
import { STATUS, OrderCard, reorder } from './Orders';

const STEPS = { new: 0, preparing: 1, ready: 2, delivering: 3, delivered: 4 };
const STEP_T = ['تم الإرسال ✅', 'استلمه المتجر', 'انجهز للشحن', 'معه المندوب 🛵', 'تم التوصيل 🎉'];

export default function OrderDetail() {
  useTitle('تفاصيل الطلب');
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
    return <div className="container section" style={{ textAlign: 'center', padding: 60 }}>
      <button className="btn btn--navy" onClick={() => setLoginOpen(true)}>تسجيل الدخول لعرض الطلب</button>
    </div>;
  }
  if (!o) return <Loader />;

  const st = STATUS[o.status] || STATUS.new;
  const cur = STEPS[o.status] ?? 0;
  const bad = ['cancelled', 'returned'].includes(o.status);
  const live = track && track.code;

  const cancel = async () => {
    try {
      const d = await api('/api/customer/orders/' + id + '/cancel', { method: 'POST' });
      notify(d.message || 'تم الإلغاء', 'ok');
      setO({ ...o, status: 'cancelled' });
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <div className="container section" style={{ maxWidth: 680, paddingBlockStart: 12 }}>
      <div className="sect-head"><h2><M n="receipt_long" s={18} c="var(--primary)" /> #{o.code}</h2>
        <span className={`pill ${st.c}`}>{st.e} {st.t}</span></div>

      {live && (
        <div className="card" style={{ padding: 16, marginBlockEnd: 14 }}>
          <div style={{ fontWeight: 900, marginBlockEnd: 6 }}><M n="my_location" s={15} c="var(--primary)" w={700} /> تتبع حي {track.courier_name ? `— المندوب ${track.courier_name}` : ''}</div>
          {track.courier_id ? (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button className="btn btn--navy btn--sm" onClick={() => nav('/orders/' + id + '/track')}><M n="map" s={13} /> فتح الخريطة الحية</button>
              <a className="btn btn--outline btn--sm" href={'tel:' + track.courier_phone}><M n="call" s={13} /> {track.courier_phone}</a>
              <button className="btn btn--outline btn--sm" onClick={() => { api('/api/customer/conversations', { method: 'POST', body: JSON.stringify({ courier_id: track.courier_id }) }).then(d => nav('/chat?id=' + d.conversation.id)).catch(e => notify(e.message, 'err')); }}><M n="chat" s={13} /> شات</button>
            </div>
          ) : <div className="note" style={{ fontSize: 13 }}>🕐 بانتظار تعيين مندوب…</div>}
        </div>
      )}

      <div className="card" style={{ padding: 18, marginBlockEnd: 14 }}>
        <div className="timeline">
          {STEP_T.map((s, i) => (
            <div key={s} className={`tl-step ${i <= cur && !bad ? 'done' : ''} ${i === cur && !bad ? 'now' : ''}`}>
              <div className="tl-dot">{i <= cur && !bad ? '✓' : i + 1}</div>
              <span>{s}</span>
            </div>
          ))}
        </div>
        {bad ? <div className="note" style={{ marginTop: 12, color: 'var(--danger)' }}>
          {o.status === 'returned' ? '↩️ رُجع الطلب.' : '🚫 الطلب ملغي.'}</div> : null}
      </div>

      <OrderCard o={o} nav={nav} mini />

      <div className="card" style={{ padding: 16, marginBlockEnd: 14, fontSize: 13 }}>
        <div className="flt-lbl" style={{ marginBlockEnd: 6 }}>📍 العنوان</div>
        <div>{o.address_text || o.address_full || '—'}</div>
        {o.note ? <div className="note" style={{ marginTop: 6 }}>📝 ملاحظتك: {o.note}</div> : null}
      </div>

      <div className="card" style={{ padding: 16, marginBlockEnd: 14, fontSize: 13 }}>
        <div className="tot-row"><span>المنتجات</span><b>{fmt(o.subtotal)}</b></div>
        {o.discount ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>خصم العروض</span><b>-{fmt(o.discount)}</b></div> : null}
        {o.coupon_code ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>كوبون {o.coupon_code}</span><b>-{fmt(o.coupon_discount || 0)}</b></div> : null}
        {o.points_discount ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>نقاط زبون</span><b>-{fmt(o.points_discount)}</b></div> : null}
        <div className="tot-row"><span>التوصيل</span><b>{fmt(o.delivery_fee || 0)}</b></div>
        <div className="tot-row grand"><span>الإجمالي</span><b>{fmt(o.total)}</b></div>
        <div className="note" style={{ marginTop: 8 }}>💵 الدفع عند الاستلام — {timeAgo(o.created_at)}</div>
      </div>

      <div className="ord-actions" style={{ justifyContent: 'center' }}>
        {o.status === 'new' && <button className="btn btn--danger" onClick={cancel}><M n="close" s={15} /> إلغاء الطلب</button>}
        {o.status === 'delivered' && <button className="btn btn--navy" onClick={() => reorder(o, nav)}><M n="restart_alt" s={16} /> أعد الطلب</button>}
        <button className="btn btn--outline" onClick={() => nav('/stores/' + o.store_id)}><M n="storefront" s={16} /> صفحة المتجر</button>
      </div>
    </div>
  );
}