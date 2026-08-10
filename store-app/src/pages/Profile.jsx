import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';

export default function Profile() {
  const { token, me, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [govs, setGovs] = useState([]);
  const [f, setF] = useState({ gov: '', district: '', addr: '', note: '', phone: '' });
  const [ok, setOk] = useState(false);

  useEffect(() => {
    api('/api/governorates').then(d => setGovs(d.governorates || d || [])).catch(() => {});
  }, []);

  if (!token) {
    return (
      <section className="sect"><div className="noprod">
        <span className="e">🔐</span>افتح حسابك يتطلب تسجيل دخول
        <br /><button className="lbtn" style={{ maxWidth: 260, margin: '14px auto 0' }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>
      </div></section>
    );
  }
  const m = me || {};
  return (
    <section className="sect" style={{ marginTop: 24 }}>
      <div className="prof">
        <h2>👤 حسابي</h2>
        <div className="row"><b>الاسم</b><span>{m.name || '—'}</span></div>
        <div className="row"><b>رقم الهاتف</b><span>{m.phone || '—'}</span></div>
        <div className="row"><b>نقاطي</b><span>{m.points || 0} نقطة</span></div>
        <div className="row"><b>كود الدعوة</b><span>{m.referral_code || '—'}</span></div>
        <div className="row"><b>الأدوار</b><span>{(m.roles || [m.role]).join('، ')}</span></div>
        <a className="lbtn" style={{ display: 'block', textAlign: 'center', marginTop: 16 }} href="#/orders" onClick={(e) => { e.preventDefault(); nav('/orders'); }}>📦 طلباتي</a>
      </div>
      <div className="prof" style={{ marginTop: 18 }}>
        <h2>🏠 عنواني الافتراضي</h2>
        {ok ? <p style={{ color: 'var(--ok)', fontWeight: 800 }}>تم الحفظ ✓</p> : null}
        <div className="lf"><label>المحافظة</label><select value={f.gov} onChange={(e) => setF({ ...f, gov: e.target.value })}>
          <option value="">اختر المحافظة</option>
          {govs.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
        </select></div>
        <div className="lf"><label>القضاء / المنطقة</label><input value={f.district} onChange={(e) => setF({ ...f, district: e.target.value })} placeholder="مثال: مركز الكوت — حي النصر" /></div>
        <div className="lf"><label>العنوان التفصيلي</label><input value={f.addr} onChange={(e) => setF({ ...f, addr: e.target.value })} placeholder="الشارع / محل إرشاد" /></div>
        <div className="lf"><label>رقم استقبال الطلب</label><input value={f.phone} onChange={(e) => setF({ ...f, phone: e.target.value })} placeholder={m.phone || '07701234567'} /></div>
        <button className="lbtn amber" onClick={async () => {
          try {
            await api('/api/customer/address', { method: 'POST', body: JSON.stringify({ governorate_id: +f.gov, district: f.district, address: f.addr, phone: f.phone }) });
            setOk(true);
          } catch (e) { setOk(false); }
        }}>حفظ العنوان</button>
      </div>
    </section>
  );
}