import React, { useEffect, useState } from 'react';
import { api } from '../api';
import { useApp } from '../ctx';
import { StoreCard } from '../components/Cards';
import { Empty, M, SkeGrid, useTitle } from '../ui';

const COVERS = ['linear-gradient(135deg,var(--primary-deep),var(--primary))', 'linear-gradient(135deg,var(--accent-light),var(--accent))', 'linear-gradient(135deg,var(--success-deep),var(--success))', 'linear-gradient(135deg,var(--warning),var(--star))'];

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
    <div className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="sect-head"><h2><M n="storefront" s={19} c="var(--primary)" /> متاجر الكوت <span className="muted" style={{ fontSize: 12, fontWeight: 700 }}>({stores ? show.length + ' من ' + stores.length : ''})</span></h2></div>
      <form className="search" style={{ marginBlockEnd: 12 }} role="search" onSubmit={(e) => e.preventDefault()}>
        <M n="search" s={19} c="var(--muted)" w={600} cls="ic" />
        <input placeholder="ابحث عن محل…" value={q} onChange={(e) => setQ(e.target.value)} aria-label="بحث عن محل" />
        {q ? <button type="button" className="icon-btn" style={{ width: 32, height: 32, border: 0 }} onClick={() => setQ('')}><M n="close" s={17} w={500} /></button> : null}
      </form>
      <div className="grid-cats">
        <span className={`chip ${!catSel ? 'on' : ''}`} onClick={() => setCatSel(null)}>الكل</span>
        {cats.map(c => <span key={c.id} className={`chip ${catSel === c.id ? 'on' : ''}`} onClick={() => setCatSel(c.id)}>{c.icon || ''} {c.name}</span>)}
      </div>
      <div className="grid-cats">
        {[['best', 'الأكثر تقييماً'], ['new', 'الأحدث']].map(([v, l]) => (
          <span key={v} className={`chip ${sort === v ? 'on' : ''}`} onClick={() => setSort(v)}>{l}</span>
        ))}
      </div>
      {!stores ? <SkeGrid n={6} />
        : show.length ? <div className="grid-stores" style={{ marginBlockStart: 8 }}>{show.map((s, i) => <StoreCard key={s.id} s={s} cover={COVERS[i % 4]} />)}</div>
        : <Empty icon="🏬" msg="ماكو متاجر مطابقة" />}
      {myFollowed.length ? (
        <>
          <div className="sect-head"><h2><M n="favorite" fill s={17} c="var(--danger)" /> متاجر تابعتهم</h2></div>
          <div className="grid-stores">{myFollowed.map((s, i) => <StoreCard key={s.id} s={s} cover={COVERS[i % 4]} />)}</div>
        </>
      ) : null}
    </div>
  );
}