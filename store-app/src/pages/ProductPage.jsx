import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, fmt, pct, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Empty, Loader, M, Stars } from '../ui';

const COLOR_DOT = {
  'أحمر': '#E7352B', 'احمر': '#E7352B', 'red': '#E7352B',
  'أزرق': '#2453CB', 'ازرق': '#2453CB', 'blue': '#2453CB',
  'أسود': '#202126', 'اسود': '#202126', 'black': '#202126',
  'أبيض': '#F5F5F5', 'ابيض': '#F5F5F5', 'white': '#F5F5F5',
  'أخضر': '#1E8A4C', 'اخضر': '#1E8A4C', 'green': '#1E8A4C',
  'أصفر': '#F2C513', 'اصفر': '#F2C513', 'yellow': '#F2C513',
  'بنفسجي': '#7C3AED', 'purple': '#7C3AED',
  'وردي': '#F472B6', 'pink': '#F472B6',
  'رمادي': '#9CA3AF', 'grey': '#9CA3AF',
  'بني': '#7C4A23', 'brown': '#7C4A23',
  'برتقالي': '#F97316', 'orange': '#F97316',
};
const cd = (n) => { const s = String(n || '').toLowerCase().trim(); for (const k of Object.keys(COLOR_DOT)) if (s.includes(k)) return COLOR_DOT[k]; return '#D9DEE7'; };
const ATTR = {
  size: 'القياس', color: 'اللون', material: 'الخامة', age: 'الفئة العمرية', type: 'النوع', expiry: 'تاريخ الانتهاء',
  skin: 'مناسب لـ', weight: 'الوزن / الحجم', serve: 'تكفي لـ', brand: 'الشركة المصنعة', prescription: 'وصفة طبية',
  warranty: 'مدة الضمان', length: 'الطول', width: 'العرض', height: 'الارتفاع', chest: 'محيط الصدر', waist: 'محيط الخصر',
  capacity: 'السعة', origin: 'بلد الصنع', flavor: 'النكهة',
};
const EMO = {
  material: '🧵', age: '👶', type: '🏷️', expiry: '📅', skin: '✨', weight: '⚖️', serve: '🍽️', brand: '🏭',
  prescription: '💊', warranty: '🛡️', length: '📏', width: '↔️', height: '↕️', chest: '📐', waist: '📐',
  capacity: '🪣', origin: '🌍', flavor: '🍬',
};
const CHART = { 'S': ['88', '74', '66'], 'M': ['96', '82', '70'], 'L': ['104', '90', '74'], 'XL': ['112', '98', '78'], 'XXL': ['120', '106', '82'], 'XS': ['80', '66', '62'] };

export default function ProductPage() {
  const { id } = useParams();
  const nav = useNavigate();
  const { token, addToCart, notify, refreshFav, setLoginOpen } = useApp();
  const [st, setSt] = useState({ p: null, store: null, reviews: [], related: [], same: [] });
  const [qty, setQty] = useState(1);
  const [selColor, setSelColor] = useState('');
  const [selSize, setSelSize] = useState(-1);
  const [imgIdx, setImgIdx] = useState(0);
  const [isFav, setIsFav] = useState(false);
  const [busy, setBusy] = useState(false);
  const [guide, setGuide] = useState(false);
  const startX = useRef(null);

  useEffect(() => {
    let live = true;
    Promise.all([api('/api/products/' + id), api('/api/categories').catch(() => ({ categories: [] }))])
      .then(async ([d, cats]) => {
        if (!live) return;
        const p = d.product;
        const [sd, rel] = await Promise.all([
          api('/api/stores/' + p.store_id).catch(() => ({ store: {}, reviews: [] })),
          api('/api/products?category_id=' + p.category_id).catch(() => ({ products: [] })),
        ]);
        setSt({
          p, store: sd.store || {},
          reviews: sd.reviews || [],
          related: (rel.products || []).filter(x => x.id !== p.id).slice(0, 12),
          same: (sd.products || []).filter(x => x.id !== p.id).slice(0, 12),
        });
      }).catch(e => notify(e.message, 'err'));
    if (token) {
      api('/api/customer/favorites').then(f => {
        const ids = ((f.products || []).map(x => x.id));
        setIsFav(ids.includes(+id));
      }).catch(() => {});
    }
    return () => { live = false; };
  }, [id]);

  const { p, store, reviews, related, same } = st;
  const imgs = useMemo(() => {
    const list = ((p && p.images) || []).map(String).filter(Boolean);
    return list.length ? list : (p && p.image ? [p.image] : []);
  }, [p]);

  if (!p) return <div className="sect"><Loader /></div>;

  const variants = p.variants || [];
  const distinct = [...new Set(variants.map(v => v.color || ''))];
  const rows = selColor ? variants.filter(v => (v.color || '') === selColor) : [];
  const noColor = distinct.length === 1 && distinct[0] === '';
  const sizeRows = noColor ? variants : rows;
  const selVariant = (noColor && selSize >= 0 && selSize < variants.length) ? variants[selSize]
    : (!noColor && selSize >= 0 && selSize < rows.length) ? rows[selSize] : null;
  const ready = !variants.length || (noColor ? selSize >= 0 : selColor && selSize >= 0);
  const stock = selVariant ? (selVariant.stock || 0) : (p.stock || 0);
  const off = p.has_offer ? pct(p.price, p.offer_price) : 0;
  const price = p.has_offer ? p.offer_price : p.price;
  const display = price * qty;

  const doFav = async () => {
    if (!token) { setLoginOpen(true); return; }
    try {
      const d = await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: p.id }) });
      setIsFav(d.favorite === true);
      refreshFav();
      notify(d.favorite ? 'انضاف للمفضلة ❤️' : 'انحذف من المفضلة', 'ok');
    } catch (e) { notify(e.message, 'err'); }
  };

  const share = async () => {
    const msg = `شوف هذا المنتج على زبون 🛍️\n${p.name} — ${fmt(price)}\n${location.origin}${location.pathname}${location.hash}`;
    try { if (navigator.share) await navigator.share({ title: p.name, text: msg }); else { await navigator.clipboard.writeText(msg); notify('نُسخ رابط المنتج ✓', 'ok'); } } catch (e) {}
  };

  const add = async () => {
    if (p.out_of_stock || (variants.length && !ready)) return;
    setBusy(true);
    await addToCart(p.id, selVariant ? selVariant.id : null, selVariant ? (noColor ? selVariant.name : `${selColor} · ${selVariant.name}`) : null, qty);
    setBusy(false);
  };

  const nudge = (e) => {
    if (e.target === e.currentTarget) {
      if (startX.current != null) {
        const dx = e.clientX - startX.current;
        if (Math.abs(dx) > 40) setImgIdx(Math.max(0, Math.min(imgs.length - 1, imgIdx + (dx < 0 ? 1 : -1))));
        startX.current = null;
      } else startX.current = e.clientX;
    }
  };

  return (
    <div className="pg">
      <div className="pg-img" onMouseDown={nudge} onMouseUp={nudge}>
        {imgs.length ? <img src={imgs[imgIdx]} alt={p.name} onClick={() => setImgIdx((imgIdx + 1) % imgs.length)} style={{ cursor: 'zoom-in' }} onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>🛍️</span>}
        {imgs.length > 1 ? (
          <div className="pg-dots">
            {imgs.map((_, i) => <i key={i} className={i === imgIdx ? 'on' : ''} onClick={() => setImgIdx(i)} style={{ cursor: 'pointer' }} />)}
          </div>
        ) : null}
      </div>

      <div className="pg-bar">
        <button className="i-btn" onClick={() => nav(-1)}><M n="arrow_back_ios_new" s={17} w={600} /></button>
        <span className="sp" />
        <button className="i-btn" onClick={share}><M n="share" s={17} w={600} /></button>
        <button className="i-btn" onClick={doFav} style={{ color: isFav ? 'var(--danger)' : 'var(--ink)' }}>
          <M n="favorite" fill={isFav} s={18} c={isFav ? 'var(--danger)' : 'currentColor'} w={600} />
        </button>
      </div>

      <div className="pg-in">
        <div className="pg-store">{store.name} <M n="verified" s={14} c="var(--primary)" fill w={500} /></div>
        <div className="pg-name">{p.name}</div>
        <div className="pg-price-row">
          <span className="pg-price">{fmt(price)}</span>
          {off ? <span className="pg-badge">خصم {off}%</span> : null}
        </div>
        <div className="pg-old-row">
          {p.has_offer ? <span className="pg-old">{fmt(p.price)}</span> : null}
          {p.has_offer ? <span className="pg-save">وفّرت {fmt(Math.max(0, p.price - price))} 🎉</span> : null}
          <span className={`pg-stock ${p.out_of_stock ? 'bad' : 'ok'}`}>{p.out_of_stock ? '● نفد المخزون' : selVariant ? `● متوفر: ${selVariant.stock}` : `● متوفر الآن · المخزون ${stock}`}</span>
        </div>

        {/* بوكس المتجر */}
        <div className="pg-box pg-storebox">
          <div className="pg-logo">{store.logo ? <img src={store.logo} alt="" /> : '🏪'}</div>
          <div style={{ minWidth: 0 }}>
            <span className="pg-sn">{store.name} {store.verified ? <M n="verified" s={15} c="var(--primary)" fill /> : null}</span>
            <div className="pg-sr">
              <M n="star" fill s={14} c="var(--star)" w={700} />
              <span>{Number(store.rating || 0) > 0 ? Number(store.rating).toFixed(1) : 'جديد'} · {store.reviews_count || 0} تقييم</span>
              {store.is_open ? <span style={{ color: 'var(--success)', display: 'inline-flex', alignItems: 'center', gap: 3 }}><i style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--success)', display: 'inline-block' }} />مفتوح الآن</span> : null}
            </div>
          </div>
          <button className="pg-gobtn" onClick={() => nav('/stores/' + p.store_id)}>المتجر</button>
        </div>

        {/* المتغيرات */}
        {variants.length ? (
          <div className="vbox">
            {!noColor ? (
              <>
                <div className="vlbl"><M n="palette" s={16} c="var(--primary)" w={600} />اختر اللون {selColor ? <span className="cur">{selColor}</span> : null}</div>
                <div className="v-wrap">
                  {distinct.map(c => (
                    <span key={c} className={`vc ${selColor === c ? 'on' : ''}`} onClick={() => { setSelColor(selColor === c ? '' : c); setSelSize(-1); }}>
                      <i className="vd" style={{ background: cd(c), borderColor: selColor === c ? '#fff' : 'var(--line2)' }} />{c || 'قياسي'}
                    </span>
                  ))}
                </div>
                <div className="vdiv" />
              </>
            ) : null}
            <div className="vlbl">
              <M n="straighten" s={16} c="var(--primary)" w={600} />اختر المقاس
              <span className="cur" style={{ cursor: 'pointer' }} onClick={() => setGuide(true)}><M n="table_chart" s={14} c="var(--primary)" w={600} /> دليل المقاسات والقياسات 📐</span>
            </div>
            <div className="v-wrap">
              {sizeRows.map((v, i) => (
                <span key={v.id} className={`vs ${selSize === i ? 'on' : ''}`} onClick={() => !(v.stock === 0) && setSelSize(selSize === i ? -1 : i)}>
                  <span className="t">{v.name}</span>
                  <span className={v.stock === 0 ? 'st no' : 'st'}>{v.stock === 0 ? 'نفد' : `${v.stock} متوفر`}</span>
                </span>
              ))}
            </div>
            {ready && selVariant ? (
              <div className="vsel">
                <span className="t">التركيبة المختارة ✓</span>
                <span className="c">{selVariant.color || selVariant.name}{!noColor && selVariant.color ? ' · ' + selVariant.name : ''}</span>
                <span className="stk">متوفر: {selVariant.stock}</span>
              </div>
            ) : null}
          </div>
        ) : null}

        {/* خدمات التوصيل */}
        <div className="pg-box serv">
          <div><div className="e">🚚</div><div className="t">توصيل{"\n"}30-60 دقيقة</div><div className="s">داخل الكوت</div></div>
          <div><div className="e">💵</div><div className="t">كاش عند{"\n"}الاستلام</div><div className="s">ادفع بعد المشاهدة</div></div>
          <div><div className="e">🔄</div><div className="t">استرجاع{"\n"}خلال {store.warranty_days ?? 3} أيام</div><div className="s">ضمان المتجر</div></div>
        </div>

        {/* التفاصيل والمواصفات */}
        <div style={{ marginTop: 20 }}>
          <div className="sst" style={{ padding: 0 }}><span className="sst-t">التفاصيل والمواصفات</span></div>
          <div className="pg-box" style={{ marginTop: 10 }}>
            {Object.entries(p.attributes || {}).filter(([k]) => !['size', 'color'].includes(k)).length ? (
              <div className="specs">
                {Object.entries(p.attributes).filter(([k]) => !['size', 'color'].includes(k)).map(([k, v]) => (
                  <span key={k} className="spec"><span className="k">{EMO[k] || '🔹'} {ATTR[k] || k}: </span><span className="v">{v}</span></span>
                ))}
              </div>
            ) : <div style={{ textAlign: 'center', padding: '12px 0', fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>وصف المتجر الكامل متوفر فوق — التفاصيل الإضافية قريباً</div>}
            <div className="vdiv" style={{ margin: '12px 0 6px' }} />
            <div style={{ display: 'flex', gap: 10 }}>
              <span style={{ fontSize: 12.5, color: 'var(--muted)', fontWeight: 800 }}>الوصف:</span>
              <span style={{ fontSize: 12.5, lineHeight: 1.7, fontWeight: 600, color: 'var(--ink)' }}>{p.description || `منتج من ${store.name || ''}`}</span>
            </div>
          </div>
        </div>

        {/* التقييمات */}
        <div style={{ marginTop: 22 }}>
          <div className="sst" style={{ padding: 0 }}>
            <span className="sst-t">⭐ التقييمات والمراجعات</span>
            {Number(store.rating || 0) > 0 ? <span style={{ color: '#FBBF24', fontWeight: 900, fontSize: 14 }}>{Number(store.rating).toFixed(1)} ★</span> : null}
          </div>
          {!reviews.length ? (
            <div className="pg-box" style={{ textAlign: 'center', padding: '20px 0', marginTop: 10 }}>
              <div style={{ fontSize: 12, color: 'var(--muted)' }}>لا تقييمات بعد — كن أول من يقيّم هذا المتجر</div>
            </div>
          ) : reviews.slice(0, 4).map(r => (
            <div key={r.id} className="rv">
              <div className="rvn"><Stars n={r.rating} size={13} /> {r.user_name || 'زبون'}</div>
              <div className="rvt">{r.comment}</div>
              <div className="rvd">{timeAgo(r.created_at)}</div>
            </div>
          ))}
        </div>

        {/* ذات صلة */}
        {related.length ? (
          <div style={{ marginTop: 22 }}>
            <div className="sst" style={{ padding: 0 }}><span className="sst-t">منتجات ذات صلة ⚡</span></div>
            <div className="grid" style={{ paddingInline: 0, marginTop: 8 }}>
              {related.slice(0, 6).map(x => <RelatedCard key={x.id} p={x} />)}
            </div>
          </div>
        ) : null}
        {same.length ? (
          <div style={{ marginTop: 22 }}>
            <div className="sst" style={{ padding: 0 }}><span className="sst-t">منتجات من نفس المحل</span></div>
            <div className="grid" style={{ paddingInline: 0, marginTop: 8 }}>
              {same.slice(0, 6).map(x => <RelatedCard key={x.id} p={x} />)}
            </div>
          </div>
        ) : null}
        <div style={{ height: 170 }} />
      </div>

      {/* الشريط السفلي الثابت */}
      <div className="pg-foot">
        <div className="qty">
          <button onClick={() => setQty(Math.max(1, qty - 1))}><M n="remove" s={17} w={600} /></button>
          <b>{qty}</b>
          <button className="plus" onClick={() => setQty(Math.min(20, qty + 1))}><M n="add" s={17} w={600} /></button>
        </div>
        <button className="btn pg-add" disabled={p.out_of_stock || (variants.length && !ready) || busy} onClick={add}>
          {p.out_of_stock ? 'غير متوفر' : variants.length && !ready ? 'اختر اللون والمقاس أولاً 👆' : `أضف للسلة · ${fmt(display)}`}
        </button>
      </div>

      {/* دليل المقاسات */}
      {guide ? (
        <>
          <div className="overlay" style={{ zIndex: 105 }} onClick={() => setGuide(false)} />
          <div style={{ position: 'fixed', inset: 0, zIndex: 105, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', pointerEvents: 'none' }}>
            <div className="sheet" style={{ pointerEvents: 'auto', width: 'min(580px,100vw)' }}>
              <div className="sheet-head"><b>دليل المقاسات والقياسات 📐</b><button className="i-btn" onClick={() => setGuide(false)}><M n="close" s={20} /></button></div>
              <SizeTable variants={variants} />
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}

function RelatedCard({ p }) {
  const nav = useNavigate();
  return (
    <div className="pc" onClick={() => nav('/product/' + p.id)}>
      <div className="pc-img">
        {p.image ? <img src={p.image} alt="" loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : <span>🛍️</span>}
        {p.has_offer ? <span className="pc-badge">خصم {pct(p.price, p.offer_price)}%</span> : null}
      </div>
      <div className="pc-in">
        <div className="pc-n">{p.name}</div>
        {p.has_offer ? <div className="pc-old">{fmt(p.price)}</div> : null}
        <div className="pc-row"><span className="pc-p">{fmt(p.has_offer ? p.offer_price : p.price)}</span></div>
      </div>
    </div>
  );
}

function SizeTable({ variants }) {
  const letterSizes = [...new Set(variants.map(v => String(v.name || '').toUpperCase()).filter(s => CHART[s]))];
  return (
    <div>
      {letterSizes.length ? (
        <>
          <div style={{ fontSize: 12, fontWeight: 800, color: 'var(--muted)' }}>💡 حسب القياسات التقريبية الشائعة (بشكل اعتمدها المتجر):</div>
          <table style={{ width: '100%', borderCollapse: 'collapse', margin: '8px 0', fontSize: 11, border: '1px solid var(--line)' }}>
            <thead><tr style={{ background: 'var(--bg)' }}>{['المقاس', 'الصدر (سم)', 'الخصر (سم)', 'الطول (سم)'].map(h => <th key={h} style={{ padding: 9, border: '1px solid var(--line)', fontWeight: 900 }}>{h}</th>)}</tr></thead>
            <tbody>
              {letterSizes.map(s => (
                <tr key={s}><td style={{ padding: 8, border: '1px solid var(--line)', fontWeight: 900, textAlign: 'center' }}>{s}</td>
                  {CHART[s].map(m => <td key={m} style={{ padding: 8, border: '1px solid var(--line)', textAlign: 'center' }}>{m}</td>)}</tr>
              ))}
            </tbody>
          </table>
          <div style={{ fontSize: 9.5, color: 'var(--muted)', fontWeight: 600 }}>* قيم تقريبية — قد تختلف بين المصنّعين، والمتجر يحدد المقاس المناسب عند الاستلام.</div>
        </>
      ) : null}
      <div style={{ fontSize: 12, fontWeight: 800, color: 'var(--muted)', margin: '10px 0 6px' }}>مقاسات المتوفر حالياً وحالة المخزون:</div>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 11.5, border: '1px solid var(--line)' }}>
        <thead><tr style={{ background: 'var(--bg)' }}>{['المقاس', 'المتوفر', 'الحالة'].map(h => <th key={h} style={{ padding: 9, border: '1px solid var(--line)', fontWeight: 900 }}>{h}</th>)}</tr></thead>
        <tbody>
          {variants.map(v => (
            <tr key={v.id}>
              <td style={{ padding: 8, border: '1px solid var(--line)', fontWeight: 800, textAlign: 'center' }}>{v.name}</td>
              <td style={{ padding: 8, border: '1px solid var(--line)', textAlign: 'center' }}>{v.stock}</td>
              <td style={{ padding: 8, border: '1px solid var(--line)', textAlign: 'center' }}>
                <span className={`pill ${(v.stock || 0) > 0 ? 'pill-ok' : 'pill-err'}`}>{(v.stock || 0) > 0 ? 'متوفر' : 'نفد'}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="pg-box" style={{ marginTop: 12 }}>
        <b style={{ fontSize: 12, color: 'var(--primary)' }}>📏 كيف تقيس بشكل صحيح؟</b>
        <div style={{ fontSize: 11, lineHeight: 1.9 }}>• الصدر: محيط أوسع نقطة تحت الإبط<br />• الخصر: أنحف نقطة فوق السرة<br />• الطول: من الكتف حتى نهاية الثوب — وقارنها بالجدول</div>
      </div>
      <div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 700, textAlign: 'center', marginTop: 10 }}>مقاس غير مناسب؟ اضغط أي مقاس بأعلى الصفحة وسيُحفظ اختيارك تلقائياً 👌</div>
    </div>
  );
}