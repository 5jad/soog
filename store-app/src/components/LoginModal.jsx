import React, { useState } from 'react';
import { useApp } from '../ctx';
import { api } from '../api';

export default function LoginModal({ open, onClose }) {
  const { login } = useApp();
  const [tab, setTab] = useState('login');
  const [f, setF] = useState({});
  const [sec, setSec] = useState(false);
  if (!open) return null;

  const F = (label, key, ph, type = 'text') => (
    <div className="lf"><label>{label}</label>
      <input type={type} placeholder={ph} value={f[key] || ''} onChange={(e) => setF({ ...f, [key]: e.target.value })} />
    </div>
  );

  const run = async (fn, done) => { try { const d = await fn(); done(d); } catch (e) { alert(e.message); } };

  return (
    <>
      <div className="lmask" onClick={onClose} />
      <div className="login">
        <div className="box">
          <h2>دخول إلى زبون</h2>
          <div className="tabs">
            {[['login', 'تسجيل دخول'], ['reg', 'حساب جديد'], ['otp', 'رمز سري']].map(([k, t]) => (
              <button key={k} className={tab === k ? 'on' : ''} onClick={() => { setTab(k); setSec(false); }}>{t}</button>
            ))}
          </div>
          {tab === 'login' && <>
            {F('رقم الهاتف', 'phone', '07701234567')}
            {F('كلمة المرور', 'pass', '••••••••', 'password')}
            <button className="lbtn" onClick={() => run(async () => await api('/api/auth/login', { method: 'POST', body: JSON.stringify({ phone: f.phone, password: f.pass }) }), login)}>دخول</button>
          </>}
          {tab === 'reg' && <>
            {F('الاسم الكامل', 'name', 'اسمك')}
            {F('رقم الهاتف', 'phone', '07701234567')}
            {F('كلمة المرور', 'pass', '••••••••', 'password')}
            <button className="lbtn amber" onClick={() => run(async () => await api('/api/auth/register', { method: 'POST', body: JSON.stringify({ name: f.name, phone: f.phone, password: f.pass }) }), login)}>إنشاء الحساب</button>
          </>}
          {tab === 'otp' && <>
            {F('رقم الهاتف', 'phone', '07701234567')}
            {!sec && <button className="lbtn" onClick={() => run(async () => await api('/api/auth/request-otp', { method: 'POST', body: JSON.stringify({ phone: f.phone }) }), (d) => { setSec(true); })}
              style={{ width: '100%' }}>أرسل لي الرمز</button>}
            {sec && <>
              {F('رمز التحقق', 'code', '●●●●')}
              {F('كلمة مرور جديدة', 'pass', '••••••••', 'password')}
              <button className="lbtn amber" onClick={() => run(async () => await api('/api/auth/reset-password', { method: 'POST', body: JSON.stringify({ phone: f.phone, code: f.code, new_password: f.pass }) }), login)}>حفظ ودخول</button>
            </>}
          </>}
          <div className="lnote">
            تطبيق <b>زبون</b> للجوال أيضاً — حمّله من <a href="/download">الصفحة الرسمية</a>.
          </div>
        </div>
      </div>
    </>
  );
}