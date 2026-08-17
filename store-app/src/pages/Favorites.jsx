import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import { Empty, SkeGrid, M, useTitle } from '../ui';
import { ProductCard } from '../components/Cards';

export default function Favorites() {
  useTitle('المفضلة');
  const { token, favs, refreshFav, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (token) {
      refreshFav().finally(() => setLoading(false));
    }
  }, [token]);

  if (!token) return <div className="container section"><Empty icon="🔐" msg="سجّل دخولك لعرض مفضلتك"
    action={<button className="btn btn--navy" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (loading) return <SkeGrid />;

  return (
    <div className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="sect-head"><h2><M n="favorite" fill s={19} c="var(--danger)" /> المفضلة <span className="muted" style={{ fontSize: 12, fontWeight: 700 }}>({favs.length} منتج)</span></h2></div>
      {!favs.length ? <Empty icon="💔" msg="أضف منتجات تحبها إلى المفضلة ❤️"
        action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/')}>تصفح المتجر</button>} /> : (
        <div className="grid-products">
          {favs.map(p => <ProductCard key={p.id} p={p} />)}
        </div>
      )}
    </div>
  );
}