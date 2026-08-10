import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api, fmt } from '../api';
import { Img } from '../ui';
import { ProductCard, SkelGrid } from '../components/Cards';

export default function StorePage() {
  const { id } = useParams();
  const [st, setSt] = useState(null);
  const [prods, setProds] = useState(null);

  useEffect(() => {
    setSt(null); setProds(null);
    Promise.all([api('/api/stores/' + id), api('/api/products?store_id=' + id)])
      .then(([sd, pd]) => { setSt(sd.store || sd); setProds(pd.products || []); })
      .catch(() => {});
  }, [id]);

  return (
    <div className="sect" style={{ marginTop: 22 }}>
      {!st ? <div className="skgrid skh"><i /><i /><i /></div> : (
        <>
          <div className="store-head">
            <div className="logo"><Img src={st.logo} fontSize="34px" /></div>
            <div style={{ flex: 1, textAlign: 'right' }}>
              <h1>{st.name}</h1>
              <div className="meta">⭐ {st.rating_avg || '5.0'} · {(prods || []).length} منتج{st.is_open ? '' : ' · مغلق حالياً'}
                {st.address ? ` · ${st.address}` : ''} {st.phone ? ` · 📞 ${st.phone}` : ''}</div>
            </div>
          </div>
          <div className="chips">
            <span className="chip on">كل المنتجات</span>
            <span className="chip">التوصيل: {st.delivery_fee ? fmt(st.delivery_fee) : 'مجاني'}</span>
            {st.free_delivery_min ? <span className="chip">مجاني فوق {fmt(st.free_delivery_min)}</span> : null}
          </div>
        </>
      )}
      {!prods ? <SkelGrid n={10} />
        : prods.length ? <div className="prods">{prods.map(p => <ProductCard key={p.id} p={p} />)}</div>
        : <div className="noprod"><span className="e">📭</span>ماكو منتجات بهذا المحل بعد</div>}
    </div>
  );
}