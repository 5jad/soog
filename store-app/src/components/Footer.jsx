import React from 'react';
import { useNavigate } from 'react-router-dom';
import { M } from '../ui';

const COLS = [
  { t: 'تسوق', items: [['الرئيسية', '/'], ['كل المنتجات', '/prods'], ['العروض', '/offers'], ['المتاجر', '/stores']] },
  { t: 'حسابي', items: [['سلة التسوق', '/cart'], ['المفضلة', '/fav'], ['طلباتي', '/orders'], ['نقاطي', '/points']] },
  { t: 'عن زبون', items: [['الإشعارات', '/notifications'], ['حسابي', '/account'], ['تواصل معنا', '/account'], ['تحميل التطبيق', '/download']] },
];

export default function Footer() {
  const nav = useNavigate();
  return (
    <footer className="foot">
      <div className="foot-in">
        <div className="foot-brand">
          <div className="foot-logo">
            <span className="foot-b">ز</span>
            <div>
              <b>زبون</b>
              <span>كل ما تتمناه بمكان واحد</span>
            </div>
          </div>
          <p>تسوق من متاجر الكوت: ملابس، مكياج، ألعاب، إلكترونيات وأكثر. توصيل سريع 30–60 دقيقة وادفع كاش عند الاستلام.</p>
          <div className="foot-perks">
            <span><M n="local_shipping" s={15} c="var(--primary)" w={600} /> توصيل سريع</span>
            <span><M n="payments" s={15} c="var(--primary)" w={600} /> دفع عند الاستلام</span>
            <span><M n="autorenew" s={15} c="var(--primary)" w={600} /> استرجاع سهل</span>
          </div>
        </div>
        {COLS.map(c => (
          <div key={c.t} className="foot-col">
            <b>{c.t}</b>
            {c.items.map(([l, to]) => (
              <a key={l} onClick={(e) => {
                if (to === '/download') return;
                e.preventDefault();
                nav(to);
              }} href={to === '/download' ? '/download' : '#'}>{l}</a>
            ))}
          </div>
        ))}
      </div>
      <div className="foot-bar">© 2026 زبون · الكوت ، واسط — جميع الحقوق محفوظة</div>
    </footer>
  );
}