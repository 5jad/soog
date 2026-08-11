import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import { Empty, Loader, useTitle } from '../ui';

export default function Account() {
  useTitle('حسابي');
  const { token, me, logout, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [pts, setPts] = useState(null);
  const [addrs, setAddrs] = useState(null);
  const [adding, setAdding] = useState(false);
  const [govs, setGovs] = useState([]);
  const [newA, setNewA] = useState({ gov: '', dist: '', details: '' });
  const [tab, setTab] = useState('addrs');

  useEffect(() => {
    if (!token) return;
    api('/api/customer/points').then(d => setPts({ balance: d.balance, rate: d.rate })).catch(() => {});
    api('/api/governorates').then(d => setGovs(d.governorates || [])).catch(() => {});
    api('/api/customer/addresses').then(d => setAddrs(d.addresses || [])).catch(() => {});
  }, [token, tab]);

  if (!token) return <div className="sect"><Empty icon="🔐" msg="سجّل دخولك لملفك الشخصي"
    action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (!me) return <Loader />;

  const saveAddr = async () => {
    if (!newA.gov || !newA.dist || !newA.details.trim()) { notify('أكمل الحقول', 'err'); return; }
    try {
      const d = await api('/api/customer/addresses', { method: 'POST', body: JSON.stringify({ district_id: +newA.dist, details: newA.details.trim() }) });
      setAddrs([...(addrs || []), d.address]);
      setNewA({ gov: '', dist: '', details: '' });
      notify('أُضيف العنوان ✓', 'ok');
    } catch (e) { notify(e.message, 'err'); }
  };

  const delAddr = async (id) => {
    try {
      await api('/api/customer/addresses/' + id, { method: 'DELETE' });
      setAddrs(addrs.filter(a => a.id !== id));
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <div className="sect" style={{ maxWidth: 680 }}>
      <div className="grad-navy card-glow" style={{ padding: 24, borderRadius: 20, display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
        <div className="acc-ava">{me.name ? me.name[0] : '👤'}</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 900, fontSize: 18 }}>{me.name}</div>
          <div style={{ fontSize: 13, opacity: .8 }}>{me.phone} {me.verified ? '• ✓ موثق' : '• غير موثق'}</div>
          {pts && <div style={{ fontSize: 13, marginTop: 4 }}>🪙 <b>{pts.balance}</b> نقطة <button className="btn btn-o btn-sm" style={{ marginInlineStart: 8 }} onClick={() => nav('/points')}>استبدل 🎁</button></div>}
        </div>
      </div>

      <div className="tabs" style={{ marginBottom: 14 }}>
        {['addrs', 'roles'].map(t => (
          <button key={t} className={`tab ${tab === t ? 'on' : ''}`} onClick={() => setTab(t)}>{t === 'addrs' ? '📍 عناويني' : '🎛️ أدواري'}</button>
        ))}
      </div>

      {tab === 'addrs' && (
        <div className="card" style={{ padding: 18 }}>
          {(addrs || []).map(a => (
            <div key={a.id} className="cc-item" style={{ alignItems: 'center' }}>
              <div style={{ flex: 1, fontSize: 13 }}>
                <b style={{ color: 'var(--ink)' }}>{a.label || 'عنوان'}{a.is_default ? ' (رئيسي)' : ''}</b>
                <div style={{ fontSize: 12, color: 'var(--muted)' }}>{a.address}</div>
              </div>
              <button className="btn btn-o-err btn-sm" onClick={() => delAddr(a.id)}>حذف</button>
            </div>
          ))}
          {(addrs || []).length === 0 && <Empty icon="📍" msg="لا عناوين بعد" />}
          {!adding ? <button className="btn btn-o" style={{ marginTop: 12 }} onClick={() => setAdding(true)}>+ عنوان جديد</button> : (
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 8 }}>
                <select className="inp" style={{ flex: '1 1 150px' }} value={newA.gov} onChange={(e) => setNewA({ ...newA, gov: e.target.value, dist: '' })}>
                  <option value="">المحافظة</option>
                  {govs.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
                </select>
                <select className="inp" style={{ flex: '1 1 150px' }} value={newA.dist} onChange={(e) => setNewA({ ...newA, dist: e.target.value })}>
                  <option value="">الحي / المنطقة</option>
                  {(govs.find(g => g.id == newA.gov)?.districts || []).map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
                </select>
              </div>
              <input className="inp" placeholder="التفاصيل: الشارع / علامة فارقة" value={newA.details} onChange={(e) => setNewA({ ...newA, details: e.target.value })} />
              <div className="lf" style={{ marginTop: 8 }}>
                <button className="btn btn-p" onClick={saveAddr}>حفظ</button>
                <button className="btn btn-o" onClick={() => setAdding(false)}>إلغاء</button>
              </div>
            </div>
          )}
        </div>
      )}

      {tab === 'roles' && (
        <div className="card" style={{ padding: 18 }}>
          <div style={{ fontWeight: 900, marginBottom: 10 }}>🎛️ مناطق المنصة</div>
          {[
            { p: '/vendor', t: '🧑‍💼 تاجر — إدارة متجرك', d: 'المنتجات، الطلبات، الكوبونات، الأداء', n: 'قريباً' },
            { p: '/delivery', t: '🛵 مندوب — توصيل الطلبات', d: 'طلبات جديدة، خريطة حية، تقارير كاش', n: 'قريباً' },
            { p: '/admin', t: '🛡️ إدارة المنصة', d: 'المستخدمون، المراجعات، الإعدادات', n: 'قريباً' },
          ].map(r => (
            <Link key={r.p} to={r.p} className="cc-item" style={{ textDecoration: 'none' }}>
              <div style={{ flex: 1, fontSize: 13 }}>
                <b style={{ color: 'var(--ink)' }}>{r.t}</b>
                <div style={{ fontSize: 12, color: 'var(--muted)' }}>{r.d}</div>
              </div>
              <span className="pill pill-sky">{r.n}</span>
              <span style={{ color: 'var(--primary)' }}>‹</span>
            </Link>
          ))}
        </div>
      )}

      <button className="btn btn-o-err btn-lg btn-block" style={{ marginTop: 14 }} onClick={() => { logout(); nav('/'); }}>🚪 تسجيل الخروج</button>
    </div>
  );
}