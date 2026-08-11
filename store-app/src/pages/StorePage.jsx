import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt, U } from '../api';
import { useApp } from '../ctx';
import { ProductCard } from '../components/Cards';
import { Stars, SkeGrid, Empty, Loader, M, useTitle } from '../ui';

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
  useTitle(st ? st.name : 'المتجر', 'متجر على زبون');

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
    <div className="pg">
      <div className="crumb">
        <a onClick={() => nav('/')}>الرئيسية</a>
        <span className="sep">/</span>
        <a onClick={() => nav('/stores')}>المتاجر</a>
        <span className="sep">/</span>
        <span className="cur">{st.name}</span>
      </div>
      {/* هيرو المتجر — غلاف يملأ الأعلى */}
      <div className="st-hero">
        {U(st.cover) ? <img className="bg" src={st.cover} alt="" /> : <div className="bg" style={{ background: 'linear-gradient(135deg,#0B1B36,#12294E,#1789A6)' }} />}
        <div className="ov" />
        <div className="st-hero-in">
          <div className="st-htop">
            <button className="i-btn" onClick={() => nav(-1)} style={{ background: 'rgba(255,255,255,.16)', border: '1px solid rgba(255,255,255,.35)', color: '#fff' }}><M n="arrow_back_ios_new" s={17} w={600} /></button>
            <div className="st-cs">
              {open
                ? <span className="cv"><M n="check_circle" s={13} fill c="#4ADE80" w={700} />{st.on_vacation ? 'ويا إجازة' : 'مفتوح'}</span>
                : <span className="cv"><M n="cancel" s={13} c="var(--danger)" fill w={700} />مغلق{st.on_vacation ? ' — إجازة' : ''}</span>}
              <span className="cv"><M n="verified_user" s={13} c="#4ADE80" fill w={700} />ضمان {st.warranty_days ?? 3} يوم</span>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div className="st-logo">{U(st.logo) ? <img src={st.logo} alt="" /> : (st.logo || '🏪')}</div>
            <div>
              <div className="st-sn">{st.name} {st.verified ? <M n="verified" s={17} fill c="#4A6FA5" w={700} /> : null}</div>
              <div className="st-sr">
                <M n="star" fill s={14} c="var(--star)" w={700} />
                <b>{Number(st.rating || 0) > 0 ? Number(st.rating).toFixed(1) : 'جديد'}</b>
                <span>· {st.reviews_count || 0} تقييم</span>
                {st.governorate_name ? <span>· {st.governorate_name}{st.district_name ? ' — ' + st.district_name : ''}</span> : null}
              </div>
            </div>
          </div>
          <div className="st-acts">
            {st.delivery_fee != null ? <span className="st-act" style={{ cursor: 'default' }}><M n="delivery_dining" s={16} w={600} />{st.delivery_fee ? fmt(st.delivery_fee) : 'مجاني'}</span> : null}
            {st.free_delivery_min ? <span className="st-act" style={{ cursor: 'default' }}><M n="card_giftcard" s={16} w={600} />مجاني فوق {fmt(st.free_delivery_min)}</span> : null}
            {st.open_time ? <span className="st-act" style={{ cursor: 'default' }}><M n="storefront" s={16} w={600} />{st.open_time} - {st.close_time}</span> : null}
            {st.phone ? <a className="st-act" href={'tel:' + st.phone}><M n="call" s={16} w={600} />اتصال</a> : null}
            {st.location_url ? <a className="st-act" href={st.location_url} target="_blank" rel="noreferrer"><M n="map" s={16} w={600} />الموقع</a> : null}
            <button className={`st-act ${followed ? 'on' : ''}`} disabled={busyF} onClick={toggleFollow}>
              <M n="favorite" fill={followed} s={16} w={600} />{followed ? 'متابع' : 'متابعة'}
            </button>
          </div>
        </div>
      </div>

      <div className="sect" style={{ paddingTop: 16 }}>
        {/* كوبونات المتجر */}
        {coupons.length ? (
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 12 }}>
            {coupons.map(c => (
              <div key={c.id} className="st-coupon" style={{ color: 'var(--ink)', background: 'rgba(245,166,35,.08)', borderColor: 'rgba(245,166,35,.5)' }}>
                <M n="confirmation_number" s={16} c="var(--accent)" w={600} />
                <span className="cd2">{c.code}</span> — {c.percent ? c.percent + '%' : fmt(c.flat)}{c.min_total ? ` (من ${fmt(c.min_total)})` : ''}
              </div>
            ))}
          </div>
        ) : null}

        <div className="tabs" style={{ maxWidth: 440, marginBottom: 14 }}>
          {[['prods', 'المنتجات', 'grid_view'], ['deals', 'العروض', 'local_fire_department'], ['reviews', 'التقييمات', 'star']].map(([k, t, ic]) => (
            <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>
              <M n={ic} s={15} w={700} /> {t}
            </button>
          ))}
        </div>

        {tab !== 'reviews' && (
          <div className="search-row" style={{ marginBottom: 10 }}>
            <div className="search-f">
              <span className="go" style={{ background: 'none', border: 0, color: 'var(--muted)', padding: '0 8px' }}><M n="search" s={20} w={500} /></span>
              <input placeholder="ابحث داخل المحل…" value={q} onChange={(e) => setQ(e.target.value)} />
              {q ? <button className="clr" onClick={() => setQ('')}><M n="close" s={19} w={500} /></button> : null}
            </div>
          </div>
        )}
        {tab !== 'reviews' && (
          <div className="cats-row" style={{ paddingInline: 0 }}>
            <span className={`chipg ${!catSel ? 'on' : ''}`} onClick={() => setCatSel(null)}>الكل</span>
            {cats.filter(c => prods && prods.some(p => p.category_id === c.id)).map(c => (
              <span key={c.id} className={`chipg ${catSel === c.id ? 'on' : ''}`} onClick={() => setCatSel(c.id)}>{c.icon || ''} {c.name}</span>
            ))}
          </div>
        )}

        {tab === 'prods' && (prods === null ? <SkeGrid n={6} /> : showProds.length ? <div className="grid" style={{ paddingInline: 0, marginTop: 10 }}>{showProds.map(p => <ProductCard key={p.id} p={p} />)}</div> : <Empty icon="📭" msg="ماكو منتجات مطابقة" />)}
        {tab === 'deals' && (bestDeals.length ? <div className="grid" style={{ paddingInline: 0, marginTop: 10 }}>{bestDeals.map(p => <ProductCard key={p.id} p={p} />)}</div> : <Empty icon="🔥" msg="ماكو عروض حالياً" />)}
        {tab === 'reviews' && (
          <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
            <div className="card" style={{ padding: 18, minWidth: 220 }}>
              <div style={{ fontSize: 34, fontWeight: 900, color: 'var(--ink)' }}>{Number(st.rating || 0) > 0 ? Number(st.rating).toFixed(1) : '5.0'} <span style={{ fontSize: 15, color: 'var(--muted)', fontWeight: 700 }}>/ 5</span></div>
              <Stars n={st.rating} size={18} />
              <div style={{ marginTop: 10 }}>
                {[5, 4, 3, 2, 1].map(n => (
                  <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '5px 0' }}>
                    <span style={{ fontWeight: 800, fontSize: 11.5, width: 26 }}>{n} <M n="star" fill s={11} c="var(--star)" w={700} /></span>
                    <span className="cg-bar" style={{ flex: 1, margin: 0 }}><i style={{ width: Math.min(100, (breakdown[n] || 0) * 8) + '%' }} /></span>
                    <span style={{ fontSize: 11, color: 'var(--muted)' }}>{breakdown[n] || 0}</span>
                  </div>
                ))}
              </div>
            </div>
            <div style={{ flex: 1, minWidth: 260 }}>
              {reviews.length ? reviews.map((r, i) => (
                <div key={i} className="rv">
                  <div className="rvn"><M n="person" s={14} c="var(--muted)" w={600} /> {r.user_name}</div>
                  <Stars n={r.rating} size={13} />
                  {r.comment ? <div style={{ fontSize: 12.5, color: 'var(--text)', marginTop: 4, lineHeight: 1.7 }}>{r.comment}</div> : null}
                  <div className="rvd">{r.created_at ? new Date(r.created_at).toLocaleDateString('ar-IQ') : ''}</div>
                </div>
              )) : <Empty icon="⭐" msg="ماكو تقييمات بعد — كن أول من يقيّم!" />}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}