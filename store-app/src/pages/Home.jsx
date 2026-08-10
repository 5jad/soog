import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import Promo from '../components/Promo';
import { ProductCard, StoreCard, DealCard, CatIcon, SkelGrid } from '../components/Cards';
import { SectHead } from '../ui';

export default function Home() {
  const [st, setSt] = useState(null);
  const [cats, setCats] = useState([]);
  const [offers, setOffers] = useState([]);
  const [best, setBest] = useState([]);
  const nav = useNavigate();

  useEffect(() => {
    let live = true;
    Promise.all([api('/api/stores'), api('/api/categories'), api('/api/offers'), api('/api/products?best=true')])
      .then(([s, c, o, b]) => {
        if (!live) return;
        setSt(s.stores || s || []);
        setCats(c.categories || c || []);
        setOffers(o.offers || o || []);
        setBest(b.products || []);
      }).catch(() => {});
    const id = setTimeout(() => {}, 1);
    return () => { live = false; clearTimeout(id); };
  }, []);

  const [cat, setCat] = useState(null);
  const pickCat = (c) => { setCat(c); if (c) nav('/prods?cat=' + c.id); else nav('/prods'); };

  return (
    <>
      <Promo />
      <section className="sect">
        <div className="sect-head"><h2><span className="ln" />تسوّق حسب <em style={{ color: 'var(--blue)' }}>القسم</em></h2></div>
        <div className="cats">
          <CatIcon c={{ name: 'الكل', icon: '🛍️' }} on={!cat} onClick={() => pickCat(null)} />
          {cats.map(c => <CatIcon key={c.id} c={c} on={cat && cat.id === c.id} onClick={() => pickCat(c)} />)}
        </div>
      </section>

      {offers.length ? (
        <section className="sect">
          <SectHead icon="🔥" title="عروض اليوم" accent="var(--bad)" more="كل العروض" onMore={() => nav('/offers')} />
          <div className="deals">{offers.map(o => <DealCard key={o.id} p={o} />)}</div>
        </section>
      ) : null}

      <section className="sect">
        <SectHead icon="🏬" title="متاجر الكوت" accent="var(--navy)" more="الكل" onMore={() => nav('/stores')} />
        {!st ? <div className="skgrid skh"><i /><i /><i /><i /><i /></div>
          : <div className="shops">{st.slice(0, 10).map(s => <StoreCard key={s.id} st={s} />)}</div>}
      </section>

      <section className="sect">
        <SectHead icon="⭐" title="الأكثر مبيعاً" accent="var(--amber)" more="الكل" onMore={() => nav('/prods')} />
        {!best.length ? <SkelGrid n={8} /> : <div className="prods">{best.slice(0, 12).map(p => <ProductCard key={p.id} p={p} />)}</div>}
      </section>
    </>
  );
}