import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, priceOf } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, LottiePlayer, useTitle } from '../ui';

export default function Checkout() {
  useTitle('إتمام الطلب');
  const { token, me, setLoginOpen, refreshCart, notify } = useApp();
  const nav = useNavigate();
  const [step, setStep] = useState(1);
  const [cart, setCart] = useState(null);
  const [govs, setGovs] = useState([]);
  const [addrs, setAddrs] = useState([]);
  const [addrSel, setAddrSel] = useState(null);
  const [newA, setNewA] = useState({ gov: '', dist: '', details: '' });
  const [pts, setPts] = useState({ balance: 0, rate: 100 });
  const [redeem, setRedeem] = useState(0);
  const [coupons, setCoupons] = useState({});
  const [codes, setCodes] = useState({});
  const [busy, setBusy] = useState(false);
  const [created, setCreated] = useState([]);

  useEffect(() => {
    if (!token) return;
    Promise.all([api('/api/customer/cart'), api('/api/governorates'), api('/api/customer/addresses'), api('/api/customer/points')])
      .then(([c, g, a, p]) => {
        setCart(c.items || []);
        setGovs(g.governorates || []);
        setAddrs(a.addresses || []);
        setPts({ balance: p.balance || 0, rate: p.rate || 100 });
        if ((a.addresses || []).length && !addrSel) setAddrSel(a.addresses[0].id);
      }).catch(() => setCart([]));
  }, [token]);

  if (!token) {
    return <div className="sect"><Empty icon="🔐" msg="أكمل طلبك يتطلب تسجيل دخول"
      action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  }
  if (!cart) return <Loader />;
  if (!cart.length) {
    return <div className="sect"><Empty icon="🛒" msg="سلتك فاضية" lottie="/animations/empty_state.json" action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => nav('/')}>تسوّق الآن</button>} /></div>;
  }

  const groups = {};
  for (const it of cart) (groups[it.store_id] = groups[it.store_id] || { items: [] }).items.push(it);
  const needAddr = !addrSel;

  const saveAddr = async () => {
    if (!newA.gov || !newA.dist || !newA.details.trim()) { notify('أكمل المحافظة والحي والعنوان', 'err'); return; }
    try {
      const d = await api('/api/customer/addresses', { method: 'POST', body: JSON.stringify({ district_id: +newA.dist, details: newA.details.trim() }) });
      setAddrs([...addrs, d.address]);
      setAddrSel(d.address.id);
      setNewA({ gov: '', dist: '', details: '' });
      notify('العنوان حُفظ ✓', 'ok');
    } catch (e) { notify(e.message, 'err'); }
  };

  const applyCoup = async (sid) => {
    const g = groups[sid];
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    try {
      const d = await api('/api/customer/cart/apply-coupon', { method: 'POST', body: JSON.stringify({ store_id: +sid, code: codes[sid], subtotal: sub }) });
      setCoupons({ ...coupons, [sid]: d });
      notify('فعّل الكوبون ✓', 'ok');
    } catch (e) { notify(e.message, 'err'); }
  };

  const totals = {};
  for (const [sid, g] of Object.entries(groups)) {
    const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    const freeMin = g.items[0].free_delivery_min || 50000;
    const fee = sub >= freeMin ? 0 : (g.items[0].delivery_fee || 0);
    const base = sub >= 50000 ? 5000 : 0;
    const coupD = coupons[sid] ? coupons[sid].discount : 0;
    totals[sid] = { sub, fee, base, coupD, total: Math.max(0, sub + fee - base - coupD) };
  }
  const grand = Object.values(totals).reduce((a, t) => a + t.total, 0);

  const place = async () => {
    if (needAddr) { notify('اختر أو أضف عنواناً أولاً', 'err'); return; }
    setBusy(true);
    const groupId = 'g' + Date.now();
    const made = [];
    try {
      let first = true;
      for (const [sid] of Object.entries(groups)) {
        const d = await api('/api/customer/orders', { method: 'POST', body: JSON.stringify({
          store_id: +sid,
          address_id: addrSel,
          coupon_code: coupons[sid] && coupons[sid].code ? coupons[sid].code : undefined,
          redeem_points: first ? redeem : 0,
          group_id: groupId,
          payment_method: 'cod',
        }) });
        made.push(d.order || d);
        first = false;
      }
      await refreshCart();
      setCreated(made);
      setStep(3);
    } catch (e) {
      notify(e.message, 'err');
      if (made.length) notify(`نُفّذ ${made.length} طلب — ${e.message}`, 'err');
    } finally { setBusy(false); }
  };

  if (step === 3) {
    return (
      <div className="sect" style={{ maxWidth: 620 }}>
        <div className="card" style={{ padding: 34, textAlign: 'center' }}>
          {/* confetti — once عند فتح شاشة النجاح */}
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
            <LottiePlayer src="/animations/order_success.json" size={160} loop={false} />
          </div>
          <h2 style={{ fontWeight: 900, fontSize: 22 }}>تم استلام طلبك بنجاح!</h2>
          <div className="note" style={{ margin: '16px 0', textAlign: 'right' }}>
            أرقام طلباتك: <b style={{ color: 'var(--primary)' }}>{created.map(c => c.code).join('، ')}</b><br />
            💵 الدفع عند الاستلام — سيتصل بك المحل لتأكيد الطلب وأرقام المندوبين تظهر في التتبع الحي.
          </div>
          <button className="btn btn-p btn-lg" onClick={() => nav('/orders/' + created[0].id)}>📦 تابع طلبك وموقع المندوب</button>
        </div>
      </div>
    );
  }

  return (
    <div className="sect" style={{ maxWidth: 860, marginTop: 22 }}>
      <div className="sect-head"><h2><span className="ln" />🚚 إتمام الطلب</h2></div>
      <div className="steps">
        <div className={`step ${step >= 1 ? 'now' : 'done'} ${step > 1 ? 'done' : ''}`}><i>1</i><p>العنوان</p></div>
        <div className={`step ${step >= 2 ? 'now' : ''} ${step > 2 ? 'done' : ''}`}><i>2</i><p>المراجعة</p></div>
        <div className={`step ${step >= 3 ? 'now' : ''}`}><i>3</i><p>التأكيد</p></div>
      </div>

      {step === 1 && (
        <div className="card" style={{ padding: 20 }}>
          <div style={{ fontWeight: 900, marginBottom: 12 }}>📍 عنوان التسليم</div>
          {addrs.map(a => (
            <label key={a.id} className="card" style={{ display: 'flex', gap: 10, padding: 13, marginBottom: 8, cursor: 'pointer', borderColor: addrSel === a.id ? 'var(--primary)' : undefined }}>
              <input type="radio" checked={addrSel === a.id} onChange={() => setAddrSel(a.id)} />
              <div style={{ fontSize: 13 }}>
                <b style={{ color: 'var(--ink)' }}>{a.label || 'عنوان'}{a.is_default ? ' (رئيسي)' : ''}</b>
                <div style={{ color: 'var(--muted)', fontSize: 12 }}>{a.address}</div>
              </div>
            </label>
          ))}
          <div className="lf" style={{ marginTop: 10 }}><label>أو أضف عنوان جديد</label>
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
            <button className="btn btn-o btn-sm" style={{ marginTop: 8 }} onClick={saveAddr}>+ حفظ واستخدام</button>
          </div>
          <button className="btn btn-p btn-lg btn-block" style={{ marginTop: 16 }} disabled={needAddr} onClick={() => setStep(2)}>التالي: مراجعة الطلب ←</button>
        </div>
      )}

      {step === 2 && (
        <div>
          {Object.entries(groups).map(([sid, g]) => {
            const t = totals[sid];
            const s = g.items[0];
            return (
              <div key={sid} className="card" style={{ padding: 18, marginBottom: 14 }}>
                <div className="cgroup-t">🏬 {s.store_name}</div>
                {g.items.map(it => (
                  <div key={it.id} className="citem">
                    <div className="c"><div className="n">{it.name} × {it.qty}</div>{it.variant ? <div className="v">{it.variant}</div> : null}</div>
                    <div className="p">{fmt(priceOf(it) * it.qty)}</div>
                  </div>
                ))}
                {!coupons[sid] && (
                  <div className="coupon-in">
                    <input className="inp" placeholder="كود كوبون لهذا المحل" value={codes[sid] || ''} onChange={(e) => setCodes({ ...codes, [sid]: e.target.value })} />
                    <button className="btn btn-o" onClick={() => applyCoup(sid)}>فعّل</button>
                  </div>
                )}
                {coupons[sid] ? <div className="coupon-tag">🎟️ {coupons[sid].code} — خصم {fmt(coupons[sid].discount)} <button onClick={() => setCoupons({ ...coupons, [sid]: null })}>✕</button></div> : null}
                <div className="tot-row"><span>المنتجات</span><b>{fmt(t.sub)}</b></div>
                {t.base ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>خصم فوق 50 ألف 🎉</span><b>-{fmt(t.base)}</b></div> : null}
                {t.coupD ? <div className="tot-row" style={{ color: 'var(--success)' }}><span>الكوبون</span><b>-{fmt(t.coupD)}</b></div> : null}
                <div className="tot-row"><span>التوصيل</span><b>{t.fee ? fmt(t.fee) : 'مجاني ✓'}</b></div>
                <div className="tot-row grand"><span>إجمالي المحل</span><span>{fmt(t.total)}</span></div>
              </div>
            );
          })}
          <div className="card" style={{ padding: 18, marginBottom: 14 }}>
            <div className="sect-head" style={{ marginBottom: 8 }}><h2 style={{ fontSize: 14 }}>🎁 نقاط زبون</h2><span style={{ fontSize: 12, color: 'var(--muted)' }}>رصيدك: <b style={{ color: 'var(--primary)' }}>{pts.balance}</b> نقطة</span></div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <input className="inp" type="number" min="0" max={pts.balance} placeholder={`استبدل بهامش ${pts.rate} (كل ${pts.rate} = 1000 د.ع)`} value={redeem || ''} onChange={(e) => setRedeem(Math.max(0, Math.min(Number(e.target.value) || 0, pts.balance)))} />
              <button className="btn btn-o" disabled={!redeem} onClick={() => setRedeem(Math.floor(redeem / pts.rate) * pts.rate)}>تثبيت</button>
            </div>
            {redeem ? <div className="note" style={{ marginTop: 8 }}>الخصم: <b style={{ color: 'var(--success)' }}>{fmt(Math.floor(redeem / pts.rate) * 1000)}</b> — يُخصم من طلب المحل الأول.</div> : null}
          </div>
          <div className="card" style={{ padding: 18 }}>
            <div className="tot-row grand" style={{ fontSize: 18 }}><span>الإجمالي الكلي</span><span>{fmt(grand)}</span></div>
            <div className="note" style={{ margin: '10px 0' }}>💵 الدفع عند الاستلام — {Object.keys(groups).length} طلب برحلة توصيل واحدة.</div>
            <button className="btn btn-sun btn-lg btn-block" disabled={busy} onClick={place}>✅ تأكيد الطلب{redeem ? ` — ${fmt(Math.floor(redeem / pts.rate) * 1000)} خصم بالنقاط` : ''}</button>
          </div>
        </div>
      )}
    </div>
  );
}