import React, { useEffect, useState } from 'react';
import { api, fmt, copy, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty } from '../ui';

const SEGS = [100, 20, 0, 50, 200, 30, 100, 20, 50, 30];
const COLORS = ['#1D4ED8', '#38BDF8', '#F97316', '#6366F1', '#06B6D4', '#8B5CF6', '#F59E0B', '#2563EB', '#0EA5E9', '#FB923C'];

export default function Points() {
  const { token, notify, setLoginOpen } = useApp();
  const [data, setData] = useState(null);
  const [spin, setSpin] = useState(null);
  const [ref, setRef] = useState(null);
  const [rot, setRot] = useState(0);
  const [busy, setBusy] = useState(false);
  const [win, setWin] = useState(null);

  useEffect(() => {
    if (!token) return;
    Promise.all([api('/api/customer/points'), api('/api/customer/spin/status'), api('/api/customer/referral')])
      .then(([p, s, r]) => { setData(p); setSpin(s); setRef(r); })
      .catch(() => {});
  }, [token]);

  if (!token) return <div className="sect"><Empty icon="🔐" msg="سجّل دخولك للنقاط"
    action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (!data) return <Loader />;

  const doSpin = async () => {
    if (busy || spin.used_today) return;
    setBusy(true);
    setWin(null);
    try {
      const d = await api('/api/customer/spin', { method: 'POST' });
      const k = SEGS.indexOf(d.points);
      const target = 360 * 5 + (360 - (k * 36 + 18));
      const el = document.getElementById('wheel');
      el.style.transition = 'none';
      el.style.transform = `rotate(${rot % 360}deg)`;
      requestAnimationFrame(() => requestAnimationFrame(() => {
        el.style.transition = 'transform 4.4s cubic-bezier(.12,.65,.24,1)';
        el.style.transform = `rotate(${target}deg)`;
      }));
      setRot(target);
      setTimeout(() => { setWin(d.points); setSpin({ ...spin, used_today: true, points_won_today: d.points }); setData({ ...data, balance: data.balance + d.points }); }, 4500);
    } catch (e) { notify(e.message, 'err'); }
    finally { setBusy(false); }
  };

  return (
    <div className="sect" style={{ maxWidth: 760 }}>
      <div className="grad-navy card-glow" style={{ padding: 26, textAlign: 'center', borderRadius: 20, marginBottom: 18 }}>
        <div style={{ fontSize: 12, letterSpacing: 1, opacity: .8 }}>رصيدك من النقاط</div>
        <div style={{ fontSize: 44, fontWeight: 900, margin: '4px 0' }}>{data.balance}</div>
        <div style={{ fontSize: 13, opacity: .85 }}>كل {data.rate} نقطة = 1000 د.ع خصم 🎉</div>
      </div>

      <div className="card" style={{ padding: 20, marginBottom: 16 }}>
        <div style={{ fontWeight: 900, marginBottom: 4 }}>🎡 عجلة الحظ اليومية</div>
        <div style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 16 }}>
          {spin.used_today ? `لعبت اليوم وكسبت ${spin.points_won_today || 0} نقطة — عد غداً!` : 'دورة واحدة مجانية كل يوم 🍀'}
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', position: 'relative' }}>
          <div className="wheel-wrap">
            <div className="wheel-ptr">🎯</div>
            <div id="wheel" className={`wheel ${spin.used_today && !win ? 'dim' : ''}`} style={{ background: `conic-gradient(${SEGS.map((v, i) => `${COLORS[i]} ${i * 36}deg ${(i + 1) * 36}deg`).join(',')})` }}>
              {SEGS.map((v, i) => (
                <span key={i} className="seg" style={{ transform: `rotate(${i * 36}deg) translateY(-86px)`, color: v === 200 ? '#FFD700' : '#fff', fontWeight: v >= 100 ? 900 : 600 }}>{v}</span>
              ))}
            </div>
          </div>
        </div>
        <button className="btn btn-sun btn-lg btn-block" style={{ marginTop: 16 }} disabled={spin.used_today || busy} onClick={doSpin}>
          {spin.used_today ? 'عد غداً 🌙' : busy ? 'جارٍ التدوير…' : 'التدوير 🎡'}
        </button>
        {win !== null && <div className="win-msg" style={{ marginTop: 10 }}>{win > 0 ? `🏆 مبروك! ربحت ${win} نقطة` : '😅 حظاً أوفر — حاول غداً'}</div>}
      </div>

      <div className="card" style={{ padding: 20, marginBottom: 16 }}>
        <div style={{ fontWeight: 900, marginBottom: 4 }}>🎁 ادعُ صديقاً</div>
        <div style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 12 }}>أنت تحصل {ref ? ref.points_referrer : 100} نقطة وصديقك {ref ? ref.points_new : 50} عند انضمامه بكودك!</div>
        <div className="coupon-in">
          <input className="inp" readOnly value={ref ? ref.code : '—'} />
          <button className="btn btn-p" onClick={() => copy(ref ? ref.code : '', notify)}>نسخ الكود</button>
        </div>
      </div>

      <div className="card" style={{ padding: 18 }}>
        <div className="sect-head" style={{ marginBottom: 8 }}><h2 style={{ fontSize: 14 }}>📜 سجل النقاط</h2></div>
        {!(data.transactions || []).length ? <Empty icon="🪙" msg="لا حركات بعد" /> : data.transactions.map(t => (
          <div key={t.id} className="cc-item">
            <div style={{ flex: 1, fontSize: 13 }}>
              <b style={{ color: 'var(--ink)' }}>{t.note || t.type}</b>
              <div style={{ color: 'var(--muted)', fontSize: 11 }}>{timeAgo(t.created_at)}</div>
            </div>
            <b style={{ color: t.points >= 0 ? 'var(--success)' : 'var(--err)' }}>{t.points >= 0 ? '+' : ''}{t.points}</b>
          </div>
        ))}
      </div>
    </div>
  );
}