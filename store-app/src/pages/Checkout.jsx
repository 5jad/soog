import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt, priceOf } from '../api';
import { useApp } from '../ctx';
import { Img } from '../ui';

export default function Checkout() {
  const { token, setLoginOpen, me, refreshCart, notify } = useApp();
  const [state, setState] = useState('load');
  const [items, setItems] = useState([]);
  const [govs, setGovs] = useState([]);
  const [f, setF] = useState({ gov: '', district: '', addr: '', note: '', phone: '' });
  const [done, setDone] = useState(null);
  const nav = useNavigate();

  useEffect(() => {
    if (!token) { setState('login'); return; }
    Promise.all([api('/api/customer/cart'), api('/api/governorates')])
      .then(([c, g]) => {
        setItems(c.items || []);
        setGovs(g.governorates || g || []);
        setState(c.items && c.items.length ? 'form' : 'empty');
      })
      .catch(() => setState('empty'));
  }, [token]);

  if (!token || state === 'login') {
    return (
      <section className="sect"><div className="noprod"><span className="e">🔐</span>أكمل الطلب يتطلب تسجيل دخول
        <br /><button className="lbtn" style={{ maxWidth: 260, margin: '14px auto 0' }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>
      </div></section>
    );
  }
  if (state === 'load') return <section className="sect"><div className="noprod"><span className="e">⏳</span>جاري التحميل…</div></section>;
  if (state === 'empty') {
    return (
      <section className="sect"><div className="noprod"><span className="e">🛒</span>سلتك فاضية — أضف منتجات أولاً
        <br /><button className="lbtn" style={{ maxWidth: 260, margin: '14px auto 0' }} onClick={() => nav('/')}>رجوع للتسوق</button></div></section>
    );
  }
  if (done) {
    return (
      <section className="sect"><div className="prof" style={{ maxWidth: 560, textAlign: 'center' }}>
        <div style={{ fontSize: 64, marginBottom: 10 }}>🎉</div>
        <h2>تم استلام طلبك بنجاح!</h2>
        <div className="lnote" style={{ margin: '14px 0' }}>
          أرقام الطلبات: <b>{done.map(c => c.code || c.order?.code).filter(Boolean).join('، ')}</b><br />
          سيتواصل معك المحل أو المندوب لتأكيد التوصيل — الدفع عند الاستلام.
        </div>
        <button className="lbtn" onClick={() => nav('/orders')}>📦 تابع طلباتك</button>
      </div></section>
    );
  }

  const groups = {};
  for (const it of items) (groups[it.store_id] = groups[it.store_id] || { items: [] }).items.push(it);

  const place = async () => {
    if (!f.gov || !f.district || !f.addr) { notify('أكمل المحافظة والمنطقة والعنوان', 'err'); return; }
    const address = `${f.district} — ${f.addr}`;
    try {
      const ctrl = [];
      for (const [sid] of Object.entries(groups)) {
        const d = await api('/api/customer/orders', { method: 'POST', body: JSON.stringify({
          store_id: +sid, address, note: `${f.phone ? '📞 ' + f.phone + ' — ' : ''}${f.note}`, payment_method: 'cod' }) });
        ctrl.push(d.order || d);
      }
      await refreshCart();
      setDone(ctrl);
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <section className="sect" style={{ marginTop: 24 }}>
      <div className="prof" style={{ maxWidth: 640 }}>
        <h2>🚚 إتمام الطلب</h2>
        <div className="lnote" style={{ marginBottom: 14 }}>
          {Object.keys(groups).length} طلب من {Object.keys(groups).length} محل:
          <div style={{ marginTop: 6 }}>
            {Object.values(groups).map((g, i) => (
              <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center', margin: '4px 0' }}>
                <Img src={g.items[0].logo} fontSize="12px" className="lg-t" />
                <b>{g.items[0].store_name}</b> — {g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0) ? fmt(g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0)) : ''}
              </div>
            ))}
          </div>
        </div>
        <div className="lf"><label>المحافظة</label>
          <select value={f.gov} onChange={(e) => setF({ ...f, gov: e.target.value })}>
            <option value="">اختر المحافظة</option>
            {govs.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select></div>
        <div className="lf"><label>القضاء / المنطقة</label>
          <input value={f.district} onChange={(e) => setF({ ...f, district: e.target.value })} placeholder="مثال: مركز الكوت — حي النصر" /></div>
        <div className="lf"><label>العنوان التفصيلي</label>
          <input value={f.addr} onChange={(e) => setF({ ...f, addr: e.target.value })} placeholder="الشارع / محل إرشاد / علامة فارقة" /></div>
        <div className="lf"><label>ملاحظات للمندوب (اختياري)</label>
          <input value={f.note} onChange={(e) => setF({ ...f, note: e.target.value })} placeholder="مثال: اتصل قبل الوصول" /></div>
        <div className="lf"><label>رقم استقبال الطلب</label>
          <input value={f.phone} onChange={(e) => setF({ ...f, phone: e.target.value })} placeholder={(me && me.phone) || '07701234567'} /></div>
        <div className="lnote" style={{ marginBottom: 14 }}>💵 الدفع عند الاستلام — إجمالي المحلات: {fmt(items.reduce((a, b) => a + priceOf(b) * b.qty, 0))}</div>
        <button className="lbtn amber" onClick={place}>✅ تأكيد الطلب</button>
      </div>
    </section>
  );
}