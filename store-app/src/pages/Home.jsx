import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { Loader, Empty, M, useTitle } from '../ui';
import Promo from '../components/Promo';
import { ProductCard, StoreCard, DealCard, CatIcon, DOT } from '../components/Cards';

const COVERS = ['linear-gradient(135deg,#1D4ED8,#38BDF8)', 'linear-gradient(135deg,#F97316,#FB923C)', 'linear-gradient(135deg,#15803D,#4ADE80)', 'linear-gradient(135deg,#B45309,#F59E0B)'];
const SORTS = [['newest', 'الأحدث'], ['best', 'الأفضل تقييماً'], ['discount', 'الأكثر خصماً'], ['price_asc', 'السعر: من الأقل'], ['price_desc', 'السعر: من الأعلى']];

export default function Home() {
  useTitle('الرئيسية', 'زبون — تسوق من متاجر الكوت');
  const nav = useNavigate();
  const [loading, setLoading] = useState(true);
  const [ads, setAds] = useState([]);
  const [stores, setStores] = useState([]);
  const [offers, setOffers] = useState([]);
  const [cats, setCats] = useState([]);
  const [best, setBest] = useState([]);
  const [catProds, setCatProds] = useState({});
  const [expCat, setExpCat] = useState(null);
  const [expBest, setExpBest] = useState(false);

  /* الفلترة داخل الرئيسية مثل التطبيق */
  const [q, setQ] = useState('');
  const [selCat, setSelCat] = useState({});
  const [sort, setSort] = useState('newest');
  const [minP, setMinP] = useState('');
  const [maxP, setMaxP] = useState('');
  const [selColors, setSelColors] = useState([]);
  const [selSizes, setSelSizes] = useState([]);
  const [offerOnly, setOfferOnly] = useState(false);
  const [metaColors, setMetaColors] = useState([]);
  const [metaSizes, setMetaSizes] = useState([]);
  const [gridP, setGridP] = useState([]);
  const [gridLoading, setGridLoading] = useState(false);
  const [fltOpen, setFltOpen] = useState(false);

  const hasFilters = sort !== 'newest' || minP || maxP || selColors.length || selSizes.length || offerOnly;
  const gridMode = selCat.id || q || hasFilters;

  const load = () => {
    Promise.all([
      api('/api/stores'), api('/api/ads'), api('/api/offers'), api('/api/categories'), api('/api/products?best=true'),
    ]).then(async ([d1, d2, d3, d4, d5]) => {
      setStores(d1.stores || []);
      setAds(d2.ads || []);
      setOffers(d3.offers || []);
      setCats(d4.categories || []);
      setBest(d5.products || []);
      const map = {};
      await Promise.all((d4.categories || []).map(async (c) => {
        try { const d = await api('/api/products?category_id=' + c.id); map[c.id] = d.products || []; } catch (e) { map[c.id] = []; }
      }));
      setCatProds(map);
    }).catch(() => {}).finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, []);

  const loadGrid = () => {
    setGridLoading(true);
    const qs = [];
    if (selCat.id) {
      qs.push('category_id=' + selCat.id);
      if (!metaColors.length || !metaSizes.length) api('/api/products/meta?category_id=' + selCat.id).then(d => { setMetaColors(d.colors || []); setMetaSizes(d.sizes || []); }).catch(() => {});
    } else { setMetaColors([]); setMetaSizes([]); }
    if (q) qs.push('q=' + encodeURIComponent(q));
    if (sort !== 'newest') qs.push('sort=' + sort);
    if (minP) qs.push('min_price=' + minP);
    if (maxP) qs.push('max_price=' + maxP);
    if (selColors.length) qs.push('colors=' + selColors.join(','));
    if (selSizes.length) qs.push('sizes=' + selSizes.join(','));
    if (offerOnly) qs.push('offer=true');
    api('/api/products?' + qs.join('&')).then(d => setGridP(d.products || [])).catch(() => setGridP([])).finally(() => setGridLoading(false));
  };

  const pickCat = (c) => {
    const next = selCat.id === c.id ? {} : c;
    setSelCat(next);
    setSort('newest'); setMinP(''); setMaxP(''); setSelColors([]); setSelSizes([]); setOfferOnly(false); setMetaColors([]); setMetaSizes([]);
    if (next.id) loadGridNow(next, q);
    else if (q || hasFilters2()) {}
    else setGridP([]);
  };
  const hasFilters2 = () => false;

  const loadGridNow = (cat, query) => {
    setGridLoading(true);
    const qs = [];
    if (cat.id) qs.push('category_id=' + cat.id);
    if (query) qs.push('q=' + encodeURIComponent(query));
    if (sort !== 'newest') qs.push('sort=' + sort);
    if (minP) qs.push('min_price=' + minP);
    if (maxP) qs.push('max_price=' + maxP);
    if (selColors.length) qs.push('colors=' + selColors.join(','));
    if (selSizes.length) qs.push('sizes=' + selSizes.join(','));
    if (offerOnly) qs.push('offer=true');
    api('/api/products?' + qs.join('&')).then(d => setGridP(d.products || [])).catch(() => setGridP([])).finally(() => setGridLoading(false));
  };

  const search = (e) => { e.preventDefault(); setSelCat({}); setQ2(q); };
  const setQ2 = (v) => {
    if (!v) { setGridP([]); return; }
    setGridLoading(true);
    api('/api/products?q=' + encodeURIComponent(v)).then(d => setGridP(d.products || [])).catch(() => setGridP([])).finally(() => setGridLoading(false));
  };

  const applyFlt = () => { loadGrid(); setFltOpen(false); };
  const clearAll = () => { setSort('newest'); setMinP(''); setMaxP(''); setSelColors([]); setSelSizes([]); setOfferOnly(false); setMetaColors([]); setMetaSizes([]); };

  const fCount = (sort !== 'newest' ? 1 : 0) + (minP || maxP ? 1 : 0) + selColors.length + selSizes.length + (offerOnly ? 1 : 0);
  const sortLabel = (SORTS.find(s => s[0] === sort) || SORTS[0])[1];

  /* شريط منتجات: صفحة = عمودان × صفّان */
  const strip2 = (list, h) => {
    const rows = Math.ceil(list.length / 2);
    const pages = Math.ceil(rows / 2);
    return (
      <div className="strip" style={{ height: h }}>
        {Array.from({ length: pages }).map((_, pi) => (
          <div key={pi} className="s2p">
            {[0, 1].map(r => list[pi * 4 + r * 2] ? (
              <div key={r} className="s2r">
                <ProductCard p={list[pi * 4 + r * 2]} />
                {list[pi * 4 + r * 2 + 1] ? <ProductCard p={list[pi * 4 + r * 2 + 1]} /> : null}
              </div>
            ) : null)}
          </div>
        ))}
      </div>
    );
  };

  const gridX = (list) => (
    <div className="grid">{list.map(p => <ProductCard key={p.id} p={p} />)}</div>
  );

  if (loading) return <div className="sect"><Loader /></div>;

  return (
    <div className="sect" style={{ paddingTop: 12 }}>
      {/* البحث + الفلتر */}
      <form className="search-row" onSubmit={search}>
        <div className="search-f">
          <button type="submit" className="go"><M n="search" s={20} w={600} /></button>
          <input value={q} onChange={(e) => { setQ(e.target.value); }} placeholder="ابحث عن قميص، فستان، شنطة، مكياج... 🔍" />
          {q ? <button type="button" className="clr" onClick={() => setQ('')}><M n="close" s={19} w={500} /></button> : null}
        </div>
        <button type="button" className={`flt-btn ${hasFilters ? 'on' : ''}`} onClick={() => setFltOpen(true)}>
          <M n="tune" s={22} w={600} />
          {hasFilters ? <span className="fb">{fCount}</span> : null}
        </button>
      </form>

      {/* شرائح الفئات */}
      {cats.length ? (
        <div className="cats-row" style={{ paddingTop: 12 }}>
          {cats.map(c => (
            <CatIcon key={c.id} c={c} on={selCat.id === c.id} onClick={() => pickCat(c)} />
          ))}
        </div>
      ) : null}

      {/* الهيرو */}
      <Promo ads={ads} stores={stores} />

      {/* شريط الثقة */}
      <div className="trust-row">
        <div className="trust-i"><span className="trust-ic"><M n="rocket_launch" s={16} w={700} /></span>توصيل سريع</div>
        <div className="trust-i"><span className="trust-ic"><M n="payments" s={16} w={700} /></span>الدفع عند الاستلام</div>
        <div className="trust-i"><span className="trust-ic"><M n="swap_horiz" s={16} w={700} /></span>استبدال خلال 5 أيام</div>
      </div>

      {/* العروض */}
      {offers.length && !gridMode ? (
        <>
          <div className="sst"><span className="sst-t">⚡ عروض اليوم</span></div>
          <div className="strip" style={{ height: 196, paddingTop: 10 }}>
            {offers.map((o, i) => <DealCard key={i} d={o} />)}
          </div>
        </>
      ) : null}

      {/* المحلات المميزة */}
      {stores.length && !gridMode ? (
        <>
          <div className="sst"><span className="sst-t">محلات مميزة</span></div>
          <div className="strip" style={{ height: 128, paddingTop: 12 }}>
            {stores.map((s, i) => <StoreCard key={s.id} s={s} cover={COVERS[i % 4]} />)}
          </div>
        </>
      ) : null}

      {/* وضع الشبكة: بحث/فئة/فلاتر */}
      {gridMode ? (
        <>
          <div className="sst">
            <span className="sst-t">{q ? `نتائج البحث عن «${q}»` : selCat.id ? `${selCat.icon || ''} ${selCat.name}` : 'المنتجات'}</span>
          </div>
          {hasFilters ? (
            <div className="fatto-row">
              {sort !== 'newest' ? <span className="fatto" onClick={() => { setSort('newest'); loadGrid(); }}>{sortLabel}<M n="close" s={13} w={700} /></span> : null}
              {(minP || maxP) ? <span className="fatto" onClick={() => { setMinP(''); setMaxP(''); loadGrid(); }}>سعر: {minP || 0}-{maxP || '∞'}<M n="close" s={13} w={700} /></span> : null}
              {selColors.map(c => <span key={c} className="fatto" onClick={() => { setSelColors(selColors.filter(x => x !== c)); loadGrid(); }}>لون: {c}<M n="close" s={13} w={700} /></span>)}
              {selSizes.map(s => <span key={s} className="fatto" onClick={() => { setSelSizes(selSizes.filter(x => x !== s)); loadGrid(); }}>مقاس: {s}<M n="close" s={13} w={700} /></span>)}
              {offerOnly ? <span className="fatto" onClick={() => { setOfferOnly(false); loadGrid(); }}>عروض فقط<M n="close" s={13} w={700} /></span> : null}
              <span className="fatto err" onClick={clearAll}>مسح الكل</span>
            </div>
          ) : null}
          {gridLoading ? <Loader /> : gridP.length ? gridX(gridP) : <Empty icon="📦" msg="ماكو منتجات مطابقة" sub="جرب كلمة أو فلترة أخرى" />}
        </>
      ) : (
        <>
          {/* الأكثر مبيعاً + عرض الكل */}
          {best.length ? (
            <>
              <div className="sst">
                <span className="sst-t">🔥 الأكثر مبيعاً</span>
                <span className={`seeall ${expBest ? 'on' : ''}`} onClick={() => setExpBest(!expBest)}>
                  {expBest ? 'عرض أقل' : 'عرض الكل'}<M n={expBest ? 'keyboard_arrow_up' : 'keyboard_arrow_down'} s={15} w={700} />
                </span>
              </div>
              {expBest ? <div style={{ marginTop: 8 }}>{gridX(best)}</div> : <div className="g2">{strip2(best, 640)}</div>}
            </>
          ) : null}
          {/* أشرطة الفئات + عرض الكل */}
          {cats.map(c => (catProds[c.id] || []).length ? (
            <div key={c.id}>
              <div className="sst">
                <span className="sst-t">{c.icon || '🛍️'} {c.name}</span>
                <span className={`seeall ${expCat && expCat.id === c.id ? 'on' : ''}`} onClick={() => setExpCat(expCat && expCat.id === c.id ? null : c)}>
                  {expCat && expCat.id === c.id ? 'عرض أقل' : 'عرض الكل'}<M n={expCat && expCat.id === c.id ? 'keyboard_arrow_up' : 'keyboard_arrow_down'} s={15} w={700} />
                </span>
              </div>
              {expCat && expCat.id === c.id ? <div style={{ marginTop: 8 }}>{gridX(catProds[c.id])}</div> : <div className="g2">{strip2(catProds[c.id], 640)}</div>}
            </div>
          ) : null)}
        </>
      )}

      {/* شيت الفلترة */}
      {fltOpen ? (
        <>
          <div className="overlay" style={{ zIndex: 105 }} onClick={() => setFltOpen(false)} />
          <div style={{ position: 'fixed', inset: 0, zIndex: 105, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', pointerEvents: 'none' }}>
            <div className="sheet" style={{ pointerEvents: 'auto', width: 'min(560px,100vw)', maxHeight: '88vh' }}>
              <div className="flt-hd">
                <span className="flt-t">الفلترة</span>
                <button className="flt-clear" onClick={() => { clearAll(); }}>مسح الكل</button>
                <button className="i-btn" onClick={() => setFltOpen(false)} style={{ marginInlineStart: 4 }}><M n="close" s={20} /></button>
              </div>
              <div className="flt-lbl">الترتيب</div>
              <div className="flt-wrap">
                {SORTS.map(([v, l]) => (
                  <span key={v} className={`chipf ${sort === v ? 'on' : ''}`} onClick={() => setSort(v)}>{l}</span>
                ))}
              </div>
              <div className="flt-lbl">السعر (د.ع)</div>
              <div className="flt-price">
                <input className="inp" type="number" placeholder="من" value={minP} onChange={(e) => setMinP(e.target.value)} />
                <span style={{ color: 'var(--muted)', fontSize: 14 }}>—</span>
                <input className="inp" type="number" placeholder="إلى" value={maxP} onChange={(e) => setMaxP(e.target.value)} />
              </div>
              {metaColors.length ? (
                <>
                  <div className="flt-lbl">اللون</div>
                  <div className="flt-wrap">
                    {metaColors.map(c => (
                      <span key={c} className={`chipf ${selColors.includes(c) ? 'on' : ''}`} onClick={() => setSelColors(selColors.includes(c) ? selColors.filter(x => x !== c) : [...selColors, c])}>
                        <span className="cd" style={{ background: DOT(c) }} />{c}
                      </span>
                    ))}
                  </div>
                </>
              ) : null}
              {metaSizes.length ? (
                <>
                  <div className="flt-lbl">المقاس</div>
                  <div className="flt-wrap">
                    {metaSizes.map(s => (
                      <span key={s} className={`chipf chipsq ${selSizes.includes(s) ? 'on' : ''}`} onClick={() => setSelSizes(selSizes.includes(s) ? selSizes.filter(x => x !== s) : [...selSizes, s])}>{s}</span>
                    ))}
                  </div>
                </>
              ) : null}
              <div className="flt-off">
                <M n="local_fire_department" s={19} c="var(--accent)" w={700} />
                <span>العروض والخصومات فقط</span>
                <button className={`switch ${offerOnly ? 'on' : ''}`} onClick={() => setOfferOnly(!offerOnly)} />
              </div>
              <button className="btn btn-lg btn-block" style={{ marginTop: 16 }} onClick={applyFlt}>عرض النتائج</button>
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}