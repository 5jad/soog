import React, { useEffect, useState } from 'react';
import { useSearchParams, useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { ProductCard } from '../components/Cards';
import { SkeGrid, Empty, M, useTitle } from '../ui';

const SORTS = [['all', 'الكل'], ['best', 'الأفضل'], ['low', 'السعر: أدنى'], ['high', 'السعر: أعلى'], ['discount', 'الأكثر خصماً']];

export default function ProductsPage({ mode }) {
  useTitle(mode === 'offers' ? 'العروض' : mode === 'search' ? 'نتائج البحث' : mode === 'cat' ? 'تصنيف المنتجات' : 'كل المنتجات');
  const [sp] = useSearchParams();
  const { id } = useParams();
  const nav = useNavigate();
  const q = mode === 'search' ? (sp.get('q') || '') : null;
  const catId = mode === 'cat' ? id : null;
  const [sort, setSort] = useState('all');
  const [prods, setProds] = useState(null);
  const [meta, setMeta] = useState([]);
  const [f, setF] = useState({ colors: [], sizes: [], min: '', max: '', show: false });

  useEffect(() => {
    setProds(null);
    const p = new URLSearchParams();
    if (q) p.set('q', q);
    if (mode === 'offers') p.set('offer', 'true');
    else if (catId) p.set('category_id', catId);
    if (f.colors.length) p.set('colors', f.colors.join(','));
    if (f.sizes.length) p.set('sizes', f.sizes.join(','));
    if (f.min) p.set('min_price', f.min);
    if (f.max) p.set('max_price', f.max);
    if (sort === 'best') p.set('best', 'true');
    if (sort === 'low') p.set('sort', 'price_asc');
    if (sort === 'high') p.set('sort', 'price_desc');
    if (sort === 'discount') p.set('sort', 'discount');
    api('/api/products?' + p.toString()).then(d => setProds(d.products || [])).catch(() => setProds([]));
    api('/api/products/meta' + (catId ? '?category_id=' + catId : '')).then(d => setMeta(d)).catch(() => {});
  }, [mode, q, catId, sort, f.colors.join(), f.sizes.join(), f.min, f.max]);

  const title = mode === 'search' ? `نتائج «${q}»`
    : mode === 'offers' ? '🔥 كل العروض' : 'كل المنتجات';
  const tgl = (arr, v) => arr.includes(v) ? arr.filter(x => x !== v) : [...arr, v];
  const fCount = f.colors.length + f.sizes.length + (f.min || f.max ? 1 : 0);

  return (
    <section className="sect" style={{ paddingTop: 16 }}>
      <div className="sect-head">
        <button className="i-btn" onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={16} w={600} /></button>
        <h2>{mode !== 'search' ? <M n={mode === 'offers' ? 'local_fire_department' : 'grid_view'} s={18} c="var(--primary)" w={700} /> : <M n="search" s={18} c="var(--primary)" w={700} />} {title} <span style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 700 }}>{prods ? `(${prods.length})` : ''}</span></h2>
        {mode !== 'offers' && <button className={`btn btn-o btn-sm ${f.show ? 'on' : ''}`} style={{ marginInlineStart: 'auto' }} onClick={() => setF({ ...f, show: !f.show })}><M n="tune" s={15} w={600} />تصفية{fCount ? ` (${fCount})` : ''}</button>}
      </div>
      <div className="cats-row" style={{ paddingInline: 0 }}>
        {SORTS.map(([k, t]) => <span key={k} className={`chipg ${sort === k ? 'on' : ''}`} onClick={() => setSort(k)}>{t}</span>)}
      </div>

      {f.show && (
        <div className="card" style={{ padding: 16, marginBottom: 14, marginTop: 6 }}>
          <div className="sect-head" style={{ marginBottom: 4 }}><h2 style={{ fontSize: 14 }}>التصفية</h2><a onClick={() => setF({ colors: [], sizes: [], min: '', max: '', show: false })}>مسح الكل</a></div>
          <div className="flt-lbl">الألوان</div>
          <div className="flt-wrap">
            {(meta.colors || []).map(c => <span key={c} className={`chipf ${f.colors.includes(c) ? 'on' : ''}`} onClick={() => setF({ ...f, colors: tgl(f.colors, c) })}>{c}</span>)}
          </div>
          <div className="flt-lbl">المقاسات</div>
          <div className="flt-wrap">
            {(meta.sizes || []).map(c => <span key={c} className={`chipf chipsq ${f.sizes.includes(c) ? 'on' : ''}`} onClick={() => setF({ ...f, sizes: tgl(f.sizes, c) })}>{c}</span>)}
          </div>
          <div className="flt-price" style={{ marginTop: 10 }}>
            <input className="inp" type="number" placeholder="من سعر" value={f.min} onChange={(e) => setF({ ...f, min: e.target.value })} />
            <span style={{ color: 'var(--muted)' }}>—</span>
            <input className="inp" type="number" placeholder="إلى سعر" value={f.max} onChange={(e) => setF({ ...f, max: e.target.value })} />
          </div>
        </div>
      )}

      {!prods ? <SkeGrid n={10} />
        : prods.length ? <div className="grid" style={{ paddingInline: 0 }}>{prods.map(p => <ProductCard key={p.id} p={p} />)}</div>
        : <Empty icon="🔍" msg="ما لقينا نتائج" sub="جرّب كلمة أقصر أو أزل التصفية"
            action={<button className="btn btn-o btn-sm" style={{ marginTop: 14 }} onClick={() => { setSort('all'); nav('/prods'); }}>كل المنتجات</button>} />}
    </section>
  );
}