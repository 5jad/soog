import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useApp } from '../ctx';
import { Empty, SkeGrid, useTitle } from '../ui';
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

  if (!token) return <div className="sect"><Empty icon="🔐" msg="سجّل دخولك لعرض مفضلتك"
    action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (loading) return <SkeGrid />;

  return (
    <div className="sect">
      <div className="sect-head"><h2><span className="ln" />❤️ المفضلة</h2><span style={{ color: 'var(--muted)', fontSize: 12 }}>{favs.length} منتج</span></div>
      {!favs.length ? <Empty icon="💔" msg="أضف منتجات تحبها إلى المفضلة ❤️"
        action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => nav('/')}>تصفح المتجر</button>} /> : (
        <div className="grid">
          {favs.map(p => <ProductCard key={p.id} p={p} />)}
        </div>
      )}
    </div>
  );
}