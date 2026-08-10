import React from 'react';
import { U } from './api';

export const Img = ({ src, alt = '', fontSize = '52px', fallback = '🛍️', className = '', style = {} }) =>
  U(src)
    ? <img className={className} style={style} src={src} alt={alt} loading="lazy" onError={(e) => { e.currentTarget.outerHTML = `<span style="font-size:${fontSize}">${fallback}</span>`; }} />
    : <span className={className} style={{ fontSize, ...style }}>{src || fallback}</span>;

export const Ske = ({ cls, n = 8 }) => (
  <div className="skgrid">
    {Array.from({ length: n }).map((_, i) => <div key={i} className={`sk ${cls || ''}`}><i className="skimg" /><i className="skln w60" /><i className="skln w40" /><i className="skln w80" /></div>)}
  </div>
);

export const SectHead = ({ icon, title, accent = 'var(--navy)', more, onMore }) => (
  <div className="sect-head">
    <h2><span className="ln" />{icon} <em style={{ color: accent }}>{title}</em></h2>
    {more && <a href="#prods" onClick={(e) => { e.preventDefault(); onMore && onMore(); }}>{more} ←</a>}
  </div>
);