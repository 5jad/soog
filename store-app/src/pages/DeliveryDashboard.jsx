import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, timeAgo } from '../api';
import { M, Empty, Loader } from '../ui';

const STAT = {
  new: ['جديد', 'st-new'], preparing: ['قيد التحضير', 'st-pending'], ready: ['جاهز', 'st-ready'],
  delivering: ['بالتوصيل', 'st-delivering'], delivered: ['تم التسليم', 'st-delivered'],
  cancelled: ['ملغي', 'st-cancelled'], returned: ['مرتجع', 'st-returned'],
};
const cls = (s) => 'c-chip ' + (STAT[s] || ['', ''])[1];

/* ═══════════════ لوحة المندوب — ويب ═══════════════ */
export default function DeliveryDashboard() {
  const { me, setLoginOpen, notify } = useApp();
  const nav = useNavigate();
  const [online, setOnline] = useState(false);
  const [loading, setLoading] = useState(true);
  const [available, setAvailable] = useState([]);
  const [trip, setTrip] = useState(null);
  const [wallet, setWallet] = useState(null);
  const [stats, setStats] = useState(null);
  const [tab, setTab] = useState('trip');
  const [busy, setBusy] = useState(false);

  const isDelivery = me && me.roles && me.roles.includes('delivery');

  const load = async (silent = false) => {
    try {
      const [st, avail, tr, wl, sts] = await Promise.all([
        api('/api/delivery/status'), api('/api/delivery/available'),
        api('/api/delivery/trip'), api('/api/delivery/wallet'), api('/api/delivery/stats'),
      ]);
      setOnline(!!st.online); setAvailable(avail.orders || []); setTrip(tr.trip);
      setWallet(wl.wallet); setStats(sts.stats);
    } catch (e) { if (!silent) notify(e.message, 'err'); } finally { setLoading(false); }
  };
  useEffect(() => { if (isDelivery) load(); else setLoading(false); }, [isDelivery]);
  useEffect(() => {
    if (!isDelivery) return;
    const t = setInterval(() => load(true), 8000);
    return () => clearInterval(t);
  }, [isDelivery]);

  if (!isDelivery) {
    return <div className="container section">
      <Empty icon="🛵" msg="هذه المنطقة للمندوبين فقط"
        sub={me ? 'حسابك مو مفعّل كمندوب — تواصل مع الإدارة' : 'سجّل دخولك بحساب المندوب أول'}
        action={<button className="btn" onClick={() => me ? nav('/') : setLoginOpen(true)}>{me ? 'عودة للمتجر' : 'دخول'}</button>} />
    </div>;
  }
  if (loading) return <div className="container section"><Loader /></div>;

  const toggleOnline = async () => {
    try {
      const d = await api('/api/delivery/online', { method: 'POST', body: JSON.stringify({ online: !online }) });
      setOnline(d.online);
      notify(d.online ? 'صرت متصل — تستلم الطلبات 🛵' : 'غيرت حالتك لغير متصل', d.online ? 'ok' : '');
      load(true);
    } catch (e) { notify(e.message, 'err'); }
  };

  const accept = async (orderId) => {
    if (!confirm('تأخذ هذا الطلب برحلتك؟')) return;
    setBusy(orderId);
    try {
      await api('/api/delivery/accept/' + orderId, { method: 'POST' });
      notify('انقبلت الرحلة — الله يوفقك 🛵', 'ok');
      load();
    } catch (e) { notify(e.message, 'err'); } finally { setBusy(null); }
  };

  const pickup = async () => {
    try { await api('/api/delivery/pickup', { method: 'POST', body: JSON.stringify({ trip_id: trip.id }) }); notify('استلمت الطلب من المحل ✓', 'ok'); load(); }
    catch (e) { notify(e.message, 'err'); }
  };
  const delivered = async () => {
    if (!confirm('تم تسليم الطلب للزبون؟')) return;
    try { await api('/api/delivery/delivered', { method: 'POST', body: JSON.stringify({ trip_id: trip.id }) }); notify('تم التسليم 🎉 — كسب الزبون نقاط', 'ok'); load(); }
    catch (e) { notify(e.message, 'err'); }
  };

  const openGmaps = (coord, label) => {
    if (!coord) return;
    const [la, ln] = coord.split(',');
    window.open(`https://www.google.com/maps/dir/?api=1&destination=${la},${ln}&travelmode=driving`, '_blank');
  };

  return (
    <div className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="dash-head">
        <div>
          <div className="dash-title">لوحة المندوب 🛵</div>
          <div className="dash-sub">{me.name} · اليوم: {stats ? stats.today_orders : 0} طلب ({stats ? stats.delivered : 0} مسلّم)</div>
        </div>
        <button className={`btn btn--sm ${online ? 'btn--outline' : ''}`} style={online ? {} : { background: 'linear-gradient(135deg, var(--success-deep), var(--success-light))', boxShadow: 'none' }} onClick={toggleOnline}>
          <span className="online-dot on" />{online ? 'متصل ✓' : 'فعّل الاتصال'}
        </button>
      </div>

      <div className="del-tiles">
        <div className="del-tile"><b>{stats ? stats.delivered : 0}</b><small>مسلّم اليوم</small></div>
        <div className="del-tile"><b>{available.length}</b><small>طلبات متاحة</small></div>
        <div className="del-tile"><b style={{ color: 'var(--success)' }}>{wallet ? fmt(wallet.balance) : '—'}</b><small>رصيد كاش</small></div>
      </div>

      {!online && (
        <div className="card" style={{ textAlign: 'center', padding: 20, marginBlockStart: 12 }}>
          <M n="sleep" s={26} c="var(--muted)" />
          <div className="muted" style={{ marginTop: 6 }}>أنت غير متصل — شغّل الاتصال ليوصلك الطلبات الجاهزة</div>
        </div>
      )}

      {online && (
        <div className="tabs" style={{ margin: '14px 0 4px' }}>
          <button className={tab === 'trip' ? 'on' : ''} onClick={() => setTab('trip')}><M n="route" s={17} />رحلتي</button>
          <button className={tab === 'available' ? 'on' : ''} onClick={() => setTab('available')}><M n="list_alt" s={17} />متاحة ({available.length})</button>
        </div>
      )}

      {online && tab === 'trip' && (
        trip ? <TripCard trip={trip} pickup={pickup} delivered={delivered} openGmaps={openGmaps} />
          : <Empty icon="😴" msg="ماكو رحلة حالياً" sub="استلم طلب جاهز من قائمة المتاحة" />
      )}

      {online && tab === 'available' && (
        available.length === 0
          ? <Empty icon="🕐" msg="لا طلبات جاهزة الآن" sub="ينزلون هنا لحظة ما يجهزوهم المتاجر" />
          : available.map(o => (
            <div key={o.id} className="card order-card" style={{ marginBlockEnd: 10 }}>
              <div className="ord-top">
                <div>
                  <b>#{o.code}</b> <span className="muted">· {o.store_name}</span>
                  <div className="muted">{o.items_count ? `${o.items_count} منتج · ` : ''}{fmt(o.total)} · {o.user_name}</div>
                </div>
                <span className={cls('ready')}>جاهز</span>
              </div>
              <div style={{ padding: '0 14px 14px' }}>
                <div className="mini-row"><span>المحل</span><b>{o.store_address || ''}</b></div>
                <div className="mini-row"><span>الزبون</span><b>{o.user_address_label || o.address_text || '—'}</b></div>
                <div className="mini-row" style={{ marginTop: 6 }}><span>هاتف الزبون</span><b dir="ltr">{o.user_phone || ''}</b></div>
                {(o.store_lat && o.user_lat) && (
                  <button className="btn btn--outline btn--sm" style={{ marginTop: 10 }} onClick={() => openGmaps(`${o.store_lat},${o.store_lng}`, o.store_name)}>
                    <M n="map" s={16} />المسار للزبون
                  </button>
                )}
                <button className="btn btn--cta btn--sm" style={{ marginTop: 10 }} disabled={busy === o.id} onClick={() => accept(o.id)}>
                  <M n="check_circle" s={16} />استلم الطلب
                </button>
              </div>
            </div>
          ))
      )}

      {wallet && wallet.reports && (
        <div className="card" style={{ marginBlockStart: 14, padding: 14 }}>
          <div className="card-h">تقارير الكاش اليومية</div>
          {wallet.reports.length === 0 ? <div className="muted" style={{ marginTop: 8 }}>لا تقارير بعد</div> : wallet.reports.slice(0, 5).map(r => (
            <div key={r.id} className="mini-row" style={{ padding: '7px 0', borderBottom: '1px solid var(--line)' }}>
              <span><M n="payments" s={15} c="var(--success)" /> تقرير {r.receipt_no || ''} <small className="muted">({timeAgo(r.created_at)})</small></span>
              <b style={{ color: 'var(--success)' }}>+{fmt(r.net)}</b>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function TripCard({ trip, pickup, delivered, openGmaps }) {
  const storeCoord = trip.store_lat ? `${trip.store_lat},${trip.store_lng}` : null;
  const userCoord = trip.user_lat ? `${trip.user_lat},${trip.user_lng}` : null;
  const picked = !!trip.picked_at;
  return (
    <div className="card trip-card">
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span className="online-dot on" style={{ display: 'inline-block' }} />
        <div>
          <b style={{ fontSize: 16 }}>رحلة نشطة — #{trip.code}</b>
          <div style={{ color: 'rgba(255,255,255,.75)', fontSize: 12 }}>{trip.items.length} منتج · {fmt(trip.total)}</div>
        </div>
      </div>

      {trip.orders && trip.orders.length > 0 && (
        <div style={{ marginTop: 10, background: 'rgba(255,255,255,.1)', borderRadius: 12, padding: 10 }}>
          <div style={{ color: 'rgba(255,255,255,.8)', fontSize: 12 }}>طلبات الرحلة ({trip.orders.length})</div>
          {trip.orders.map(o => (
            <div key={o.id} className="mini-row" style={{ color: '#fff', paddingTop: 6, fontSize: 12 }}>
              <span>#{o.code} — {o.store_name}</span><span>{fmt(o.total)}</span>
            </div>
          ))}
        </div>
      )}

      <div className="trip-stops">
        <div className="trip-stop">
          <M n="storefront" s={18} c="var(--warning)" />
          <div className="prod-info">
            <b style={{ color: '#fff' }}>{trip.store_name}</b>
            <div style={{ color: 'rgba(255,255,255,.75)', fontSize: 12 }}>{trip.store_address}</div>
          </div>
          {storeCoord && <button className="btn btn--sm" style={{ background: 'rgba(255,255,255,.18)', boxShadow: 'none', minHeight: 36 }} onClick={() => openGmaps(storeCoord, trip.store_name)}><M n="map" s={15} /></button>}
        </div>
        <div className="trip-line" />
        <div className="trip-stop">
          <M n="person_pin_circle" s={18} c="#fff" />
          <div className="prod-info">
            <b style={{ color: '#fff' }}>{trip.user_name}</b>
            <div style={{ color: 'rgba(255,255,255,.75)', fontSize: 12 }}>{trip.user_address_label || trip.address_text || ''} · <span dir="ltr">{trip.user_phone}</span></div>
          </div>
          {userCoord && <button className="btn btn--sm" style={{ background: 'rgba(255,255,255,.18)', boxShadow: 'none', minHeight: 36 }} onClick={() => openGmaps(userCoord, trip.user_name)}><M n="map" s={15} /></button>}
        </div>
      </div>

      <div className="two-col" style={{ marginTop: 16 }}>
        {!picked
          ? <button className="btn btn--cta btn--sm" onClick={pickup}><M n="storefront" s={16} />استلمت من المحل ✓</button>
          : <span className="c-chip st-delivered" style={{ justifySelf: 'center' }}><M n="check" s={14} />استلمته من المحل</span>}
        <button className="btn btn--sm" style={{ background: 'rgba(255,255,255,.18)', boxShadow: 'none' }} onClick={delivered}>
          <M n="done_all" s={16} />سلمت الطلب 🎉
        </button>
      </div>
    </div>
  );
}