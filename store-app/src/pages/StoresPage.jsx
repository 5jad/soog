import React, { useEffect, useState } from 'react';
import { api } from '../api';
import { useApp } from '../ctx';
import { StoreCard } from '../components/Cards';
import { SkeRow, Empty } from '../ui';

export default function StoresPage() {
  const [stores, setStores] = useState(null);
  const [cats, setCats] = useState([]);
  const [catSel, setCatSel] = useState(null);
  const [q, setQ] = useState('');
  const [followed, setFollowed] = useState([]);
  const { token } = useApp();

  useEffect(() => {
    api('/api/stores').then(d => setStores(d.stores || [])).catch(() => setStores([]));
    api('/api/categories').then(d => setCats(d.categories || [])).catch(() => {});
    if (token) api('/api/customer/store-favorites').then(d => setFollowed((d.favorites || []).map(f => f.store_id))).catch(() => {});
  }, []);

  const show = (stores || []).filter(s =>
    (!catSel || s.category_id === catSel) && (!q.trim() || s.name.includes(q.trim())));
  const myFollowed = (stores || []).filter(s => followed.includes(s.id));

  return (
    <div className="sect" style={{ marginTop: 22 }}>
      <div className="breadcrumb">زبون <b>&lt;</b> المتاجر</div>
      <div className="sect-head"><h2><span className="ln" />🏬 متاجر الكوت <span style={{ color: 'var(--muted)', fontSize: 13 }}>({stores ? stores.length : ''})</span></h2></div>
      <div style={{ display: 'flex', gap: 10, marginBottom: 14, flexWrap: 'wrap', alignItems: 'center' }}>
        <input className="inp" style={{ maxWidth: 280 }} placeholder="ابحث عن محل…" value={q} onChange={(e) => setQ(e.target.value)} />
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <span className={`chip ${!catSel ? 'on' : ''}`} onClick={() => setCatSel(null)}>الكل</span>
          {cats.map(c => <span key={c.id} className={`chip ${catSel === c.id ? 'on' : ''}`} onClick={() => setCatSel(c.id)}>{c.icon || ''} {c.name}</span>)}
        </div>
      </div>
      {!stores ? <SkeRow n={6} />
        : show.length ? <div className="railx" style={{ flexWrap: 'wrap' }}>{show.map(s => <StoreCard key={s.id} st={s} />)}</div>
        : <Empty icon="🏬" msg="ماكو متاجر مطابقة" />}
      {myFollowed.length ? (
        <>
          <div className="sect-head" style={{ marginTop: 30 }}><h2><span className="ln" />❤️ متاجر تابعتهم</h2></div>
          <div className="railx" style={{ flexWrap: 'wrap' }}>{myFollowed.map(s => <StoreCard key={s.id} st={s} />)}</div>
        </>
      ) : null}
    </div>
  );
}