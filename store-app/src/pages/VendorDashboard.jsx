import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';
import { api, fmt, priceOf, timeAgo } from '../api';
import { M, Modal, Empty, Loader } from '../ui';


/* ═══════════════ لوحة التاجر — ويب ═══════════════ */
const STAT = {
  new: ['جديد', 'st-new'], preparing: ['قيد التحضير', 'st-pending'], ready: ['جاهز', 'st-ready'],
  delivering: ['بالتوصيل', 'st-delivering'], delivered: ['تم التسليم', 'st-delivered'],
  cancelled: ['ملغي', 'st-cancelled'], returned: ['مرتجع', 'st-returned'],
};
const cls = (s) => 'c-chip ' + (STAT[s] || ['', ''])[1];

const TABS = [
  ['overview', 'dashboard', 'نظرة عامة'],
  ['orders', 'receipt_long', 'الطلبات'],
  ['products', 'inventory_2', 'المنتجات'],
  ['wallet', 'account_balance_wallet', 'المحفظة'],
  ['store', 'storefront', 'متجري'],
  ['coupons', 'confirmation_number', 'الكوبونات'],
  ['refunds', 'assignment_return', 'الإرجاعات'],
  ['questions', 'quiz', 'الأسئلة'],
];

export default function VendorDashboard() {
  const { me, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [tab, setTab] = useState('overview');
  const [store, setStore] = useState(null);
  const [stats, setStats] = useState(null);
  const [week, setWeek] = useState(null);
  const [products, setProducts] = useState([]);
  const [refunds, setRefunds] = useState([]);
  const [wallet, setWallet] = useState(null);
  const [tx, setTx] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(null);
  const [showForm, setShowForm] = useState(false);

  const isVendor = me && me.roles && me.roles.includes('vendor');

  const reload = async () => {
    try {
      const [s, st, w, wk] = await Promise.all([
        api('/api/vendor/store'),
        api('/api/vendor/stats'),
        api('/api/vendor/wallet'),
        api('/api/vendor/week-earnings'),
      ]);
      setStore(s.store); setProducts(s.store ? s.store.products || [] : []);
      setRefunds(s.store ? s.store.refunds || [] : []);
      setStats(st.stats); setWallet(w.wallet); setTx(w.transactions || []);
      setWeek(wk);
    } catch (e) { notify(e.message, 'err'); } finally { setLoading(false); }
  };

  const { notify } = useApp();
  useEffect(() => { if (isVendor) reload(); else setLoading(false); }, [isVendor]);
  useEffect(() => { if (isVendor) { const t = setInterval(reload, 30000); return () => clearInterval(t); } }, [isVendor]);

  if (!isVendor) {
    return <div className="sect">
      <Empty icon="🧑💼" msg="هذه المنطقة للتجار فقط"
        sub={me ? 'حسابك مو مفعّل كتاجر — تواصل مع الإدارة' : 'سجّل دخولك بحساب التاجر أول'}
        action={<button className="btn" onClick={() => me ? nav('/') : setLoginOpen(true)}>{me ? 'عودة للمتجر' : 'دخول'}</button>} />
    </div>;
  }
  if (loading) return <div className="sect"><Loader /></div>;

  return (
    <div className="sect">
      <div className="dash-head">
        <div>
          <div className="dash-title">{store ? store.name : 'واجهة التاجر'}{store && store.verified ? <M n="verified" fill s={18} c="var(--accent)" /> : null}</div>
          <div className="dash-sub">{store ? `${store.category_name || ''} · ${store.district_name || ''} · ${STAT[store.status] ? STAT[store.status][0] : store.status}` : 'سجّل متجرك من صفحة متجري'}</div>
        </div>
        <div className="dash-btns">
          {store && <span className={'c-chip ' + (store.on_vacation ? 'st-cancelled' : 'st-delivered')}>{store.on_vacation ? 'في إجازة' : 'فاتح'}</span>}
        </div>
      </div>

      <div className="tabs dash-tabs">
        {TABS.map(([k, ic, l]) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>
            <M n={ic} s={17} />{l}
            {k === 'orders' && stats && stats.new_orders > 0 ? <span className="badge">{stats.new_orders}</span> : null}
          </button>
        ))}
      </div>

      {tab === 'overview' && <Overview store={store} stats={stats} week={week} products={products} goto={setTab} />}
      {tab === 'orders' && <OrdersTab reload={reload} notify={notify} />}
      {tab === 'products' && <ProductsTab products={products} reload={reload} notify={notify} setEditing={(p) => { setEditing(p); setShowForm(true); }} showForm={showForm} editing={editing} onClose={() => setShowForm(false)} />}
      {tab === 'wallet' && <WalletTab wallet={wallet} tx={tx} week={week} reload={reload} notify={notify} />}
      {tab === 'store' && <StoreTab store={store} reload={reload} notify={notify} />}
      {tab === 'coupons' && <CouponsTab notify={notify} />}
      {tab === 'refunds' && <RefundsTab refunds={refunds} reload={reload} notify={notify} />}
      {tab === 'questions' && <QuestionsTab notify={notify} />}
    </div>
  );
}

/* ══════════ نظرة عامة ══════════ */
function Overview({ store, stats, week, products, goto }) {
  const cards = [
    ['receipt_long', 'طلبات اليوم', stats ? stats.today_orders : 0, 'var(--primary)'],
    ['payments', 'مبيعات اليوم', stats ? fmt(stats.today_sales) : 0, 'var(--success)'],
    ['monitoring', 'طلبات جديدة', stats ? stats.new_orders : 0, 'var(--danger)'],
    ['inventory_2', 'المنتجات', products.length, 'var(--warning)'],
  ];
  return (
    <>
      <div className="stat" style={{ gridTemplateColumns: 'repeat(2,1fr)' }}>
        {cards.map(([ic, l, v, c]) => (
          <div key={l} className="grid-item">
            <span className="gi-ic" style={{ background: c + '1a', color: c }}><M n={ic} /></span>
            <h4>{v}</h4><p>{l}</p>
          </div>
        ))}
      </div>
      <div className="card" style={{ margin: '14px 16px 0', padding: 16 }}>
        <div className="card-h"><M n="calendar_today" s={18} c="var(--success)" />مستحقاتك هذا الأسبوع</div>
        <div style={{ fontSize: 24, fontWeight: 900, color: 'var(--success)', marginTop: 6 }}>
          {week ? fmt(week.net_due) : '—'}
        </div>
        <div className="muted-l" style={{ marginTop: 2 }}>بعد خصم عمولة المنصة ({store ? store.commission_rate : 10}%)</div>
        <div className="mini-row">
          <span>إجمالي المبيعات: <b>{week ? fmt(week.gross) : '—'}</b></span>
          <span>عمولة المنصة: <b style={{ color: 'var(--danger)' }}>{week ? '−' + fmt(week.commission_due) : '—'}</b></span>
        </div>
      </div>
      <Empty icon="📈" msg="التقارير التفصيلية تظهر هنا قريباً"
        action={<button className="btn btn-sm btn-o" style={{ marginTop: 10 }} onClick={() => goto('orders')}>شوف طلباتك ←</button>} />
    </>
  );
}

/* ══════════ الطلبات ══════════ */
function OrdersTab({ reload, notify: toast }) {
  const [orders, setOrders] = useState([]);
  const [status, setStatus] = useState('all');
  const [openId, setOpenId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [reason, setReason] = useState('');

  const load = async () => {
    try {
      const d = await api('/api/vendor/orders?status=' + status);
      setOrders(d.orders || []);
    } catch (e) { toast(e.message, 'err'); } finally { setLoading(false); }
  };
  useEffect(() => { load(); }, [status]);

  const act = async (id, action) => {
    try {
      await api(`/api/vendor/orders/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status: action, reason }) });
      toast(action === 'reject' ? 'انرفض الطلب' : action === 'accept' ? 'قبلت الطلب — صار قيد التحضير' : 'الطلب جاهز 🛵', 'ok');
      setReason(''); load(); reload();
    } catch (e) { toast(e.message, 'err'); }
  };

  if (loading) return <Loader />;
  return (
    <>
      <div className="tabs" style={{ margin: '10px 16px 6px' }}>
        {['all', 'new', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled', 'returned'].map(s => (
          <button key={s} className={status === s ? 'on' : ''} onClick={() => setStatus(s)}>
            {s === 'all' ? 'الكل' : STAT[s][0]}
          </button>
        ))}
      </div>
      {orders.length === 0
        ? <Empty icon="🧾" msg="لا طلبات بهذه الحالة" />
        : orders.map(o => (
          <div key={o.id} className="card ord-card">
            <div className="ord-top" onClick={() => setOpenId(openId === o.id ? null : o.id)}>
              <div>
                <b>#{o.code}</b>
                <span className="muted-l"> · {timeAgo(o.created_at)} · {o.user_name}</span>
                <div className="muted-l">{o.items.length} منتج · {fmt(o.total)}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className={cls(o.status)}>{STAT[o.status][0]}</span>
                <M n={openId === o.id ? 'expand_less' : 'expand_more'} s={20} c="var(--muted)" />
              </div>
            </div>
            {openId === o.id && (
              <div className="ord-body">
                {o.items.map(it => (
                  <div key={it.id} className="mini-row">
                    <span>{it.name}{it.variant_label ? ` (${it.variant_label})` : ''} × {it.qty}</span>
                    <b>{fmt(it.price * it.qty)}</b>
                  </div>
                ))}
                <div className="mini-row"><span>رسوم التوصيل</span><b>{fmt(o.delivery_fee || 0)}</b></div>
                <div className="mini-row ord-total"><span>الإجمالي</span><b style={{ color: 'var(--accent)' }}>{fmt(o.total)}</b></div>
                <div className="muted-l" style={{ margin: '8px 0' }}>الزبون: {o.user_phone || ''} · {o.address_text || ''}</div>
                {['new', 'preparing'].includes(o.status) && (
                  <div className="ord-actions">
                    {o.status === 'new' && (
                      <>
                        <button className="btn btn-sm" onClick={() => act(o.id, 'accept')}>قبول ✓</button>
                        <button className="btn btn-sm btn-o-err" onClick={() => act(o.id, 'reject')}>رفض ✕</button>
                        <input className="inp" style={{ marginTop: 8, padding: 8, fontSize: 12 }} placeholder="سبب الرفض (اختياري)" value={reason} onChange={e => setReason(e.target.value)} />
                      </>
                    )}
                    {o.status === 'preparing' && <button className="btn btn-sm btn-sun" onClick={() => act(o.id, 'ready')}>جهّز الطلب — جاهز للتوصيل 🛵</button>}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
    </>
  );
}

/* ══════════ المنتجات ══════════ */
function ProductsTab({ products, reload, notify: toast, setEditing, showForm, editing, onClose }) {
  return (
    <>
      <div className="dash-actions">
        <span className="muted-l">{products.length} منتج</span>
        <button className="btn btn-sm" onClick={() => setEditing(null)}><M n="add" s={17} />إضافة منتج</button>
      </div>
      {products.length === 0
        ? <Empty icon="📦" msg="ما عندك منتجات بعد" action={<button className="btn btn-sm" style={{ marginTop: 10 }} onClick={() => setEditing(null)}>أول منتج +</button>} />
        : <div className="dash-products">
          {products.map(p => <ProductRow key={p.id} p={p} reload={reload} toast={toast} onEdit={() => setEditing(p)} />)}
        </div>}
      {showForm && <ProductForm product={editing} onClose={onClose} reload={reload} toast={toast} />}
    </>
  );
}

const IMG = ({ src, size = 46 }) => src && (src.startsWith('data:') || src.startsWith('/') || src.startsWith('http'))
  ? <img className="pimg" src={src} style={{ width: size, height: size }} alt="" />
  : <span className="pimg" style={{ width: size, height: size, fontSize: 22 }}>{src || '📦'}</span>;

function ProductRow({ p, reload, toast, onEdit }) {
  const [busy, setBusy] = useState(false);
  const del = async () => {
    if (!confirm('تتحذف المنتج نهائياً؟')) return;
    setBusy(true);
    try { await api('/api/vendor/products/' + p.id, { method: 'DELETE' }); toast('انحذف المنتج', 'ok'); reload(); }
    catch (e) { toast(e.message, 'err'); } finally { setBusy(false); }
  };
  const toggleOffer = async () => {
    try {
      await api(`/api/vendor/products/${p.id}/offer`, { method: 'POST', body: JSON.stringify({ percent: p.has_offer ? 0 : 15 }) });
      toast(p.has_offer ? 'أزلت العرض' : 'فعّلت عرض 15% 🔥', 'ok'); reload();
    } catch (e) { toast(e.message, 'err'); }
  };
  return (
    <div className="card prod-row">
      <IMG src={p.image} />
      <div className="prod-info">
        <b>{p.name}</b>
        <div className="muted-l">{p.variants ? p.variants.length : 0} متغير · مخزون {p.stock ?? 0}</div>
        {p.has_offer
          ? <div><s className="muted-l">{fmt(p.price)}</s> <b style={{ color: 'var(--accent)' }}>{fmt(priceOf(p))}</b></div>
          : <b>{fmt(p.price)}</b>}
      </div>
      <div className="prod-acts">
        <button className="btn btn-sm btn-o" onClick={onEdit}><M n="edit" s={16} />تعديل</button>
        <button className="btn btn-sm btn-o" onClick={toggleOffer}>{p.has_offer ? 'إيقاف عرض' : 'عرض 🔥'}</button>
        <button className="btn btn-sm btn-o-err" disabled={busy} onClick={del}><M n="delete" s={16} /></button>
      </div>
    </div>
  );
}

/* نموذج إضافة/تعديل منتج */
function ProductForm({ product, onClose, reload, toast }) {
  const [f, setF] = useState({
    name: product?.name || '', price: product?.price || '', stock: product?.stock ?? 10,
    description: product?.description || '', offer: product?.has_offer ? product?.offer_price : '',
    category_id: product?.category_id ?? '',
  });
  const [variants, setVariants] = useState(
    (product?.variants || []).map(v => ({ id: v.id, color: v.color || '', name: v.name || '', stock: v.stock || 0 }))
  );
  const [imgs, setImgs] = useState((product?.images || (product?.image ? [product.image] : [])));
  const [cats, setCats] = useState([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => { api('/api/categories').then(d => setCats(d.categories || [])).catch(() => {}); }, []);

  const pick = async () => {
    const inp = document.createElement('input');
    inp.type = 'file'; inp.accept = 'image/*'; inp.multiple = true;
    inp.onchange = async () => {
      for (const file of inp.files) {
        const reader = new FileReader();
        reader.onload = async () => {
          const b64 = String(reader.result);
          try {
            const d = await api('/api/uploads/upload', { method: 'POST', body: JSON.stringify({ files: [b64] }) });
            if (d.urls && d.urls.length) setImgs(list => [...list, ...d.urls].slice(0, 8));
          } catch (e) { toast(e.message, 'err'); }
        };
        reader.readAsDataURL(file);
      }
    };
    inp.click();
  };

  const save = async () => {
    if (!f.name || !f.price) { toast('الاسم والسعر مطلوبين', 'err'); return; }
    const body = {
      name: f.name, price: Number(f.price), stock: Number(f.stock) || 0,
      description: f.description, category_id: f.category_id ? Number(f.category_id) : null,
      images: imgs,
      has_offer: f.offer !== '', offer_price: f.offer ? Number(f.offer) : 0,
      variants: variants.map(v => ({ id: v.id, color: v.color, name: v.name || 'قياسي', stock: Number(v.stock) || 0 })),
    };
    setBusy(true);
    try {
      if (product) await api('/api/vendor/products/' + product.id, { method: 'PATCH', body: JSON.stringify(body) });
      else await api('/api/vendor/products', { method: 'POST', body: JSON.stringify(body) });
      toast(product ? 'انعدّل المنتج ✓' : 'انضاف المنتج ✓', 'ok');
      onClose(); reload();
    } catch (e) { toast(e.message, 'err'); } finally { setBusy(false); }
  };

  return (
    <Modal open onClose={onClose} lg>
      <div className="modal-head">
        <b>{product ? 'تعديل المنتج' : 'إضافة منتج'}</b>
        <button className="i-btn" onClick={onClose}><M n="close" s={20} /></button>
      </div>
      <div className="modal-body">
        <div className="img-row">
          {imgs.map((u, i) => (
            <span key={i} className="img-tile">
              <img src={u} alt="" style={{ width: 64, height: 64, borderRadius: 10, objectFit: 'cover' }} />
              <button className="img-x" onClick={() => setImgs(l => l.filter((x, j) => j !== i))}><M n="close" s={12} /></button>
            </span>
          ))}
          {imgs.length < 8 && <button className="img-add" onClick={pick}><M n="add_a_photo" s={22} /><small>صور</small></button>}
        </div>
        <label className="muted-l">اسم المنتج *</label>
        <input className="inp" value={f.name} onChange={e => setF({ ...f, name: e.target.value })} />
        <div className="two-col">
          <div><label className="muted-l">السعر (د.ع) *</label><input className="inp" type="number" value={f.price} onChange={e => setF({ ...f, price: e.target.value })} /></div>
          <div><label className="muted-l">الكمية</label><input className="inp" type="number" value={f.stock} onChange={e => setF({ ...f, stock: e.target.value })} /></div>
        </div>
        <label className="muted-l">الوصف</label>
        <textarea className="inp" rows={2} value={f.description} onChange={e => setF({ ...f, description: e.target.value })} />
        <div className="two-col">
          <div>
            <label className="muted-l">القسم</label>
            <select className="inp" value={f.category_id} onChange={e => setF({ ...f, category_id: e.target.value })}>
              <option value="">بدون قسم</option>
              {cats.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
            </select>
          </div>
          <div><label className="muted-l">سعر العرض (اختياري)</label><input className="inp" type="number" value={f.offer} onChange={e => setF({ ...f, offer: e.target.value })} /></div>
        </div>

        <div className="card-h" style={{ marginTop: 14 }}>الألوان والمقاسات
          <button className="btn btn-sm" style={{ minHeight: 30, padding: '4px 10px' }}
            onClick={() => setVariants(v => [...v, { color: '', name: '', stock: 10 }])}>
            <M n="add" s={15} />صف
          </button>
        </div>
        {variants.map((v, i) => (
          <div key={i} className="v-row">
            <input className="inp" placeholder="اللون (أحمر/أسود)" value={v.color} onChange={e => setVariants(l => l.map((x, j) => j === i ? { ...x, color: e.target.value } : x))} />
            <input className="inp" placeholder="المقاس" value={v.name} onChange={e => setVariants(l => l.map((x, j) => j === i ? { ...x, name: e.target.value } : x))} />
            <input className="inp" type="number" placeholder="الكمية" value={v.stock} onChange={e => setVariants(l => l.map((x, j) => j === i ? { ...x, stock: e.target.value } : x))} />
            <button className="i-btn" onClick={() => setVariants(l => l.filter((x, j) => j !== i))}><M n="close" s={18} c="var(--danger)" /></button>
          </div>
        ))}

        <button className="btn btn-block" style={{ marginTop: 16 }} disabled={busy} onClick={save}>{busy ? 'حفظ...' : 'حفظ المنتج'}</button>
      </div>
    </Modal>
  );
}

/* ══════════ المحفظة ══════════ */
function WalletTab({ wallet, tx, week, reload, notify: toast }) {
  const [amount, setAmount] = useState('');
  const [adOpen, setAdOpen] = useState(false);
  const [pkg, setPkg] = useState(0);
  const [pkgs, setPkgs] = useState([]);
  const [adTxt, setAdTxt] = useState('');
  const [busy, setBusy] = useState(false);

  const openAd = async () => {
    try { const d = await api('/api/vendor/ad-packages'); setPkgs(d.packages || []); setPkg((d.packages?.[0]?.id) || 0); } catch (_) {}
    setAdOpen(true);
  };
  const withdraw = async () => {
    if (!Number(amount)) { toast('اكتب المبلغ أولاً', 'err'); return; }
    setBusy(true);
    try {
      await api('/api/vendor/wallet/withdraw', { method: 'POST', body: JSON.stringify({ amount: Number(amount) }) });
      toast('انرسل طلب السحب للأدمن ✓', 'ok'); setAmount(''); reload();
    } catch (e) { toast(e.message, 'err'); } finally { setBusy(false); }
  };
  const createAd = async () => {
    if (!adTxt.trim()) { toast('اكتب نص الإعلان', 'err'); return; }
    setBusy(true);
    try {
      await api('/api/vendor/ads', { method: 'POST', body: JSON.stringify({ title: adTxt, package_id: Number(pkg) }) });
      toast('تم تفعيل الإعلان 🚀', 'ok'); setAdOpen(false); setAdTxt(''); reload();
    } catch (e) { toast(e.message, 'err'); } finally { setBusy(false); }
  };

  return (
    <>
      <div className="card grad-navy card-glow" style={{ margin: '12px 16px 0', padding: 22, textAlign: 'center' }}>
        <div style={{ fontSize: 13, opacity: .85 }}>رصيد محفظتك</div>
        <div style={{ fontSize: 30, fontWeight: 900, margin: '6px 0' }}>{wallet ? fmt(wallet.balance) : '0'}</div>
        <div className="two-col">
          <button className="btn btn-sun btn-sm" disabled={busy} onClick={withdraw}><M n="payments" s={17} />سحب</button>
          <button className="btn btn-sm" style={{ background: 'rgba(255,255,255,.16)', boxShadow: 'none' }} onClick={openAd}><M n="campaign" s={17} />إعلان 📣</button>
        </div>
        {week && <div className="mini-row" style={{ marginTop: 12, justifyContent: 'center', gap: 18 }}>
          <span>أسبوعي: <b style={{ color: 'var(--success)' }}>{fmt(week.net_due)}</b></span>
        </div>}
      </div>
      <div className="card" style={{ margin: '14px 16px 0', padding: 14 }}>
        <div className="card-h">الحركات</div>
        {tx.length === 0 ? <Empty icon="🧾" msg="لا حركات بعد" /> : tx.map((t, i) => (
          <div key={i} className="mini-row" style={{ padding: '7px 0', borderBottom: '1px solid var(--line)' }}>
            <span><M n={t.type === 'credit' ? 'arrow_downward' : 'arrow_upward'} s={15} c={t.type === 'credit' ? 'var(--success)' : 'var(--danger)'} /> {t.note} <small className="muted-l">({timeAgo(t.created_at)})</small></span>
            <b style={{ color: t.type === 'credit' ? 'var(--success)' : 'var(--danger)' }}>{t.type === 'credit' ? '+' : '−'}{fmt(t.amount)}</b>
          </div>
        ))}
      </div>

      <Modal open={adOpen} onClose={() => setAdOpen(false)}>
        <div className="modal-head"><b>إعلان لمتجري 📣</b><button className="i-btn" onClick={() => setAdOpen(false)}><M n="close" s={20} /></button></div>
        <div className="modal-body">
          <label className="muted-l">نص الإعلان</label>
          <input className="inp" placeholder="مثال: خصم 50% هذا الأسبوع" value={adTxt} onChange={e => setAdTxt(e.target.value)} />
          <label className="muted-l" style={{ marginTop: 10, display: 'block' }}>الباقة</label>
          <select className="inp" value={pkg} onChange={e => setPkg(Number(e.target.value))}>
            {pkgs.map(p => <option key={p.id} value={p.id}>{p.days} أيام — {fmt(p.price)}</option>)}
          </select>
          <button className="btn btn-block btn-sun" style={{ marginTop: 14 }} disabled={busy} onClick={createAd}>ترويج الآن 🚀</button>
        </div>
      </Modal>
    </>
  );
}

/* ══════════ متجري ══════════ */
function StoreTab({ store, reload, notify: toast }) {
  const nav = useNavigate();
  const [editing, setEditing] = useState(false);
  if (!store) return <Empty icon="🏪" msg="سجل متجرك لتبدأ البيع" action={<button className="btn" style={{ marginTop: 10 }} onClick={() => nav('/stores')}>إنشاء متجر</button>} />;
  const vac = async (on) => {
    try { await api('/api/vendor/store/vacation', { method: 'POST', body: JSON.stringify({ on_vacation: on }) }); toast(on ? 'المتجر ويا إجازة' : 'رجع المتجر يشتغل', 'ok'); reload(); }
    catch (e) { toast(e.message, 'err'); }
  };
  const setOpen = async (on) => {
    try { await api('/api/vendor/store', { method: 'PATCH', body: JSON.stringify({ is_open: on }) }); toast('انحفظ', 'ok'); reload(); }
    catch (e) { toast(e.message, 'err'); }
  };
  return (
    <>
      {editing && <StoreEdit store={store} onClose={() => setEditing(false)} reload={reload} toast={toast} />}
      <div className="card" style={{ margin: '12px 16px 0', padding: 16 }}>
        <div className="store-line">
          <IMG src={store.logo || '🏪'} size={56} />
          <div className="prod-info">
            <b>{store.name}</b>
            <div className="muted-l">{store.category_name || ''} · {store.district_name || ''} · {store.address || ''} · {store.phone || ''}</div>
            <div className="muted-l">رسوم التوصيل: <b>{fmt(store.delivery_fee || 0)}</b> · عمولة المنصة: <b>{store.commission_rate}%</b></div>
          </div>
          <button className="btn btn-sm btn-o" onClick={() => setEditing(true)}><M n="edit" s={16} />تعديل</button>
        </div>
        <div className="two-col" style={{ marginTop: 12 }}>
          <button className="btn btn-sm btn-o" onClick={() => setOpen(!store.is_open)}>
            <M n={store.is_open ? 'storefront' : 'lock'} s={16} />{store.is_open ? 'المتجر مفتوح' : 'المتجر مغلق'}
          </button>
          <button className="btn btn-sm btn-o" onClick={() => vac(!store.on_vacation)}>
            <M n="beach_access" s={16} />{store.on_vacation ? 'رجوع من الإجازة' : 'إجازة المتجر 🏖'}
          </button>
        </div>
      </div>
      <Empty icon="🛠" msg="معلومات المتجر تُدار من هذا القسم" />
    </>
  );
}

/* تعديل المتجر */
function StoreEdit({ store, onClose, reload, toast }) {
  const [f, setF] = useState({ name: store.name || '', description: store.description || '', address: store.address || '', phone: store.phone || '', delivery_fee: store.delivery_fee || 2000, free_delivery_min: store.free_delivery_min || 50000 });
  const [busy, setBusy] = useState(false);
  const save = async () => {
    setBusy(true);
    try {
      await api('/api/vendor/store', { method: 'PATCH', body: JSON.stringify(f) });
      toast('انحفظت المعلومات ✓', 'ok'); onClose(); reload();
    } catch (e) { toast(e.message, 'err'); } finally { setBusy(false); }
  };
  return (
    <Modal open onClose={onClose}>
      <div className="modal-head"><b>تعديل المتجر</b><button className="i-btn" onClick={onClose}><M n="close" s={20} /></button></div>
      <div className="modal-body">
        <label className="muted-l">اسم المتجر</label><input className="inp" value={f.name} onChange={e => setF({ ...f, name: e.target.value })} />
        <label className="muted-l" style={{ marginTop: 8, display: 'block' }}>الوصف</label><textarea className="inp" rows={3} value={f.description} onChange={e => setF({ ...f, description: e.target.value })} />
        <label className="muted-l" style={{ marginTop: 8, display: 'block' }}>العنوان</label><input className="inp" value={f.address} onChange={e => setF({ ...f, address: e.target.value })} />
        <div className="two-col">
          <div><label className="muted-l">الهاتف</label><input className="inp" value={f.phone} onChange={e => setF({ ...f, phone: e.target.value })} /></div>
          <div><label className="muted-l">رسوم التوصيل</label><input className="inp" type="number" value={f.delivery_fee} onChange={e => setF({ ...f, delivery_fee: e.target.value })} /></div>
        </div>
        <button className="btn btn-block" style={{ marginTop: 14 }} disabled={busy} onClick={save}>{busy ? 'حفظ...' : 'حفظ'}</button>
      </div>
    </Modal>
  );
}

/* ══════════ الكوبونات ══════════ */
function CouponsTab({ notify: toast }) {
  const [list, setList] = useState([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [f, setF] = useState({ code: '', percent: '', flat: '', min_total: 0, max_discount: 0, uses_limit: 0 });
  const load = async () => {
    try { const d = await api('/api/vendor/coupons'); setList(d.coupons || []); }
    catch (e) { toast(e.message, 'err'); } finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);
  const del = async (id) => {
    if (!confirm('تحذف الكوبون؟')) return;
    try { await api('/api/vendor/coupons/' + id, { method: 'DELETE' }); load(); } catch (e) { toast(e.message, 'err'); }
  };
  const save = async () => {
    if (!f.code || (!f.percent && !f.flat)) { toast('الكود ونوع الخصم مطلوبين', 'err'); return; }
    try {
      await api('/api/vendor/coupons', { method: 'POST', body: JSON.stringify({
        code: f.code, percent: f.percent ? Number(f.percent) : null, flat: f.flat ? Number(f.flat) : null,
        min_total: Number(f.min_total) || 0, max_discount: Number(f.max_discount) || 0, uses_limit: Number(f.uses_limit) || 0,
      }) });
      toast('انضاف الكوبون ✓', 'ok'); setOpen(false); setF({ code: '', percent: '', flat: '', min_total: 0, max_discount: 0, uses_limit: 0 }); load();
    } catch (e) { toast(e.message, 'err'); }
  };
  if (loading) return <Loader />;
  return (
    <>
      <div className="dash-actions"><span className="muted-l">{list.length} كوبون</span>
        <button className="btn btn-sm" onClick={() => setOpen(true)}><M n="add" s={17} />كوبون جديد</button></div>
      {list.length === 0 ? <Empty icon="🏷" msg="ما عندك كوبونات" /> : list.map(c => (
        <div key={c.id} className="card mini-row" style={{ margin: '8px 16px 0', padding: 12 }}>
          <div>
            <b className="coupon-code">{c.code}</b>
            <span className="muted-l"> — {c.percent ? c.percent + '%' : fmt(c.flat)} خصم{c.min_total ? ` من ${fmt(c.min_total)}` : ''}{c.uses_left ? ` · متبقي ${c.uses_left}` : ''}{c.active ? '' : ' · متوقف'}</span>
          </div>
          <button className="i-btn" onClick={() => del(c.id)}><M n="delete" s={18} c="var(--danger)" /></button>
        </div>
      ))}
      <Modal open={open} onClose={() => setOpen(false)}>
        <div className="modal-head"><b>كوبون جديد</b><button className="i-btn" onClick={() => setOpen(false)}><M n="close" s={20} /></button></div>
        <div className="modal-body">
          <label className="muted-l">الكود (حروف إنجليزية)</label><input className="inp" value={f.code} onChange={e => setF({ ...f, code: e.target.value.toUpperCase() })} />
          <div className="two-col">
            <div><label className="muted-l">نسبة %</label><input className="inp" type="number" value={f.percent} onChange={e => setF({ ...f, percent: e.target.value })} /></div>
            <div><label className="muted-l">خصم ثابت</label><input className="inp" type="number" value={f.flat} onChange={e => setF({ ...f, flat: e.target.value })} /></div>
          </div>
          <div className="two-col">
            <div><label className="muted-l">حد أدنى للطلب</label><input className="inp" type="number" value={f.min_total} onChange={e => setF({ ...f, min_total: e.target.value })} /></div>
            <div><label className="muted-l">سقف الخصم</label><input className="inp" type="number" value={f.max_discount} onChange={e => setF({ ...f, max_discount: e.target.value })} /></div>
          </div>
          <label className="muted-l" style={{ marginTop: 8, display: 'block' }}>حد الاستخدام (0 = بلا حد)</label>
          <input className="inp" type="number" value={f.uses_limit} onChange={e => setF({ ...f, uses_limit: e.target.value })} />
          <button className="btn btn-block" style={{ marginTop: 14 }} onClick={save}>حفظ</button>
        </div>
      </Modal>
    </>
  );
}

/* ══════════ الإرجاعات ══════════ */
function RefundsTab({ refunds, reload, notify: toast }) {
  const [busy, setBusy] = useState(null);
  const decide = async (id, status) => {
    setBusy(id);
    try { await api('/api/vendor/refunds/' + id, { method: 'PATCH', body: JSON.stringify({ status }) }); toast(status === 'accepted' ? 'قبلت الطلب ✓' : 'رفضت الطلب', 'ok'); reload(); }
    catch (e) { toast(e.message, 'err'); } finally { setBusy(null); }
  };
  return (
    <>
      {refunds.length === 0 ? <Empty icon="🔄" msg="لا طلبات إرجاع حالياً" /> : refunds.map(r => (
        <div key={r.id} className="card mini-row" style={{ margin: '8px 16px 0', padding: 12, alignItems: 'flex-start' }}>
          <div>
            <b>#{r.code}</b> <span className="muted-l">— {r.type === 'exchange' ? 'استبدال 🔁' : 'إرجاع ↩️'} · {r.reason || ''}{r.desired ? ` · البديل: ${r.desired}` : ''}</span>
            <div className="muted-l">{r.user_name} · {fmt(r.total)} · {timeAgo(r.created_at)}</div>
          </div>
          {r.status === 'pending'
            ? <div className="prod-acts">
              <button className="btn btn-sm" disabled={busy === r.id} onClick={() => decide(r.id, 'accepted')}>قبول</button>
              <button className="btn btn-sm btn-o-err" disabled={busy === r.id} onClick={() => decide(r.id, 'rejected')}>رفض</button>
            </div>
            : <span className={r.status === 'accepted' ? 'c-chip st-delivered' : 'c-chip st-cancelled'}>{r.status === 'accepted' ? 'مقبول' : 'مرفوض'}</span>}
        </div>
      ))}
    </>
  );
}

/* ══════════ أسئلة الزبائن ══════════ */
function QuestionsTab({ notify: toast }) {
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [ans, setAns] = useState({});
  const load = async () => {
    try { const d = await api('/api/vendor/questions'); setList(d.questions || []); }
    catch (e) { toast(e.message, 'err'); } finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);
  const reply = async (id) => {
    if (!(ans[id] || '').trim()) { toast('اكتب الجواب أولاً', 'err'); return; }
    try { await api('/api/vendor/questions/' + id + '/answer', { method: 'POST', body: JSON.stringify({ answer: ans[id] }) }); toast('جاوبت السؤال ✓', 'ok'); load(); }
    catch (e) { toast(e.message, 'err'); }
  };
  if (loading) return <Loader />;
  return (
    <>
      {list.length === 0 ? <Empty icon="💬" msg="لا أسئلة معلقة" /> : list.map(qq => (
        <div key={qq.id} className="card" style={{ margin: '8px 16px 0', padding: 14 }}>
          <b>{qq.product_name}</b> <span className="muted-l">— {qq.user_name}</span>
          <p style={{ fontSize: 13, margin: '6px 0' }}>{qq.question}</p>
          <div className="two-col">
            <input className="inp" placeholder="جوابك..." value={ans[qq.id] || ''} onChange={e => setAns({ ...ans, [qq.id]: e.target.value })} />
            <button className="btn btn-sm" onClick={() => reply(qq.id)}>إرسال ✓</button>
          </div>
        </div>
      ))}
    </>
  );
}