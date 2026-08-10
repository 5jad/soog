import React, { useEffect, useState } from 'react';
import { useSearchParams, useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { ProductCard } from '../components/Cards';
import { SkeGrid, Empty } from '../ui';

const SORTS = [['all', 'الكل'], ['best', '⭐ الأفضل'], ['low', 'السعر: أدنى'], ['high', 'السعر: أعلى'], ['discount', '💸 الأكثر خصماً']];

export default function ProductsPage({ mode }) {
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
    : mode === 'offers' ? '🔥 كل العروض' : '🛍️ كل المنتجات';
  const tgl = (arr, v) => arr.includes(v) ? arr.filter(x => x !== v) : [...arr, v];

  return (
    <section className="sect" style={{ marginTop: 22 }}>
      <div className="breadcrumb">زبون <b>&lt;</b> {title}</div>
      <div className="sect-head">
        <h2><span className="ln" />{title} <span style={{ color: 'var(--muted)', fontSize: 13 }}>{prods ? `(${prods.length})` : ''}</span></h2>
        {mode !== 'offers' && <button className="btn btn-o btn-sm" onClick={() => setF({ ...f, show: !f.show })}>⚙️ تصفية{f.colors.length + f.sizes.length + (f.min || f.max ? 1 : 0) ? ` (${f.colors.length + f.sizes.length + (f.min || f.max ? 1 : 0)})` : ''}</button>}
      </div>
      <div className="chips" style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 14 }}>
        {SORTS.map(([k, t]) => <span key={k} className={`chip ${sort === k ? 'on' : ''}`} onClick={() => setSort(k)}>{t}</span>)}
      </div>

      {f.show && (
        <div className="card" style={{ padding: 16, marginBottom: 16 }}>
          <div className="sect-head" style={{ marginBottom: 10 }}><h2 style={{ fontSize: 14 }}>التصفية</h2><a onClick={() => setF({ colors: [], sizes: [], min: '', max: '', show: false })}>مسح الكل</a></div>
          <div style={{ fontSize: 12, fontWeight: 800, color: 'var(--muted)', marginBottom: 6 }}>الألوان</div>
          <div className="chips" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {meta.colors && meta.colors.map(c => <span key={c} className={`chip ${f.colors.includes(c) ? 'on' : ''}`} onClick={() => setF({ ...f, colors: tgl(f.colors, c) })}>{c}</span>)}
          </div>
          <div style={{ fontSize: 12, fontWeight: 800, color: 'var(--muted)', margin: '10px 0 6px' }}>المقاسات</div>
          <div className="chips" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {meta.sizes && meta.sizes.map(c => <span key={c} className={`chip ${f.sizes.includes(c) ? 'on' : ''}`} onClick={() => setF({ ...f, sizes: tgl(f.sizes, c) })}>{c}</span>)}
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 12, alignItems: 'center' }}>
            <input className="inp" style={{ maxWidth: 130 }} type="number" placeholder="من سعر" value={f.min} onChange={(e) => setF({ ...f, min: e.target.value })} />
            <span style={{ color: 'var(--muted)' }}>—</span>
            <input className="inp" style={{ maxWidth: 130 }} type="number" placeholder="إلى سعر" value={f.max} onChange={(e) => setF({ ...f, max: e.target.value })} />
          </div>
        </div>
      )}

      {!prods ? <SkeGrid n={10} />
        : prods.length ? <div className="grid">{prods.map(p => <ProductCard key={p.id} p={p} />)}</div>
        : <Empty icon="🔍" msg="ما لقينا نتائج" sub="جرّب كلمة أقصر أو أزل التصفية"
            action={<button className="btn btn-o btn-sm" style={{ marginTop: 14 }} onClick={() => { setSort('all'); nav('/prods'); }}>كل المنتجات</button>} />}
    </section>
  );
}