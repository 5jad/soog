import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';

const GRADS = [
  'linear-gradient(120deg,#0e2a47 0%,#1d5fd6 75%,#4a86f0 110%)',
  'linear-gradient(120deg,#7c3aed 0%,#2563eb 70%,#0ea5e9 110%)',
  'linear-gradient(120deg,#b45309 0%,#f59e0b 60%,#fbbf24 105%)',
];

export default function Promo() {
  const [ads, setAds] = useState(null);
  const [i, setI] = useState(0);
  const nav = useNavigate();

  useEffect(() => {
    api('/api/ads').then((d) => setAds((d.ads || d || []).filter(x => x && x.status !== 'inactive')))
      .catch(() => setAds([]));
  }, []);

  useEffect(() => {
    if (!ads || ads.length < 2) return;
    const t = setInterval(() => setI(k => (k + 1) % ads.length), 4500);
    return () => clearInterval(t);
  }, [ads]);

  const slides = ads && ads.length
    ? ads.slice(0, 4).map(a => ({
        bg: a.gradient && a.gradient.includes(',') ? a.gradient : GRADS[ads.indexOf(a) % 3],
        t: a.title || 'عرض خاص من زبون',
        p: a.store_name ? 'عرض حصري من ' + a.store_name + ' — توصيل سريع والدفع عند الاستلام.' : 'خصومات حصرية من متاجر الكوت — توصيل سريع والدفع عند الاستلام.',
        e: a.art || '🎁',
        go: a.store_id ? () => nav('/stores/' + a.store_id) : null,
      }))
    : [
        { bg: GRADS[0], t: 'كل ما تتمناه 🤲 من متاجر الكوت', p: 'ملابس، مكياج، ألعاب، إلكترونيات — اطلب والدفع عند الاستلام.', e: '🛍️', go: () => nav('/prods') },
        { bg: GRADS[1], t: 'عروض 🔥 اليوم محدودة', p: 'خصومات حقيقية على الأكثر مبيعاً — شحن سريع داخل المحافظة.', e: '⚡', go: () => nav('/offers') },
        { bg: GRADS[2], t: 'حمّل تطبيق زبون 📲', p: 'تجربة أسرع على الجوال بالرمز السري وبوت التليجرام.', e: '📲', go: null },
      ];

  if (!ads) return <div className="promo"><div className="rail skrail" /></div>;

  return (
    <section className="promo">
      <div className="rail">
        {slides.map((s, k) => (
          <div key={k} className={`slide ${k === i ? 'on' : ''}`} style={{ background: s.bg }} onClick={s.go}>
            <div>
              <h3>{s.t}</h3>
              <p>{s.p}</p>
              <span className="go">{s.go ? 'تسوق الآن ←' : 'جرب التطبيق'}</span>
            </div>
            <span className="emoji">{s.e}</span>
          </div>
        ))}
      </div>
      <div className="dots">{slides.map((_, k) => <i key={k} className={k === i ? 'on' : ''} onClick={() => setI(k)} />)}</div>
    </section>
  );
}