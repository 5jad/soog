import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import Promo from '../components/Promo';
import { ProductCard, StoreCard, DealCard, CatIcon } from '../components/Cards';
import { SkeGrid, SkeRow } from '../ui';

export default function Home() {
  const [st, setSt] = useState(null);
  const [cats, setCats] = useState([]);
  const [offers, setOffers] = useState([]);
  const [best, setBest] = useState(null);
  const [followed, setFollowed] = useState([]);
  const { token } = useApp();
  const nav = useNavigate();
  const [cat, setCat] = useState(null);

  useEffect(() => {
    let live = true;
    Promise.all([api('/api/stores'), api('/api/categories'), api('/api/offers'), api('/api/products?best=true')])
      .then(([s, c, o, b]) => {
        if (!live) return;
        setSt(s.stores || []); setCats(c.categories || []); setOffers(o.products || []); setBest(b.products || []);
      }).catch(() => {});
    if (token) api('/api/customer/store-favorites').then(d => setFollowed((d.favorites || []).map(f => f.store_id))).catch(() => {});
    return () => { live = false; };
  }, []);

  const pickCat = (c) => { setCat(c); nav(c ? '/cat/' + c.id : '/prods'); };
  const followedStores = (st || []).filter(s => followed.includes(s.id));

  return (
    <>
      <Promo />
      <section className="sect">
        <div className="sect-head"><h2><span className="ln" />تسوّق حسب <em style={{ color: 'var(--primary)', fontStyle: 'normal' }}>القسم</em></h2></div>
        <div className="cats">
          <CatIcon c={{ name: 'الكل', icon: '🛍️' }} on={!cat} onClick={() => pickCat(null)} />
          {cats.map(c => <CatIcon key={c.id} c={c} on={cat && cat.id === c.id} onClick={() => pickCat(c)} />)}
        </div>
      </section>

      {offers.length ? (
        <section className="sect">
          <div className="sect-head"><h2><span className="ln" />🔥 عروض اليوم <em style={{ color: 'var(--accent-deep)', fontStyle: 'normal' }}></em></h2><a onClick={() => nav('/offers')}>كل العروض ←</a></div>
          <div className="railx">{offers.map(o => <DealCard key={o.id} p={o} />)}</div>
        </section>
      ) : null}

      <section className="sect">
        <div className="sect-head"><h2><span className="ln" />🏬 متاجر الكوت</h2><a onClick={() => nav('/stores')}>الكل ←</a></div>
        {!st ? <SkeRow n={5} /> : <div className="railx">{st.slice(0, 10).map(s => <StoreCard key={s.id} st={s} />)}</div>}
      </section>

      {followedStores.length ? (
        <section className="sect">
          <div className="sect-head"><h2><span className="ln" />❤️ متاجر تابعتهم</h2></div>
          <div className="railx">{followedStores.map(s => <StoreCard key={s.id} st={s} />)}</div>
        </section>
      ) : null}

      <section className="sect">
        <div className="sect-head"><h2><span className="ln" />⭐ الأكثر مبيعاً</h2><a onClick={() => nav('/prods')}>الكل ←</a></div>
        {!best ? <SkeGrid n={8} /> : <div className="grid">{best.slice(0, 12).map(p => <ProductCard key={p.id} p={p} />)}</div>}
      </section>
    </>
  );
}