import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { U } from '../api';
import { M } from '../ui';

const COVERS = ['linear-gradient(135deg,var(--primary-deep),var(--primary))', 'linear-gradient(135deg,var(--accent-light),var(--orange-soft))', 'linear-gradient(135deg,var(--success-deep),var(--success-light))', 'linear-gradient(135deg,var(--warning),var(--star))'];

export default function Promo({ ads, stores }) {
  const nav = useNavigate();
  const [page, setPage] = useState(0);
  const timer = useRef(null);
  const list = ads && ads.length ? ads : [{
    title: 'كل ما تتمناه بمكان واحد',
    theme: 'navy', store_id: null, store_name: 'مول الأزياء',
    description: 'لرجالك ونسائك وأطفالك — خصومات على كل الطلبيات',
  }];

  useEffect(() => {
    if (!list || list.length <= 1) return;
    timer.current = setInterval(() => setPage((p) => (p + 1) % list.length), 4000);
    return () => clearInterval(timer.current);
  }, [ads]);

  const coverOf = (a) => {
    if (!a.store_id) return '';
    const s = (stores || []).find(x => x.id === a.store_id);
    return (s && s.cover) || '';
  };
  const imgOf = (a) => [a.image, a.store_cover, coverOf(a)].find(x => U(x)) || '';

  const open = (a) => {
    if (a.store_id != null) nav('/stores/' + a.store_id);
    else nav('/stores');
  };

  return (
    <div>
      <div className="hero" onClick={() => open(list[page])} style={{ cursor: 'pointer' }}>
        {(() => {
          const a = list[page];
          const sun = a.theme === 'sun';
          const img = imgOf(a);
          const grad = img ? '' : (sun ? 'linear-gradient(135deg,var(--orange-deep),var(--orange-soft))' : 'linear-gradient(135deg,var(--primary-deep),var(--primary),var(--cyan))');
          return (
            <>
              {img ? <div className="hero-bg" style={{ backgroundImage: `url(${img})` }} /> : <div className="hero-bg" style={{ background: grad }} />}
              <div className="hero-ov" />
              {!img && <span className="hero-emoji">{sun ? '🛍️' : '💎'}</span>}
              <div className="hero-in">
                <span className={`hero-chip ${sun ? 'sun' : ''}`}>
                  {U(coverOf(a)) ? <img src={coverOf(a)} alt="" />
                    : <b className="hero-logo" style={{ background: 'rgba(255,255,255,.2)', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>🏪</b>}
                  {a.store_name || 'عرض مميز'}
                </span>
                <div className="hero-row">
                  <div style={{ minWidth: 0 }}>
                    <div className="hero-t">{a.title}</div>
                    {a.description ? <div className="hero-d">{a.description}</div> : null}
                  </div>
                  <span className="hero-btn">تسوق الآن <M n="arrow_back" s={14} w={800} /></span>
                </div>
              </div>
            </>
          );
        })()}
      </div>
      {(ads || []).length > 1 && (
        <div className="dots">
          {(ads || []).map((_, i) => <span key={i} className={`dot ${i === page ? 'on' : ''}`} />)}
        </div>
      )}
    </div>
  );
}