import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, M, useTitle } from '../ui';

export default function CheckoutPage() {
  useTitle('إتمام الطلب');
  const { token, cart, setCart, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [info, setInfo] = useState(null);
  const [same, setSame] = useState(true);
  const [pay, setPay] = useState('cod');
  const [f, setF] = useState({ name: '', phone: '', governorate: '', address: '', notes: '' });
  const [districts, setDistricts] = useState([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!token) { setLoginOpen(true); return; }
    api('/api/customer/me').then(d => {
      const u = d.user || d;
      setInfo(u);
      setF({ name: u.full_name || '', phone: u.phone || '', governorate: u.governorate || '', address: u.address || '', notes: '' });
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (f.governorate) api('/api/routing/districts?governorate=' + f.governorate).then(d => setDistricts(d.districts || [])).catch(() => {});
  }, [f.governorate]);

  if (!cart) return <Loader />;
  if (!cart.items || !cart.items.length) return <div className="container section"><Empty icon="🛒" msg="المصطفة فارغة" action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/stores')}>تصفح المتاجر</button>} /></div>;

  const sub = cart.subtotal || cart.items.reduce((s, i) => s + i.price * i.quantity, 0);
  const ship = cart.shipping ?? Math.max(0, 2000 - sub);
  const total = Math.max(0, sub - (cart.discount || 0) - (cart.coupon_discount || 0)) + (ship || 0);

  const place = async () => {
    if (!f.name.trim() || !f.phone.trim() || !f.governorate || !f.address.trim()) { notify('أكمل كل الحقول المطلوبة', 'err'); return; }
    setBusy(true);
    try {
      const d = await api('/api/orders', { method: 'POST', body: JSON.stringify({ name: f.name, phone: f.phone, governorate: f.governorate, district: same ? (info && info.district) || '' : '', address: f.address, notes: f.notes, payment: pay } as any) });
      setCart(await api('/api/cart'));
      notify('تم استلام طلبك بنجاح! 🎉', 'ok');
      nav('/orders/' + (d.order ? d.order.id : d.id));
    } catch (e) { notify(e.message, 'err'); } finally { setBusy(false); }
  };

  return (
    <section className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="sect-head">
        <button className="icon-btn" onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={16} w={600} /></button>
        <h2><M n="local_shipping" s={19} c="var(--primary)" /> إتمام الطلب</h2>
        <div className="steps"><span className="on">المصطفة</span><span className="sep">‹</span><span className="on">العنوان</span><span className="sep">‹</span><span>الدفع</span></div>
      </div>

      <div className="card" style={{ padding: 16 }}>
        <div className="flt-lbl">بيانات التوصيل</div>
        <div className="field"><M n="person" s={16} c="var(--muted)" /><input className="inp" placeholder="الاسم الكامل *" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></div>
        <div className="field"><M n="smartphone" s={16} c="var(--muted)" /><input className="inp" placeholder="رقم الهاتف *" dir="ltr" value={f.phone} onChange={(e) => setF({ ...f, phone: e.target.value })} /></div>
        <div className="rowf" style={{ gap: 8 }}>
          <select className="inp" value={f.governorate} onChange={(e) => setF({ ...f, governorate: e.target.value })}>
            <option value="">المحافظة *</option>
            <option>واسط</option><option>بغداد</option><option>ميسان</option><option>ذي قار</option><option>ديالى</option><option>بابل</option><option>كربلاء</option><option>النجف</option><option>البصرة</option><option>أخرى</option>
          </select>
          <select className="inp" disabled={!f.governorate} value={same ? ((info && info.district) || '') : ''} onChange={(e) => setF({ ...f, district: e.target.value })}>
            <option value="">{f.governorate ? (districts.length ? 'القضاء *' : 'لا أقضية') : 'اختر المحافظة أولاً'}</option>
            {districts.map(d => <option key={d} value={d}>{d}</option>)}
          </select>
        </div>
        <div className="field" style={{ alignItems: 'flex-start' }}><M n="location_on" s={16} c="var(--muted)" /><textarea className="inp" rows={2} placeholder="العنوان التفصيلي (حي/شارع/عقار) *" value={f.address} onChange={(e) => setF({ ...f, address: e.target.value })} /></div>
        <div className="field" style={{ alignItems: 'flex-start' }}><M n="notes" s={16} c="var(--muted)" /><textarea className="inp" rows={2} placeholder="ملاحظات للمندوب (اختياري)" value={f.notes} onChange={(e) => setF({ ...f, notes: e.target.value })} /></div>
        {info && info.address && (
          <label className="rowf" style={{ gap: 8, alignItems: 'center', fontSize: 13, fontWeight: 700, color: 'var(--ink)', marginTop: 8, cursor: 'pointer' }}>
            <input type="checkbox" checked={same} onChange={(e) => setSame(e.target.checked)} />
            نفس عنواني المسجل: {info.governorate} {info.district} — {info.address}
          </label>
        )}
      </div>

      <div className="card" style={{ padding: 16, marginTop: 14 }}>
        <div className="flt-lbl">طريقة الدفع</div>
        <div className="grid-2col" style={{ marginTop: 8 }}>
          <button className={`switch ${pay === 'cod' ? 'on' : ''}`} onClick={() => setPay('cod')}><M n="payments" s={17} w={700} /> <div><b>الدفع عند الاستلام</b><small>كاش أو بطاقة عند الباب</small></div></button>
          <button className={`switch ${pay === 'card' ? 'on' : ''}`} onClick={() => setPay('card')}><M n="credit_card" s={17} w={700} /> <div><b>بطاقة إلكترونية</b><small>يدعم زين كاش والبطاقات</small></div></button>
        </div>
      </div>

      <div className="card tot-row" style={{ marginTop: 14 }}>
        <div><span>المنتجات</span><b>{fmt(sub)}</b></div>
        <div><span>خصم العروض</span>{cart.discount ? <b className="gr">-{fmt(cart.discount)}</b> : <b>—</b>}</div>
        <div><span>خصم الكوبون</span>{cart.coupon_discount ? <b className="gr">-{fmt(cart.coupon_discount)}</b> : <b>—</b>}</div>
        <div><span>التوصيل</span>{ship ? <b>{fmt(ship)}</b> : <b className="gr">مجاني</b>}</div>
        <div className="grand"><span>المجموع النهائي</span><b>{fmt(total)}</b></div>
        <button className="btn btn--cta btn--block" disabled={busy} onClick={place}>{busy ? '… يتم الإرسال' : <><M n="lock" s={16} /> تأكيد الطلب</>}</button>
      </div>
    </section>
  );
}