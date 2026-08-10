import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, fmt } from '../api';
import { useApp } from '../ctx';
import { ProductCard, SkelGrid } from '../components/Cards';

export default function Favorites() {
  const { token, setLoginOpen } = useApp();
  const [items, setItems] = useState(null);
  const nav = useNavigate();

  useEffect(() => {
    if (!token) { setItems([]); return; }
    api('/api/customer/favorites').then(d => setItems(d.favorites || d.products || []))
      .catch(() => setItems([]));
  }, [token]);

  if (!token) {
    return (
      <section className="sect"><div className="noprod">
        <span className="e">🔐</span>شاهد مفضلتك يتطلب تسجيل دخول
        <br /><button className="lbtn" style={{ maxWidth: 260, margin: '14px auto 0' }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>
      </div></section>
    );
  }
  return (
    <section className="sect" style={{ marginTop: 24 }}>
      <div className="sect-head"><h2><span className="ln" />❤️ <em style={{ color: 'var(--bad)' }}>المفضلة</em></h2></div>
      {!items ? <SkelGrid n={8} />
        : items.length ? <div className="prods">{items.map(x => <ProductCard key={x.product_id ?? x.id} p={{ ...x, id: x.product_id ?? x.id }} />)}</div>
        : <div className="noprod"><span className="e">🤍</span>ماكو مفضلات بعد — اضغط ♡ على أي منتج</div>}
    </section>
  );
}