import React, { useEffect, useState } from 'react';
import { api } from '../api';
import { useApp } from '../ctx';
import { StoreCard } from '../components/Cards';
import { Empty, M, SkeGrid, useTitle } from '../ui';

const COVERS = ['linear-gradient(135deg,#1D4ED8,#38BDF8)', 'linear-gradient(135deg,#F97316,#FB923C)', 'linear-gradient(135deg,#15803D,#4ADE80)', 'linear-gradient(135deg,#B45309,#F59E0B)'];

export default function StoresPage() {
  useTitle('المتاجر', 'جميع متاجر الكوت');
  const [stores, setStores] = useState(null);
  const [cats, setCats] = useState([]);
  const [catSel, setCatSel] = useState(null);
  const [q, setQ] = useState('');
  const [sort, setSort] = useState('best');
  const [followed, setFollowed] = useState([]);
  const { token } = useApp();

  useEffect(() => {
    api('/api/stores').then(d => setStores(d.stores || [])).catch(() => setStores([]));
    api('/api/categories').then(d => setCats(d.categories || [])).catch(() => {});
    if (token) api('/api/customer/store-favorites').then(d => setFollowed((d.favorites || []).map(f => f.store_id))).catch(() => {});
  }, []);

  let show = (stores || []).filter(s =>
    (!catSel || s.category_id === catSel) && (!q.trim() || s.name.includes(q.trim())));
  if (sort === 'best') show = [...show].sort((a, b) => (b.rating || 0) - (a.rating || 0));
  else if (sort === 'new') show = [...show].sort((a, b) => (b.created_at || '').localeCompare(a.created_at || ''));
  const myFollowed = (stores || []).filter(s => followed.includes(s.id));

  return (
    <div className="sect" style={{ paddingTop: 16 }}>
      <div className="sect-head"><h2><M n="storefront" s={19} c="var(--primary)" /> متاجر الكوت <span style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 700 }}>({stores ? show.length + ' من ' + stores.length : ''})</span></h2></div>
      <div className="search-row" style={{ marginBottom: 8 }}>
        <div className="search-f">
          <span className="go" style={{ background: 'none', border: 0, color: 'var(--muted)', padding: '0 8px' }}><M n="search" s={20} w={500} /></span>
          <input placeholder="ابحث عن محل…" value={q} onChange={(e) => setQ(e.target.value)} />
          {q ? <button className="clr" onClick={() => setQ('')}><M n="close" s={19} w={500} /></button> : null}
        </div>
      </div>
      <div className="cats-row" style={{ paddingInline: 0 }}>
        <span className={`chipg ${!catSel ? 'on' : ''}`} onClick={() => setCatSel(null)}>الكل</span>
        {cats.map(c => <span key={c.id} className={`chipg ${catSel === c.id ? 'on' : ''}`} onClick={() => setCatSel(c.id)}>{c.icon || ''} {c.name}</span>)}
      </div>
      <div className="cats-row" style={{ paddingInline: 0 }}>
        {[['best', 'الأكثر تقييماً'], ['new', 'الأحدث']].map(([v, l]) => (
          <span key={v} className={`chipg ${sort === v ? 'on' : ''}`} onClick={() => setSort(v)}>{l}</span>
        ))}
      </div>
      {!stores ? <SkeGrid n={6} />
        : show.length ? <div className="grid" style={{ paddingInline: 0, gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: 12 }}>{show.map((s, i) => <StoreCard key={s.id} s={s} cover={COVERS[i % 4]} />)}</div>
        : <Empty icon="🏬" msg="ماكو متاجر مطابقة" />}
      {myFollowed.length ? (
        <>
          <div className="sect-head"><h2><M n="favorite" fill s={17} c="var(--danger)" /> متاجر تابعتهم</h2></div>
          <div className="grid" style={{ paddingInline: 0, gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: 12 }}>{myFollowed.map((s, i) => <StoreCard key={s.id} s={s} cover={COVERS[i % 4]} />)}</div>
        </>
      ) : null}
    </div>
  );
}