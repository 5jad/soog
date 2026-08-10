import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Empty } from '../ui';

export default function ComingSoon({ area }) {
  const nav = useNavigate();
  const map = {
    vendor: { ic: '🧑‍💼', t: 'منطقة التاجر', d: 'إدارة متجرك: المنتجات، الطلبات، الكوبونات، والأداء — قيد البناء، قريباً جداً!' },
    delivery: { ic: '🛵', t: 'منطقة المندوب', d: 'طلبات جديدة، خريطة تتبع حية، وتقارير كاش — قيد البناء، قريباً جداً!' },
    admin: { ic: '🛡️', t: 'لوحة الإدارة', d: 'الإشراف الكامل على المنصة — قيد البناء، قريباً جداً!' },
  };
  const m = map[area] || map.vendor;
  return (
    <div className="sect">
      <div className="grad-navy card-glow" style={{ padding: 26, borderRadius: 20, marginBottom: 14, textAlign: 'center' }}>
        <div style={{ fontSize: 13, letterSpacing: 1, opacity: .8 }}>متبقٍ من المراحل القادمة</div>
        <div style={{ fontSize: 26, fontWeight: 900, margin: '6px 0' }}>{m.ic} {m.t}</div>
        <div style={{ fontSize: 13, opacity: .85, maxWidth: 420, margin: '0 auto' }}>{m.d}</div>
      </div>
      <Empty icon={m.ic} msg={m.t + ' — قيد البناء!'} action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => nav('/')}>العودة للمتجر</button>} />
    </div>
  );
}