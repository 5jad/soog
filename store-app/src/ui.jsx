import React, { useEffect } from 'react';
import { U } from './api';

/**
 * غلاف الـ Lottie Animation — يستخدم dotlottie-player كـ web component.
 * القواعد:
 *   loop=true  → loading_splash + main_loader فقط
 *   loop=false → order_success + cart_confirm + empty_state + no_results
 *
 * @param {string} src  - مسار ملف JSON (من public/animations/)
 * @param {number} size - الحجم بالبكسل (مربع)
 * @param {boolean} loop - هل يتكرر؟
 * @param {string} className - كلاسات إضافية
 */
export const LottiePlayer = ({ src, size = 120, loop = false, className = '' }) => {
  // لو prefers-reduced-motion مفعل → لا نعرض الحركة
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce || !src) return null;
  return (
    <dotlottie-player
      src={src}
      autoplay
      loop={loop ? '' : undefined}
      style={{ width: size, height: size, display: 'block' }}
      className={className}
    />
  );
};

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
      {Array.from({ length: 5 - v }).map((_, i) => <M key={i} n="star" s={size} c="var(--line-strong)" w={400} />)}
    </span>
  );
};

/* علبة فراغ */
export const Empty = ({ icon = '📭', msg, sub = '', action = null, lottie = null, lottieSize = 120 }) => (
  <div className="empty-state">
    {lottie
      ? <LottiePlayer src={lottie} size={lottieSize} loop={false} />
      : <span className="e">{icon}</span>
    }
    <h4>{msg}</h4>
    {sub && <p>{sub}</p>}
    {action}
  </div>
);

/* هيكل تحميل */
export const SkeGrid = ({ n = 8 }) => (
  <div className="grid-products">
    {Array.from({ length: n }).map((_, i) => (
      <div key={i} className="sk"><i className="sk-img" /><i className="sk-line w60" /><i className="sk-line w40" /><i className="sk-line w80" /></div>
    ))}
  </div>
);
export const SkeRow = ({ n = 6 }) => (
  <div className="sk-row">{Array.from({ length: n }).map((_, i) => <i key={i} />)}</div>
);
export const Loader = () => (
  <div className="centerload">
    <LottiePlayer src="/animations/main_loader.json" size={80} loop={true} />
    {/* fallback: لو الـ lottie ما شتغل (أوف-لاين/بطيء) نعرض الدائرة */}
    <style>{`.centerload dotlottie-player:not(:defined) ~ .spin { display: block } .centerload dotlottie-player { display: block }`}</style>
    <div className="spin" style={{ display: 'none' }} />
  </div>
);

/* رأس قسم */
export const SectHead = ({ title, accent = 'var(--ink)', more, onMore }) => (
  <div className="sect-head">
    <h2><span className="ln" />{title} {accent && <em style={{ color: accent, fontStyle: 'normal' }}></em>}</h2>
    {more && <a onClick={onMore}>{more} ←</a>}
  </div>
);

/* مودال عام — زر الإغلاق ثابت في الزاوية (modal-x) */
export const Modal = ({ open, onClose, children, lg = false }) => {
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} />
      <div className="modal" onClick={onClose}>
        <div className={`modal-box modal-box--rel ${lg ? 'modal-box--lg' : ''}`} onClick={(e) => e.stopPropagation()}>
          <button className="modal-x" onClick={onClose} aria-label="إغلاق"><M n="close" s={16} w={700} /></button>
          {children}
        </div>
      </div>
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
            <button className="icon-btn" onClick={onClose}><M n="close" s={20} /></button></div>
          {children.body}
        </div>
      </div>
    </>
  );
};