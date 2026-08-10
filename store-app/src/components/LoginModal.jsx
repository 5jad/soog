import React, { useState } from 'react';
import { useApp } from '../ctx';
import { api } from '../api';
import { Modal } from '../ui';

export default function LoginModal({ open, onClose }) {
  const { login } = useApp();
  const [tab, setTab] = useState('login');
  const [f, setF] = useState({});
  const [sec, setSec] = useState(false);
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const F = (label, key, ph, type = 'text') => (
    <div className="lf"><label>{label}</label>
      <input className="inp" type={type} placeholder={ph} value={f[key] || ''} onChange={(e) => setF({ ...f, [key]: e.target.value })} />
    </div>
  );

  const run = async (fn) => {
    setErr(''); setBusy(true);
    try { const d = await fn(); if (d) login(d); }
    catch (e) { setErr(e.message); } finally { setBusy(false); }
  };

  return (
    <Modal open={open} onClose={onClose}>
      <h2 style={{ fontWeight: 900, marginBottom: 15 }}>دخول إلى زبون</h2>
      <div className="tabs">
        {[['login', 'تسجيل دخول'], ['reg', 'حساب جديد'], ['otp', 'رمز سري']].map(([k, t]) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => { setTab(k); setSec(false); setErr(''); }}>{t}</button>
        ))}
      </div>
      {tab === 'login' && <>
        {F('رقم الهاتف', 'phone', '07701234567')}
        {F('كلمة المرور', 'pass', '••••••••', 'password')}
        <button className="btn btn-p btn-lg btn-block" disabled={busy} onClick={() => run(() => api('/api/auth/login', { method: 'POST', body: JSON.stringify({ phone: f.phone, password: f.pass }) }))}>دخول</button>
      </>}
      {tab === 'reg' && <>
        {F('الاسم الكامل', 'name', 'اسمك')}
        {F('رقم الهاتف', 'phone', '07701234567')}
        {F('كلمة المرور', 'pass', '••••••••', 'password')}
        <button className="btn btn-sun btn-lg btn-block" disabled={busy} onClick={() => run(() => api('/api/auth/register', { method: 'POST', body: JSON.stringify({ name: f.name, phone: f.phone, password: f.pass }) }))}>إنشاء الحساب</button>
        <div className="note" style={{ marginTop: 10 }}>🎁 مكافأة دعوة: أنت 100 نقطة وصديقك 50 عند أول طلب.</div>
      </>}
      {tab === 'otp' && <>
        {F('رقم الهاتف', 'phone', '07701234567')}
        {!sec && <button className="btn btn-p btn-lg btn-block" disabled={busy} onClick={() => run(async () => { await api('/api/auth/request-otp', { method: 'POST', body: JSON.stringify({ phone: f.phone }) }); setSec(true); })}>أرسل لي الرمز</button>}
        {sec && <>
          {F('رمز التحقق', 'code', '●●●●')}
          {F('كلمة مرور جديدة', 'pass', '••••••••', 'password')}
          <button className="btn btn-sun btn-lg btn-block" disabled={busy} onClick={() => run(() => api('/api/auth/reset-password', { method: 'POST', body: JSON.stringify({ phone: f.phone, code: f.code, new_password: f.pass }) }))}>حفظ ودخول</button>
        </>}
      </>}
      {err ? <p style={{ color: 'var(--danger)', fontSize: 12.5, fontWeight: 800, marginTop: 10, textAlign: 'center' }}>{err}</p> : null}
      <div className="note" style={{ marginTop: 13, lineHeight: 2 }}>
        📲 الرمز السري يوصلك عبر بوت التليجرام <b>@soog_otp_bot</b> — ربطه مرة واحدة من شاشة الدخول أيضاً في <a href="/download" style={{ color: 'var(--primary)', fontWeight: 800 }}>تطبيق الجوال</a>.
      </div>
    </Modal>
  );
}