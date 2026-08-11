import React, { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty } from '../ui';
import { STATUS } from './Orders';

let L = null;
const ic = (e) => (L ? L.divIcon({ className: '', html: `<div class="lm">${e}</div>`, iconSize: [34, 34], iconAnchor: [17, 34] }) : null);

export default function Track() {
  const { id } = useParams();
  const { token, notify } = useApp();
  const nav = useNavigate();
  const mapEl = useRef(null);
  const mapRef = useRef(null);
  const mStore = useRef(null);
  const mUser = useRef(null);
  const mCou = useRef(null);
  const pathRef = useRef(null);
  const [t, setT] = useState(null);
  const [err, setErr] = useState(null);

  useEffect(() => {
    if (!token) { setErr('سجّل دخولك للتتبع'); return; }
    let live = true;
    const load = async () => {
      try {
        const d = await api('/api/customer/orders/' + id + '/track');
        if (live) setT(d);
      } catch (e) { if (live) setErr(e.message); }
    };
    load();
    const iv = setInterval(load, 12000);
    return () => { live = false; clearInterval(iv); };
  }, [token, id]);

  useEffect(() => {
    if (!t || !t.code || !token) return;
    import('leaflet').then(Lm => {
      L = Lm;
      if (!mapRef.current) {
        mapRef.current = Lm.map(mapEl.current, { zoomControl: false, attributionControl: false }).setView([33.31, 44.36], 12);
        Lm.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(mapRef.current);
      }
      const mp = Lm.map;
      if (!mStore.current) mStore.current = mp.marker([t.store_lat, t.store_lng], { icon: ic('🏬') }).addTo(mapRef.current).bindPopup('<b>' + t.store_name + '</b>');
      if (!mUser.current) mUser.current = mp.marker([t.user_lat, t.user_lng], { icon: ic('📍') }).addTo(mapRef.current).bindPopup('<b>عنوان التوصيل</b>');
      if (mCou.current) mapRef.current.removeLayer(mCou.current);
      if (t.courier_lat && t.courier_lng) {
        mCou.current = mp.marker([t.courier_lat, t.courier_lng], { icon: ic(t.status === 'on_the_way' ? '🚚' : '🛵') }).addTo(mapRef.current).bindPopup('<b>' + (t.courier_name || 'المندوب') + '</b>');
      }
      if (pathRef.current) { mapRef.current.removeLayer(pathRef.current); pathRef.current = null; }
      if ((t.path || []).length) pathRef.current = Lm.polyline(t.path, { color: '#12294E', weight: 4, opacity: 0.8, dashArray: '8 6' }).addTo(mapRef.current);
      const pts = [[t.store_lat, t.store_lng], [t.user_lat, t.user_lng]];
      if (mCou.current) pts.push([t.courier_lat, t.courier_lng]);
      mapRef.current.fitBounds(Lm.latLngBounds(pts).pad(0.2));
    });
  }, [t, token]);

  if (err) return <div className="sect"><Empty icon="🔐" msg={err} /></div>;
  if (!t) return <Loader />;

  const st = STATUS[t.status] || STATUS.pending;
  const chat = async () => {
    try {
      const d = await api('/api/customer/conversations', { method: 'POST', body: JSON.stringify({ courier_id: t.courier_id }) });
      nav('/chat?id=' + d.conversation.id);
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <div className="sect" style={{ maxWidth: 760 }}>
      <div className="sect-head"><h2><span className="ln" />📍 تتبع الطلب #{t.code}</h2>
        <span className={`pill ${st.c}`}>{st.e} {st.t}</span></div>

      <div className="card" style={{ padding: 0, overflow: 'hidden', marginBottom: 14 }}>
        <div ref={mapEl} style={{ height: 300, width: '100%', background: '#e8ecf1' }}></div>
        <div className="track-legend">
          <span><b>🏬</b> المتجر</span><span><b>📍</b> عنوانك</span><span><b>🛵</b> المندوب</span>
        </div>
        <div style={{ padding: 14, borderTop: '1px solid var(--line)' }}>
          {t.courier_id ? (
            <div className="courier-card">
              <div className="courier-ava">🛵</div>
              <div style={{ flex: 1, fontSize: 13 }}>
                <b>{t.courier_name}</b>
                <div style={{ color: 'var(--muted)', fontSize: 12 }}>{t.status === 'on_the_way' ? '🚚 في الطريق إليك' : 'قادم للمتجر لاستلام طلبك'}</div>
                <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                  <a className="btn btn-p btn-sm" href={'tel:' + t.courier_phone}>📞 اتصال</a>
                  <button className="btn btn-o btn-sm" onClick={chat}>💬 راسله</button>
                  <button className="btn btn-o btn-sm" onClick={() => nav('/orders/' + id)}>📦 التفاصيل</button>
                </div>
              </div>
            </div>
          ) : (
            <div className="note" style={{ textAlign: 'center', padding: 14 }}>
              🕐 {t.status === 'rejected' ? 'الطلب رُفض — تفاصيل في صفحة الطلب' : 'بانتظار قيام المتجر بتجهيز طلبك وتعيين مندوب…'} (تبني حي كل ~12 ثانية)
            </div>
          )}
        </div>
      </div>
    </div>
  );
}