import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import { Empty, Loader, M, useTitle } from '../ui';

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

  if (!token) return <div className="container section"><Empty icon="🔐" msg="سجّل دخولك لملفك الشخصي"
    action={<button className="btn btn--navy" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
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
    <div className="container section" style={{ maxWidth: 680, paddingBlockStart: 12 }}>
      <div className="promo-banner" style={{ padding: 24, display: 'flex', alignItems: 'center', gap: 14, marginBlockStart: 0 }}>
        <div className="acc-ava">{me.name ? me.name[0] : '👤'}</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 900, fontSize: 18 }}>{me.name}</div>
          <div style={{ fontSize: 13, opacity: .8 }}>{me.phone} {me.verified ? '• ✓ موثق' : '• غير موثق'}</div>
          {pts && <div style={{ fontSize: 13, marginTop: 4 }}>🪙 <b>{pts.balance}</b> نقطة <button className="btn btn--outline btn--sm" style={{ marginInlineStart: 8 }} onClick={() => nav('/points')}>استبدل 🎁</button></div>}
        </div>
      </div>

      <div className="tabs" style={{ marginBlockEnd: 14 }}>
        <button className={tab === 'addrs' ? 'on' : ''} onClick={() => setTab('addrs')}><M n="location_on" s={14} w={700} /> عناويني</button>
        <button className={tab === 'roles' ? 'on' : ''} onClick={() => setTab('roles')}><M n="tune" s={14} w={700} /> أدواري</button>
      </div>

      {tab === 'addrs' && (
        <div className="card" style={{ padding: 18 }}>
          {(addrs || []).map(a => (
            <div key={a.id} className="acc-item" style={{ alignItems: 'center', borderRadius: 'var(--radius-md)', padding: 'var(--space-3)' }}>
              <div style={{ flex: 1, fontSize: 13 }}>
                <b style={{ color: 'var(--ink)' }}>{a.label || 'عنوان'}{a.is_default ? ' (رئيسي)' : ''}</b>
                <div style={{ fontSize: 12, color: 'var(--muted)' }}>{a.address}</div>
              </div>
              <button className="btn btn--danger btn--sm" onClick={() => delAddr(a.id)}>حذف</button>
            </div>
          ))}
          {(addrs || []).length === 0 && <Empty icon="📍" msg="لا عناوين بعد" />}
          {!adding ? <button className="btn btn--outline" style={{ marginTop: 12 }} onClick={() => setAdding(true)}><M n="add" s={15} /> عنوان جديد</button> : (
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBlockEnd: 8 }}>
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
              <div className="rowf" style={{ gap: 8, marginTop: 8 }}>
                <button className="btn btn--navy" onClick={saveAddr}>حفظ</button>
                <button className="btn btn--outline" onClick={() => setAdding(false)}>إلغاء</button>
              </div>
            </div>
          )}
        </div>
      )}

      {tab === 'roles' && (
        <div className="card" style={{ padding: 18 }}>
          <div className="flt-lbl" style={{ marginBlock: '0 10px' }}><M n="tune" s={15} c="var(--muted)" /> مناطق المنصة</div>
          {[
            { p: '/vendor', t: '🧑‍💼 تاجر — إدارة متجرك', d: 'المنتجات، الطلبات، الكوبونات، الأداء', n: 'قريباً', ic: 'storefront' },
            { p: '/delivery', t: '🛵 مندوب — توصيل الطلبات', d: 'طلبات جديدة، خريطة حية، تقارير كاش', n: 'قريباً', ic: 'delivery_dining' },
            { p: '/admin', t: '🛡️ إدارة المنصة', d: 'المستخدمون، المراجعات، الإعدادات', n: 'قريباً', ic: 'shield' },
          ].map(r => (
            <Link key={r.p} to={r.p} className="acc-item" style={{ textDecoration: 'none', marginBlockEnd: 8, borderRadius: 'var(--radius-md)', padding: 'var(--space-3)' }}>
              <span className="gi-ic"><M n={r.ic} s={19} /></span>
              <div style={{ flex: 1 }}>
                <b style={{ color: 'var(--ink)' }}>{r.t}</b>
                <div style={{ fontSize: 12, color: 'var(--muted)' }}>{r.d}</div>
              </div>
              <span className="pill pill--sky">{r.n}</span>
              <M n="chevron_left" s={18} c="var(--muted)" />
            </Link>
          ))}
        </div>
      )}

      <button className="btn btn--danger btn--lg btn--block" style={{ marginTop: 14 }} onClick={() => { logout(); nav('/'); }}><M n="logout" s={16} /> تسجيل الخروج</button>
    </div>
  );
}