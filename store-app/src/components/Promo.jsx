import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';

const GRADS = [
  'linear-gradient(135deg,#1E3A8A,#1D4ED8 55%,#38BDF8)',
  'linear-gradient(135deg,#7C3AED,#1D4ED8 60%,#06B6D4)',
  'linear-gradient(135deg,#B45309,#F97316 60%,#FB923C)',
];

export default function Promo() {
  const [ads, setAds] = useState(null);
  const [i, setI] = useState(0);
  const nav = useNavigate();

  useEffect(() => {
    let live = true;
    api('/api/ads').then(d => live && setAds((d.ads || []).filter(a => a.status === 'active'))).catch(() => live && setAds([]));
    return () => { live = false; };
  }, []);

  useEffect(() => {
    if (!ads || ads.length < 2) return;
    const t = setInterval(() => setI(k => (k + 1) % ads.length), 4500);
    return () => clearInterval(t);
  }, [ads]);

  const slides = (ads && ads.length)
    ? ads.slice(0, 4).map(a => ({
        bg: a.gradient && a.gradient.includes(',') ? a.gradient : GRADS[ads.indexOf(a) % GRADS.length],
        t: a.title || 'عرض خاص من زبون',
        p: a.store_name ? `عرض حصري من ${a.store_name} — توصيل سريع والدفع عند الاستلام.` : 'توصيل سريع والدفع عند الاستلام داخل واسط.',
        e: a.art || '🎁',
        go: a.store_id ? () => nav('/stores/' + a.store_id) : null,
      }))
    : [
        { bg: GRADS[0], t: 'كل ما تتمناه 🤲 من متاجر الكوت', p: 'ملابس، مكياج، ألعاب، إلكترونيات — اطلب ويوصلك الباب.', e: '🛍️', go: () => nav('/prods') },
        { bg: GRADS[1], t: 'عروض 🔥 اليوم محدودة', p: 'خصومات حقيقية على الأكثر مبيعاً — شحن سريع داخل المحافظة.', e: '⚡', go: () => nav('/offers') },
        { bg: GRADS[2], t: 'حمّل تطبيق زبون 📲', p: 'تجربة أسرع على الجوال: عجلة حظ، تتبع حي، وبوت تليجرام.', e: '📲', go: null },
      ];

  if (!ads) return <div className="promo"><div className="rail" style={{ background: '#EEF3FB' }} /></div>;

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
            <span className="em">{s.e}</span>
          </div>
        ))}
      </div>
      <div className="dots">{slides.map((_, k) => <i key={k} className={k === i ? 'on' : ''} onClick={() => setI(k)} />)}</div>
    </section>
  );
}