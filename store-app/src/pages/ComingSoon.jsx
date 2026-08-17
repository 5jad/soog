import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Empty, M, useTitle } from '../ui';

export default function ComingSoon({ area }) {
  useTitle('قريباً');
  const nav = useNavigate();
  const map = {
    vendor: { ic: '🧑‍💼', t: 'منطقة التاجر', d: 'إدارة متجرك: المنتجات، الطلبات، الكوبونات، والأداء — قيد البناء، قريباً جداً!', s: 'storefront' },
    delivery: { ic: '🛵', t: 'منطقة المندوب', d: 'طلبات جديدة، خريطة تتبع حية، وتقارير كاش — قيد البناء، قريباً جداً!', s: 'delivery_dining' },
    admin: { ic: '🛡️', t: 'لوحة الإدارة', d: 'الإشراف الكامل على المنصة — قيد البناء، قريباً جداً!', s: 'shield' },
  };
  const m = map[area] || map.vendor;
  return (
    <div className="container section" style={{ paddingBlockStart: 12 }}>
      <div className="promo-banner" style={{ padding: 26, textAlign: 'center', marginBlockStart: 0 }}>
        <M n={m.s} s={40} c="var(--white)" w={400} />
        <div style={{ fontSize: 13, letterSpacing: 1, opacity: .8, marginBlockStart: 8 }}>متبقٍ من المراحل القادمة</div>
        <div style={{ fontSize: 26, fontWeight: 900, margin: '6px 0' }}>{m.ic} {m.t}</div>
        <div style={{ fontSize: 13, opacity: .85, maxWidth: 420, margin: '0 auto' }}>{m.d}</div>
      </div>
      <Empty icon={m.ic} msg={m.t + ' — قيد البناء!'} action={<button className="btn btn--cta" style={{ marginTop: 14 }} onClick={() => nav('/')}>العودة للمتجر</button>} />
    </div>
  );
}