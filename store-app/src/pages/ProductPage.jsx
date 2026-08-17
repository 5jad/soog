import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt } from '../api';
import { useApp } from '../ctx';
import { ProductCard } from '../components/Cards';
import { Stars, Loader, SkeGrid, M, useTitle } from '../ui';

export default function ProductPage() {
  const { id } = useParams();
  const { token, notify, setLoginOpen, cart, setCart, setCartOpen } = useApp();
  const nav = useNavigate();
  const [p, setP] = useState(null);
  const [rel, setRel] = useState(null);
  const [v, setV] = useState({});
  const [qty, setQty] = useState(1);
  const [busy, setBusy] = useState(false);
  const [img, setImg] = useState(0);
  useTitle(p ? p.name : 'المنتج', p ? p.store_name : '');

  useEffect(() => {
    api('/api/products/' + id).then(d => { setP(d.product || d); setV(d.product ? d.product.selected_variants || {} : {}); })
      .catch(e => notify(e.message, 'err'));
    api('/api/products?limit=8').then(d => setRel(d.products || [])).catch(() => {});
  }, [id]);

  if (!p) return <Loader />;

  const imgs = (p.images && p.images.length ? p.images : p.image ? [p.image] : []);
  const add = async (go) => {
    if (!token) { setLoginOpen(true); return; }
    if (p.variants && p.variants.length && Object.keys(v).length < p.variants.length) { notify('اختر ' + p.variants.map(x => x.name).join(' و ') + ' أولاً', 'err'); return; }
    setBusy(true);
    try { await api('/api/cart/add', { method: 'POST', body: JSON.stringify({ product_id: p.id, quantity: qty, variants: v }) }); setCart(await api('/api/cart')); notify('انضاف للمصطفة 🛒', 'ok'); if (go) setCartOpen(true); }
    catch (e) { notify(e.message, 'err'); } finally { setBusy(false); }
  };

  return (
    <section className="container section pd" style={{ paddingBlockStart: 12 }}>
      <div className="crumb">
        <a onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={14} w={600} /> رجوع</a>
        <span className="sep">/</span>
        <a onClick={() => nav('/stores/' + p.store_id)}>{p.store_name}</a>
      </div>

      <div className="pd-gallery">
        {imgs.length ? <img src={imgs[Math.min(img, imgs.length - 1)]} alt={p.name} />
          : <div style={{ aspectRatio: 1, display: 'grid', placeItems: 'center' }}><M n="image_not_supported" s={70} c="var(--primary)" /></div>}
        {p.has_offer ? <span className="pcard-off" style={{ position: 'absolute' }}>{p.offer_percent}%</span> : null}
        {!p.available ? <span className="pcard-tag" style={{ position: 'absolute' }}>نفد</span> : null}
        {imgs.length > 1 && (
          <div className="pd-dots">
            {imgs.map((_, i) => <i key={i} className={img === i ? 'on' : ''} onClick={() => setImg(i)} style={{ cursor: 'pointer' }} />)}
          </div>
        )}
      </div>

      <div className="pd-info">
        <button className="pd-store" onClick={() => nav('/stores/' + p.store_id)}>
          <M n="storefront" s={15} w={600} /> {p.store_name} <M n="chevron_left" s={16} c="var(--muted)" />
        </button>
        <h1 className="pd-name">{p.name}</h1>
        {p.subtitle ? <div className="muted" style={{ fontSize: 13 }}>{p.subtitle}</div> : null}
        <div className="pd-sr">
          <Stars n={p.rating} size={16} />
          <span className="muted" style={{ fontSize: 13, fontWeight: 700 }}>{p.reviews_count || 0} تقييم</span>
        </div>

        <div className="pd-old-row">
          <span className="pd-price">{fmt(p.price)}</span>
          {p.old_price ? <s className="pd-old">{fmt(p.old_price)}</s> : null}
          {p.has_offer ? <span className="pd-save">وفّرت {fmt(p.old_price ? p.old_price - p.price : p.price * p.offer_percent / 100)}</span> : null}
        </div>
        {p.available === false
          ? <span className="pd-stock bad">نفد هذا المنتج حالياً</span>
          : p.stock != null && p.stock <= 5 ? <span className="pd-stock bad">باقي {p.stock} فقط</span> : null}

        {p.variants && p.variants.map((gr, gi) => (
          <div key={gi}>
            <div className="flt-lbl">{gr.name}</div>
            <div className="vars">
              {gr.values.map(val => (
                <span key={val} className={`var ${v[gr.name] === val ? 'on' : ''}`} onClick={() => setV({ ...v, [gr.name]: val })}>
                  {gr.type === 'color' && (gr.hex && gr.hex[val]) ? <i className="dot" style={{ background: gr.hex[val] }} /> : null}{val}
                </span>
              ))}
            </div>
          </div>
        ))}

        <div className="rowf" style={{ gap: 12, alignItems: 'center' }}>
          <div className="qty">
            <button onClick={() => setQty(Math.max(1, qty - 1))} disabled={qty <= 1}><M n="remove" s={17} w={700} /></button>
            <b>{qty}</b>
            <button onClick={() => setQty(qty + 1)}><M n="add" s={17} w={700} /></button>
          </div>
          <div className="pd-actions">
            <button className="btn btn--cta" disabled={busy} onClick={() => add(false)}>{busy ? <M n="progress_activity" cls="spin" s={18} /> : <M n="shopping_cart_checkout" s={18} />} أضف للمصطفة</button>
            <button className="btn btn--navy" disabled={busy} onClick={() => add(true)}>اشترِ الآن</button>
          </div>
        </div>

        <div className="serv card">
          <div><M n="verified_user" s={19} c="var(--success)" /><div className="t">ضمان {p.warranty_days ?? 3} يوم</div></div>
          <div><M n="autorenew" s={19} c="var(--primary)" /><div className="t">استبدال سهل</div></div>
          <div><M n="paid" s={19} c="var(--accent)" /><div className="t">دفع عند الاستلام</div></div>
          <div><M n="local_shipping" s={19} c="var(--cyan)" /><div className="t">توصيل سريع</div></div>
        </div>

        {p.desc ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div className="card-h">الوصف</div>
            <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.9, color: 'var(--ink)' }}>{p.desc}</p>
          </div>
        ) : null}
      </div>

      {rel && rel.length ? (
        <div>
          <div className="sect-head"><h2><M n="local_offer" s={18} c="var(--primary)" w={700} /> منتجات مشابهة</h2></div>
          <div className="grid-products">{rel.map(x => <ProductCard key={x.id} p={x} />)}</div>
        </div>
      ) : null}
    </section>
  );
}