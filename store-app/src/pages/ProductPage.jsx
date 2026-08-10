import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api, fmt, priceOf } from '../api';
import { useApp } from '../ctx';
import { ProductCard } from '../components/Cards';
import { Img, SkeGrid, Empty, Loader } from '../ui';

export default function ProductPage() {
  const { id } = useParams();
  const { addToCart, notify, setCartOpen } = useApp();
  const nav = useNavigate();
  const [p, setP] = useState(null);
  const [similar, setSimilar] = useState(null);
  const [varI, setVarI] = useState(0);
  const [qty, setQty] = useState(1);
  const [busy, setBusy] = useState(false);
  const [qA, setQA] = useState('');
  const [qBusy, setQB] = useState(false);
  const [szOpen, setSzOpen] = useState(false);

  useEffect(() => {
    setP(null); setQty(1); setVarI(0);
    api('/api/products/' + id).then(d => {
      setP(d.product);
      api('/api/products?category_id=' + (d.product.category_id || 0)).then(x => setSimilar((x.products || []).filter(pp => pp.id !== +id).slice(0, 8))).catch(() => {});
    }).catch(() => setP(false));
  }, [id]);

  if (!p) return p === false ? <Empty icon="📦" msg="المنتج غير موجود" action={<button className="btn btn-p" onClick={() => nav('/')}>الرئيسية</button>} /> : <Loader />;
  const vars = p.variants || [];
  const varSel = vars.length ? (vars[varI] && vars[varI].stock > 0 ? vars[varI] : vars.find(v => v.stock > 0) || null) : null;
  const price = priceOf(p);
  const d = p.has_offer ? Math.round(p.offer_percent) : 0;

  const addBtn = async (q, goCart = false) => {
    setBusy(true);
    const ok = await addToCart(p.id, varSel ? varSel.id : null, null, q);
    setBusy(false);
    if (ok && goCart) setCartOpen(true);
  };

  return (
    <div className="sect" style={{ marginTop: 18 }}>
      <div className="breadcrumb">
        <a onClick={() => nav('/')}>زبون</a> <b>&lt;</b> <a onClick={() => nav('/cat/' + p.category_id)}>{p.category_name || 'المنتجات'}</a> <b>&lt;</b> {p.name}
      </div>

      <div className="pd">
        <div className="gallery">
          <div className="main">
            <Img src={p.image} fontSize="110px" />
            {d ? <span className="dc" style={{ position: 'absolute', top: 12, right: 12, fontSize: 13, padding: '6px 13px' }}>-{d}%</span> : null}
          </div>
          <div className="note" style={{ marginTop: 10, textAlign: 'center' }}>المحل: <b style={{ color: 'var(--primary)' }}>{p.store_name}</b> — صور زي الواقع، الألوان تعتمد على شاشة جهازك.</div>
        </div>

        <div className="info">
          <h1>{p.name}</h1>
          <div className="sname" onClick={() => nav('/stores/' + p.store_id)}>🏬 {p.store_name} {p.verified ? '✔' : ''} {p.is_open ? '' : '· مغلق'}</div>
          <div className="prices">
            <b>{fmt(price)}</b>
            {Number(p.old_price) > price ? <s>{fmt(p.old_price)}</s> : null}
            {d ? <span className="dc">خصم -{d}%</span> : null}
          </div>
          <div className="trust">
            <span>🚚 التوصيل: {p.delivery_fee ? fmt(p.delivery_fee) : 'مجاني'}</span>
            <span>💵 الدفع عند الاستلام</span>
            <span>🔁 إرجاع خلال {p.warranty_days || 3} أيام</span>
            <span>⭐ {p.has_offer ? 'من العروض' : 'متوفر'}</span>
          </div>

          {vars.length ? (
            <>
              <div style={{ fontWeight: 800, fontSize: 13, marginBottom: 8, color: 'var(--ink)' }}>
                المقاس / اللون {varSel ? <span style={{ color: 'var(--success)', fontSize: 11.5 }}>(في المخزون: {varSel.stock})</span> : <span style={{ color: 'var(--danger)' }}>— الكل نفد</span>}
              </div>
              <div className="vars">
                {vars.map((v, i) => (
                  <span key={i} className={`var ${v.stock === 0 ? 'off' : i === varI ? 'on' : ''}`} onClick={() => v.stock > 0 && setVarI(i)}>
                    {v.color ? v.color + ' · ' : ''}{v.name}{v.stock === 0 ? ' (نفد)' : v.stock <= 3 ? ` (بقي ${v.stock})` : ''}
                  </span>
                ))}
              </div>
            </>
          ) : null}

          <div className="qty">
            <span style={{ fontWeight: 800, fontSize: 13 }}>الكمية</span>
            <button onClick={() => setQty(Math.max(1, qty - 1))}>−</button><b>{qty}</b>
            <button onClick={() => setQty(qty + 1)}>+</button>
          </div>

          <div className="pd-actions">
            <button className="btn btn-p btn-lg" disabled={busy || !varSel} onClick={() => addBtn(qty)}>🛒 أضف للسلة</button>
            <button className="btn btn-sun btn-lg" disabled={busy || !varSel} onClick={() => addBtn(1, true)}>⚡ اشترِ الآن</button>
          </div>

          {vars.length ? null : (
            <button className="btn btn-p btn-lg btn-block" style={{ marginBottom: 18 }} disabled={busy} onClick={() => addBtn(qty)}>🛒 أضف للسلة — {fmt(price)}</button>
          )}

          {p.description ? <div className="desc">📋 {p.description}</div> : null}

          <div className="card" style={{ padding: 16, marginTop: 14 }}>
            <div style={{ fontWeight: 900, marginBottom: 10, fontSize: 14 }}>❓ عندك سؤال عن هذا المنتج؟</div>
            {qBusy ? <div className="note">جاري الإرسال… سيجيب عليه صاحب المحل قريباً.</div> : (
              <div style={{ display: 'flex', gap: 8 }}>
                <input className="inp" placeholder="مثال: هل معه دليل مقاسات؟" value={qA} onChange={(e) => setQA(e.target.value)} />
                <button className="btn btn-p" disabled={!qA.trim()} onClick={async () => {
                  setQB(true);
                  try { await api('/api/customer/products/' + p.id + '/question', { method: 'POST', body: JSON.stringify({ question: qA }) }); setQA(''); notify('سؤالك انرسل ✓', 'ok'); }
                  catch (e) { notify(e.message, 'err'); } finally { setQB(false); }
                }}>أرسل</button>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="sticky-cta"><div className="in">
        <button className="btn btn-p btn-lg" disabled={busy || !varSel} onClick={() => addBtn(qty)}>🛒 أضف للسلة — {fmt(price)}</button>
        <button className="btn btn-sun btn-lg" disabled={busy || !varSel} onClick={() => addBtn(1, true)}>⚡ اشترِ الآن</button>
      </div></div>

      {similar && similar.length ? (
        <section className="sect">
          <div className="sect-head"><h2><span className="ln" />🔄 منتجات مشابهة</h2></div>
          <div className="grid">{similar.map(pp => <ProductCard key={pp.id} p={pp} />)}</div>
        </section>
      ) : null}
    </div>
  );
}