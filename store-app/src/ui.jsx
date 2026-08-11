import React, { useEffect } from 'react';
import { U } from './api';

/* عنوان الصفحة في شريط المتصفح */
export const useTitle = (t, extra = '') => {
  useEffect(() => {
    document.title = t ? (extra ? `${t} — ${extra}` : `${t} | زبون`) : 'زبون — كل ما تتمناه بمكان واحد';
  }, [t, extra]);
};

/* ═══ أيقونة Material Symbols — مطابقة أيقونات التطبيق ═══ */
export const M = ({ n, s = 20, c = 'currentColor', fill = false, w = 400, cls = '', style = {} }) => (
  <span className={'msm ' + (fill ? 'mf ' : '') + cls} style={{ fontSize: s, color: c, fontVariationSettings: `'FILL' ${fill ? 1 : 0},'wght' ${w},'GRAD' 0,'opsz' 24`, ...style }}>{n}</span>
);

/* صورة آمنة: data-URI أو مسار داخلي، وإلا أيقونة */
export const Img = ({ src, alt = '', fontSize = '44px', fallback = '🛍️', className = '', style = {}, noSpan }) => {
  if (U(src)) {
    return <img className={className} style={style} src={src} alt={alt} loading="lazy"
      onError={(e) => { e.currentTarget.style.display = 'none'; }} />;
  }
  return <span className={className} style={{ fontSize, ...style }}>{src || fallback}</span>;
};

/* نجوم التقييم */
export const Stars = ({ n = 0, size = 15, color = 'var(--star)' }) => {
  const v = Math.max(0, Math.min(5, Math.round(Number(n) || 0)));
  return (
    <span className="stars" style={{ fontSize: size }}>
      {Array.from({ length: v }).map((_, i) => <M key={i} n="star" fill s={size} c={color} w={700} />)}
      {Array.from({ length: 5 - v }).map((_, i) => <M key={i} n="star" s={size} c="var(--line2)" w={400} />)}
    </span>
  );
};

/* علبة فراغ */
export const Empty = ({ icon = '📭', msg, sub = '', action = null }) => (
  <div className="empty">
    <span className="e">{icon}</span>
    <div style={{ fontWeight: 800, fontSize: 15, color: 'var(--text)' }}>{msg}</div>
    {sub && <div style={{ fontSize: 12.5, marginTop: 5 }}>{sub}</div>}
    {action}
  </div>
);

/* هيكل تحميل */
export const SkeGrid = ({ n = 8 }) => (
  <div className="grid">
    {Array.from({ length: n }).map((_, i) => (
      <div key={i} className="sk"><i className="skimg" /><i className="skln w60" /><i className="skln w40" /><i className="skln w80" /></div>
    ))}
  </div>
);
export const SkeRow = ({ n = 6 }) => (
  <div className="skrow">{Array.from({ length: n }).map((_, i) => <i key={i} />)}</div>
);
export const Loader = () => <div className="centerload"><div className="spin" /></div>;

/* رأس قسم */
export const SectHead = ({ title, accent = 'var(--ink)', more, onMore }) => (
  <div className="sect-head">
    <h2><span className="ln" />{title} {accent && <em style={{ color: accent, fontStyle: 'normal' }}></em>}</h2>
    {more && <a onClick={onMore}>{more} ←</a>}
  </div>
);

/* مودال عام */
export const Modal = ({ open, onClose, children, lg = false }) => {
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} />
      <div className="modal"><div className={lg ? 'box lg' : 'box'}>{children}</div></div>
    </>
  );
};

/* شيت سفلي */
export const Sheet = ({ open, onClose, children }) => {
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} style={{ zIndex: 105 }} />
      <div style={{ position: 'fixed', inset: 0, zIndex: 105, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
        <div className="sheet" style={{ width: 'min(560px,100vw)' }}>
          <div className="sheet-head"><b>{children.title || ''}</b>
            <button className="i-btn" onClick={onClose}><M n="close" s={20} /></button></div>
          {children.body}
        </div>
      </div>
    </>
  );
};