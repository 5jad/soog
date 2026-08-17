import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, M, useTitle } from '../ui';

export default function CartPage() {
  useTitle('سلة التسوق');
  const { token, cart, setCart, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [coupon, setCoupon] = useState('');
  const [couponInfo, setCouponInfo] = useState(null);
  const [cpErr, setCpErr] = useState('');
  const [cpLoading, setCpLoading] = useState(false);
  const [busy, setBusy] = useState({});

  useEffect(() => { if (!token) setLoginOpen(true); }, []);

  const applyCoupon = async () => {
    if (!coupon.trim()) return;
    setCpLoading(true); setCpErr('');
    try { const d = await api('/api/coupons/apply', { method: 'POST', body: JSON.stringify({ code: coupon.trim() }) }); setCouponInfo(d.coupon || d); }
    catch (e) { setCpErr(e.message); setCouponInfo(null); } finally { setCpLoading(false); }
  };
  const qty = async (id, quantity) => {
    if (quantity < 1) return;
    setBusy(b => ({ ...b, [id]: true }));
    try { await api('/api/cart/update', { method: 'POST', body: JSON.stringify({ product_id: id, quantity }) }); setCart(await api('/api/cart')); }
    catch (e) { notify(e.message, 'err'); } finally { setBusy(b => ({ ...b, [id]: false })); }
  };
  const rm = async (id) => {
    try { await api('/api/cart/remove', { method: 'POST', body: JSON.stringify({ product_id: id }) }); setCart(await api('/api/cart')); }
    catch (e) { notify(e.message, 'err'); }
  };

  if (!cart) return <Loader />;
  if (!cart.items || !cart.items.length) return <Empty icon="🛒" msg="المصطفة فارغة" sub="روّح على المتاجر وضيف منتجات" lottie="/animations/empty_cart.json" action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/stores')}>تصفح المتاجر</button>} />;

  const sub = cart.subtotal || cart.items.reduce((s, i) => s + i.price * i.quantity, 0);
  const disc = (cart.discount || 0) + (cart.coupon_discount || 0);
  const ship = cart.shipping ?? Math.max(0, 2000 - sub);
  const total = Math.max(0, sub - disc) + (ship || 0);
  const needs = cart.needs || Math.max(0, 2000 - sub);

  return (
    <section className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="sect-head">
        <button className="icon-btn" onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={16} w={600} /></button>
        <h2><M n="shopping_cart" s={19} c="var(--primary)" /> سلة التسوق <span className="muted" style={{ fontSize: 12, fontWeight: 700 }}>({cart.items.length})</span></h2>
      </div>

      {needs > 0 ? (
        <div className="threshold">
          <span><M n="local_shipping" s={15} c="var(--primary)" w={600} /> بقي <b>{fmt(needs)}</b> لتوصيل مجاني!</span>
          <div className="cg-bar"><i style={{ width: Math.min(100, (sub / 2000) * 100) + '%' }} /></div>
        </div>
      ) : (
        <div className="note" style={{ marginBottom: 10 }}><M n="local_shipping" s={15} c="var(--success)" w={600} /> تهانينا! توصيلك مجاني تماماً 🎉</div>
      )}

      <div className="cgroup">
        <div className="cgroup-t"><M n="shopping_bag" s={14} c="var(--muted)" /> المصطفة ({cart.items.length})</div>
        {cart.items.map(it => (
          <div key={it.product_id} className="citem">
            {it.images && it.images.length ? <img className="img" src={it.images[0]} alt="" /> : <div className="img"><M n="image" s={18} c="var(--muted)" /></div>}
            <div className="c">
              <div className="nm">{it.name} {it.variant ? <span className="muted" style={{ fontSize: 11, fontWeight: 600 }}>· {it.variant}</span> : null}</div>
              <div className="v">{it.store_name} {it.is_fresh ? '· طازج 🧊' : ''}</div>
              <div className="p"><b>{fmt(it.price)}</b> {it.old_price ? <s>{fmt(it.old_price)}</s> : null}</div>
            </div>
            <div className="qty">
              <button onClick={() => qty(it.product_id, it.quantity - 1)} disabled={busy[it.product_id]}><M n="remove" s={16} w={700} /></button>
              <b>{it.quantity}</b>
              <button onClick={() => qty(it.product_id, it.quantity + 1)} disabled={busy[it.product_id]}><M n="add" s={16} w={700} /></button>
            </div>
            <button className="x" onClick={() => rm(it.product_id)} title="حذف"><M n="close" s={16} /></button>
          </div>
        ))}
      </div>

      <div className="coupon-row card">
        <M n="confirmation_number" s={19} c="var(--accent)" />
        <input className="inp" placeholder="كود الخصم" value={coupon} onChange={(e) => setCoupon(e.target.value)} aria-label="كود الخصم" />
        <button className="btn btn--outline btn--sm" disabled={cpLoading} onClick={applyCoupon}>{cpLoading ? '…' : 'تطبيق'}</button>
        {couponInfo ? <span style={{ color: 'var(--success)', fontSize: 12, fontWeight: 700 }}>✓ {couponInfo.percent ? couponInfo.percent + '%' : fmt(couponInfo.flat)} (كود {couponInfo.code})</span> : null}
        {cpErr ? <span style={{ color: 'var(--danger)', fontSize: 12, fontWeight: 700 }}>{cpErr}</span> : null}
      </div>

      <div className="card tot-row">
        <div><span>المجموع الفرعي</span><b>{fmt(sub)}</b></div>
        {cart.discount ? <div><span>خصم العروض</span><b className="gr">-{fmt(cart.discount)}</b></div> : null}
        {cart.coupon_discount ? <div><span>خصم الكوبون</span><b className="gr">-{fmt(cart.coupon_discount)}</b></div> : null}
        <div><span>التوصيل</span>{ship ? <b>{fmt(ship)}</b> : <b className="gr">مجاني</b>}</div>
        <div className="grand"><span>المجموع</span><b>{fmt(total)}</b></div>
        <button className="btn btn--cta btn--block" onClick={() => nav('/checkout')}><M n="local_shipping" s={18} /> متابعة الشراء</button>
        <button className="btn btn--outline btn--block" style={{ marginTop: 8 }} onClick={() => nav('/stores')}>تصفح المتاجر</button>
      </div>
    </section>
  );
}