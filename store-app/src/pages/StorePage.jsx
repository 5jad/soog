import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt, priceOf } from '../api';
import { useApp } from '../ctx';
import { ProductCard, DealCard, CatIcon } from '../components/Cards';
import { Stars, SkeGrid, Empty, Loader, Img } from '../ui';

export default function StorePage() {
  const { id } = useParams();
  const { token, notify, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [st, setSt] = useState(null);
  const [prods, setProds] = useState(null);
  const [reviews, setReviews] = useState([]);
  const [breakdown, setBreakdown] = useState({});
  const [coupons, setCoupons] = useState([]);
  const [cats, setCats] = useState([]);
  const [catSel, setCatSel] = useState(null);
  const [q, setQ] = useState('');
  const [followed, setFollowed] = useState(false);
  const [busyF, setBusyF] = useState(false);
  const [tab, setTab] = useState('prods');

  useEffect(() => {
    setSt(null); setProds(null);
    Promise.all([api('/api/stores/' + id), api('/api/products?store_id=' + id), api('/api/categories')])
      .then(([sd, pd, cd]) => {
        setSt(sd.store || sd);
        setProds(pd.products || []);
        setReviews(sd.reviews || []);
        setBreakdown(sd.rating_breakdown || {});
        setCoupons(sd.coupons || []);
        setCats(cd.categories || []);
      }).catch(() => {});
    if (token) api('/api/customer/store-favorites').then(d => setFollowed((d.favorites || []).some(f => f.store_id === +id))).catch(() => {});
  }, [id]);

  if (!st) return <Loader />;
  const open = st.is_open && !st.on_vacation;
  const showProds = (prods || []).filter(p => (!catSel || p.category_id === catSel) && (!q.trim() || p.name.includes(q.trim())));
  const bestDeals = (prods || []).filter(p => p.has_offer);

  const toggleFollow = async () => {
    if (!token) { setLoginOpen(true); return; }
    setBusyF(true);
    try { const d = await api('/api/customer/store-favorites', { method: 'POST', body: JSON.stringify({ store_id: st.id }) }); setFollowed(d.favorite); notify(d.favorite ? 'تتابع المحل الآن ❤️' : 'ألغيت المتابعة', 'ok'); }
    catch (e) { notify(e.message, 'err'); } finally { setBusyF(false); }
  };

  return (
    <div className="sect" style={{ marginTop: 18 }}>
      <div className="breadcrumb"><a onClick={() => nav('/')}>زبون</a> <b>&lt;</b> <a onClick={() => nav('/stores')}>المتاجر</a> <b>&lt;</b> {st.name}</div>
      <div className="store-hero">
        <div className="logo"><Img src={st.logo} fontSize="38px" /></div>
        <div style={{ flex: 1 }}>
          <h1>{st.name} {st.verified ? '✔' : ''}</h1>
          <div className="meta">{st.category_name || ''}{st.governorate_name ? ' · ' + st.governorate_name : ''}{st.district_name ? ' — ' + st.district_name : ''}</div>
          <div className="meta" style={{ display: 'flex', alignItems: 'center', gap: 6 }}><Stars n={st.rating} size={13} /> {st.rating || '5.0'} ({st.reviews_count || 0})</div>
          <div className="badges">
            {open ? <span>🟢 مفتوح</span> : <span>🔴 مغلق{st.on_vacation ? ' — إجازة' : ''}</span>}
            <span>🚚 {st.delivery_fee ? 'توصيل ' + fmt(st.delivery_fee) : 'توصيل مجاني'}</span>
            {st.free_delivery_min ? <span>مجاني فوق {fmt(st.free_delivery_min)}</span> : null}
            {st.phone ? <span>📞 {st.phone}</span> : null}
          </div>
        </div>
        <button className={`btn ${followed ? 'btn-o' : ''}`} style={{ background: followed ? '#fff' : 'rgba(255,255,255,.92)', color: followed ? 'var(--primary)' : 'var(--primary-deep)', borderRadius: 999 }} disabled={busyF} onClick={toggleFollow}>
          {followed ? '❤️ تتبعه' : '🤍 متابعة'}
        </button>
      </div>

      {coupons.length ? (
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 14 }}>
          {coupons.map(c => (
            <div key={c.id} className="card" style={{ padding: '9px 14px', fontSize: 12, fontWeight: 800, color: 'var(--primary)', borderStyle: 'dashed' }}>
              🎟️ {c.code} — {c.percent ? c.percent + '%' : fmt(c.flat)}{c.min_total ? ` (من ${fmt(c.min_total)})` : ''}
            </div>
          ))}
        </div>
      ) : null}

      <div className="tabs" style={{ maxWidth: 420, marginBottom: 16 }}>
        {[['prods', '🛍️ المنتجات'], ['deals', '🔥 العروض'], ['reviews', '⭐ التقييمات']].map(([k, t]) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>{t}</button>
        ))}
      </div>

      {tab !== 'reviews' && (
        <div style={{ display: 'flex', gap: 10, marginBottom: 14, flexWrap: 'wrap', alignItems: 'center' }}>
          <input className="inp" style={{ maxWidth: 280 }} placeholder="ابحث داخل المحل…" value={q} onChange={(e) => setQ(e.target.value)} />
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <span className={`chip ${!catSel ? 'on' : ''}`} onClick={() => setCatSel(null)}>الكل</span>
            {cats.filter(c => prods && prods.some(p => p.category_id === c.id)).map(c => (
              <span key={c.id} className={`chip ${catSel === c.id ? 'on' : ''}`} onClick={() => setCatSel(c.id)}>{c.icon || ''} {c.name}</span>
            ))}
          </div>
        </div>
      )}

      {tab === 'prods' && (showProds.length ? <div className="grid">{showProds.map(p => <ProductCard key={p.id} p={p} />)}</div> : <Empty icon="📭" msg="ماكو منتجات مطابقة" />)}
      {tab === 'deals' && (bestDeals.length ? <div className="grid">{bestDeals.map(p => <ProductCard key={p.id} p={p} fire />)}</div> : <Empty icon="🔥" msg="ماكو عروض حالياً" />)}
      {tab === 'reviews' && (
        <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap' }}>
          <div className="card" style={{ padding: 18, minWidth: 220 }}>
            <div style={{ fontSize: 34, fontWeight: 900, color: 'var(--ink)' }}>{st.rating || '5.0'} <span style={{ fontSize: 15, color: 'var(--muted)', fontWeight: 700 }}>/ 5</span></div>
            <Stars n={st.rating} size={18} />
            <div style={{ marginTop: 10 }}>
              {[5, 4, 3, 2, 1].map(n => (
                <div key={n} className="rat-row" style={{ margin: '4px 0' }}>
                  <span style={{ fontWeight: 800, fontSize: 11.5, width: 30 }}>{n} ★</span>
                  <span className="rat-bar"><i style={{ width: (breakdown[n] || 0) * 8 + '%' }} /></span>
                  <span style={{ fontSize: 11 }}>{breakdown[n] || 0}</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ flex: 1, minWidth: 260 }}>
            {reviews.length ? reviews.map((r, i) => (
              <div key={i} className="review">
                <div className="top"><span className="nm">👤 {r.user_name}</span><span className="dt">{r.created_at ? new Date(r.created_at).toLocaleDateString('ar-IQ') : ''}</span></div>
                <Stars n={r.rating} size={13} />
                {r.comment ? <div style={{ fontSize: 12.5, color: 'var(--text)', marginTop: 6 }}>{r.comment}</div> : null}
              </div>
            )) : <Empty icon="⭐" msg="ماكو تقييمات بعد — كن أول من يقيّم!" />}
          </div>
        </div>
      )}
    </div>
  );
}