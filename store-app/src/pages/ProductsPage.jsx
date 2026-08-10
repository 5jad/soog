import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api } from '../api';
import { ProductCard, SkelGrid } from '../components/Cards';

export default function ProductsPage({ mode }) {
  const [sp, setSp] = useSearchParams();
  const q = mode === 'search' ? (sp.get('q') || '') : null;
  const catId = sp.get('cat');
  const [sort, setSort] = useState('all');
  const [prods, setProds] = useState(null);

  useEffect(() => {
    setProds(null);
    const p = new URLSearchParams();
    if (mode === 'offers') p.set('sort', 'discount');
    else if (mode === 'stores') p.set('best', 'true');
    else {
      if (catId) p.set('category_id', catId);
      if (sort === 'best') p.set('best', 'true');
      if (sort === 'low') p.set('sort', 'price_asc');
      if (sort === 'high') p.set('sort', 'price_desc');
      if (sort === 'discount') p.set('sort', 'discount');
      if (catId && sort === 'discount') p.set('sort', 'discount');
    }
    if (q) p.set('q', q);
    api('/api/products?' + p.toString()).then(d => setProds(d.products || [])).catch(() => setProds([]));
  }, [mode, q, catId, sort]);

  const title = mode === 'search' ? 'نتائج البحث'
    : mode === 'offers' ? '🔥 كل العروض'
    : mode === 'stores' ? '⭐ الأكثر مبيعاً' : '🛍️ كل المنتجات';

  return (
    <section className="sect" style={{ marginTop: 24 }}>
      <div className="sect-head"><h2><span className="ln" />{title} {q ? `عن «${q}»` : ''}</h2></div>
      {mode !== 'search' && mode !== 'offers' && mode !== 'stores' && (
        <div className="chips">
          {[['all', 'الكل'], ['best', '⭐ الأفضل'], ['low', 'السعر: أدنى'], ['high', 'السعر: أعلى'], ['discount', '💸 الأكثر خصماً']].map(([k, t]) => (
            <span key={k} className={`chip ${sort === k ? 'on' : ''}`} onClick={() => setSort(k)}>{t}</span>
          ))}
        </div>
      )}
      {!prods ? <SkelGrid n={10} />
        : prods.length ? <div className="prods">{prods.map(p => <ProductCard key={p.id} p={p} />)}</div>
        : <div className="noprod"><span className="e">🔍</span>ما لقينا نتائج — جرّب كلمة أخرى</div>}
    </section>
  );
}