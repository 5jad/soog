/* ═══════════ متجر زبون — المحرك ═══════════ */
const $ = (s) => document.querySelector(s);
const api = async (path, opts = {}) => {
  const h = { 'Content-Type': 'application/json' };
  if (localStorage.zaboon_token) h.Authorization = 'Bearer ' + localStorage.zaboon_token;
  const r = await fetch(path, { ...opts, headers: { ...h, ...(opts.headers || {}) } });
  let d = {};
  try { d = await r.json(); } catch (_) {}
  if (!r.ok) throw (d && d.error) ? new Error(d.error) : new Error('مشكلة اتصال بالسيرفر');
  return d;
};

const fmt = (n) => (Number(n) || 0).toLocaleString('ar-IQ') + ' د.ع';
const priceOf = (p) => (p.has_offer && p.offer_price) ? p.offer_price : p.price;
const U = (s) => s && s.startsWith('data:') ? s : (s && s.startsWith('/') ? s : null);

const LS = {
  get token() { return localStorage.zaboon_token || ''; },
  set token(v) { v ? localStorage.zaboon_token = v : delete localStorage.zaboon_token; },
  get me() { try { return JSON.parse(localStorage.zaboon_me || 'null'); } catch (_) { return null; } },
  set me(v) { v ? localStorage.zaboon_me = JSON.stringify(v) : delete localStorage.zaboon_me; },
};

const UI = {
  load(on = true) { $('#load').classList.toggle('hide', !on); },
  toast(msg, kind = '') {
    const t = $('#toast');
    t.textContent = msg; t.className = 'toast ' + kind;
    clearTimeout(this._tt);
    this._tt = setTimeout(() => t.classList.add('hide'), 3200);
  },
  img(im, size = '52px', font = '28px') {
    const u = U(im);
    if (u) return `<img src="${u}" onerror="this.outerHTML='<span style=\\'font-size:${font}\\'>🛍</span>'">`;
    return `<span style="font-size:${font}">${im || '🛍'}</span>`;
  },
  userMenu() {
    if (!LS.token) return this.openLogin();
    const pop = $('#userPop');
    const nm = LS.me ? LS.me.name : 'حسابي';
    $('#userName').textContent = nm;
    pop.classList.toggle('hide');
  },
  closeUser() { $('#userPop').classList.add('hide'); },
  openLogin() {
    this.renderLogin();
    $('#lmask').classList.remove('hide');
    $('#login').classList.remove('hide');
  },
  closeLogin() {
    $('#lmask').classList.add('hide');
    $('#login').classList.add('hide');
  },
  renderLogin() {
    $('#login').innerHTML = `
    <div class="box">
      <h2>${LS.token ? 'حسابك' : 'دخول إلى زبون'}</h2>
      <div class="tabs">
        <button class="on" id="t-login" onclick="UI.loginTab('login')">تسجيل دخول</button>
        <button id="t-reg" onclick="UI.loginTab('reg')">حساب جديد</button>
        <button id="t-otp" onclick="UI.loginTab('otp')">رمز سري</button>
      </div>
      <div id="lform"></div>
      <div class="lnote">
        تطبيق <b>زبون</b> للجوال أيضاً — حمّله من <a href="/download">الصفحة الرسمية</a>.
        <br><span id="otpNote"></span>
      </div>
    </div>`;
    this.loginTab('login');
  },
  loginTab(t) {
    ['login', 'reg', 'otp'].forEach(x => $('#t-' + x).classList.toggle('on', x === t));
    const F = (label, id, ph, type = 'text') => `<div class="lf"><label>${label}</label><input id="${id}" type="${type}" placeholder="${ph}" autocomplete="off"></div>`;
    if (t === 'login') {
      $('#lform').innerHTML = F('رقم الهاتف', 'lg-phone', '07701234567') + F('كلمة المرور', 'lg-pass', '••••••••', 'password') +
        `<button class="lbtn" onclick="AUTH.login()">دخول</button>`;
    } else if (t === 'reg') {
      $('#lform').innerHTML = F('الاسم الكامل', 'rg-name', 'اسمك') + F('رقم الهاتف', 'rg-phone', '07701234567') + F('كلمة المرور', 'rg-pass', '••••••••', 'password') +
        `<button class="lbtn amber" onclick="AUTH.register()">إنشاء الحساب</button>`;
    } else {
      $('#lform').innerHTML = F('رقم الهاتف', 'otp-phone', '07701234567') +
        `<button class="lbtn" onclick="AUTH.requestOtp()">أرسل لي الرمز</button>
         <div id="otp-sec" class="hide" style="margin-top:12px">
          ${F('رمز التحقق', 'otp-code', '●●●●', 'text')}
          ${F('كلمة مرور جديدة', 'otp-pass', '••••••••', 'password')}
          <button class="lbtn amber" onclick="AUTH.verifyOtp()">حفظ ودخول</button>
         </div>`;
      $('#otpNote').textContent = 'الرمز يوصلك عبر بوت التليجرام أو يظهر في تطبيق الجوال (الوضع التجريبي).';
    }
  },
  badge(id, n) { const b = $('#' + id); b.textContent = n; b.classList.toggle('hide', !n); },
};

const AUTH = {
  async save(d) {
    LS.token = d.token; LS.me = d.user || d.me || null;
    UI.closeLogin();
    this.refresh();
    APP.cartCount();
    UI.toast('مرحباً بك 👋', 'ok');
  },
  async login() {
    try {
      UI.load(true);
      const d = await api('/api/auth/login', { method: 'POST', body: JSON.stringify({ phone: $('#lg-phone').value.trim(), password: $('#lg-pass').value }) });
      await this.save(d);
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },
  async register() {
    try {
      UI.load(true);
      const d = await api('/api/auth/register', { method: 'POST', body: JSON.stringify({ name: $('#rg-name').value.trim(), phone: $('#rg-phone').value.trim(), password: $('#rg-pass').value }) });
      await this.save(d);
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },
  async requestOtp() {
    try {
      UI.load(true);
      const d = await api('/api/auth/request-otp', { method: 'POST', body: JSON.stringify({ phone: $('#otp-phone').value.trim() }) });
      $('#otp-sec').classList.remove('hide');
      const c = $('#otp-code');
      if (d.dev_code) { c.value = d.dev_code; UI.toast('رمز التجربة وُضع لك تلقائياً ✓', 'ok'); }
      else UI.toast(d.via === 'telegram' ? 'الرمز أرسل لتليجرامك ✓' : 'الرمز أرسل ✓', 'ok');
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },
  async verifyOtp() {
    try {
      UI.load(true);
      const d = await api('/api/auth/reset-password', { method: 'POST', body: JSON.stringify({
        phone: $('#otp-phone').value.trim(), code: $('#otp-code').value.trim(), new_password: $('#otp-pass').value }) });
      await this.save(d);
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },
  logout() {
    LS.token = ''; LS.me = null;
    UI.badge('cartBadge', 0);
    UI.toast('خرجت من الحساب');
    APP.home();
  },
  refresh() {
    UI.closeUser();
    const u = $('#userBtn').querySelector('span');
    if (u) u.textContent = LS.me ? ' ' + LS.me.name.split(' ')[0] : '';
  },
};

const CART = {
  async load() {
    if (!LS.token) { UI.badge('cartBadge', 0); return []; }
    try { return (await api('/api/customer/cart')).items || []; }
    catch (_) { return []; }
  },
  async add(pid, variantId = null, label = null, qty = 1) {
    if (!LS.token) { UI.toast('سجّل دخولك أولاً', 'err'); UI.openLogin(); return false; }
    try {
      UI.load(true);
      const d = await api('/api/customer/cart', { method: 'POST', body: JSON.stringify({ product_id: pid, variant_id: variantId, variant_label: label, qty }) });
      UI.badge('cartBadge', d.count);
      UI.toast('أضيف للسلة ✓', 'ok');
      return true;
    } catch (e) { UI.toast(e.message, 'err'); return false; } finally { UI.load(false); }
  },
  async setQty(id, qty) {
    try { await api('/api/customer/cart/' + id, { method: 'PATCH', body: JSON.stringify({ qty }) }); await this.render(); }
    catch (e) { UI.toast(e.message, 'err'); }
  },
  async del(id) {
    try { await api('/api/customer/cart/' + id, { method: 'DELETE' }); await this.render(); }
    catch (e) { UI.toast(e.message, 'err'); }
  },
  async count() {
    if (!LS.token) return;
    try { const d = await api('/api/customer/cart'); UI.badge('cartBadge', d.items.reduce((a, b) => a + b.qty, 0)); }
    catch (_) {}
  },
  async render() {
    const items = await this.load();
    const groups = {};
    for (const it of items) (groups[it.store_id] = groups[it.store_id] || { name: it.store_name, logo: it.logo, fee: it.delivery_fee, free_min: it.free_delivery_min || 50000, items: [] }).items.push(it);
    const body = $('#cartBody');
    if (!items.length) {
      body.innerHTML = `<div class="empty"><span class="e">🛒</span>سلتك فاضية — ابدأ التسوق!</div>`;
      $('#cartFoot').classList.add('hide');
      return;
    }
    body.innerHTML = Object.values(groups).map(g => {
      const sub = g.items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
      const free = sub >= g.free_min;
      return `<div class="cgroup">
        <div class="cgroup-t">${UI.img(g.logo, '30px', '15px')} ${g.name}</div>
        ${g.items.map(it => `
          <div class="citem">
            <div class="img">${UI.img(it.image, '100%', '24px')}</div>
            <div class="c">
              <div class="n">${it.name}</div>
              ${it.variant ? `<div class="v">${it.variant}</div>` : ''}
              <div class="row">
                <div class="q">
                  <button onclick="CART.setQty(${it.id}, ${it.qty + 1})">+</button><b>${it.qty}</b>
                  <button onclick="CART.setQty(${it.id}, ${it.qty - 1})">−</button>
                </div>
                <div class="p">${fmt(priceOf(it) * it.qty)}</div>
                <button class="del" onclick="CART.del(${it.id})">حذف</button>
              </div>
            </div>
          </div>`).join('')}
        <div class="cgroup-s">التوصيل ${free ? '<b>مجاني ✓</b>' : fmt(g.fee)} ${free ? '' : `(مجاني عند ${fmt(g.free_min)})`}</div>
      </div>`;
    }).join('');
    const total = items.reduce((a, b) => a + priceOf(b) * b.qty, 0);
    const fees = Object.values(groups).reduce((a, g) => a + (g.items.reduce((s, b) => s + priceOf(b) * b.qty, 0) >= g.free_min ? 0 : g.fee), 0);
    $('#cartFoot').classList.remove('hide');
    $('#cartFoot').innerHTML = `<div class="tot"><span>الإجمالي</span><span>${fmt(total + fees)}</span></div>
      <button onclick="APP.checkout()">إتمام الطلب ←</button>`;
  },
  open() { this.render(); $('#cart').classList.add('open'); $('#cartOverlay').classList.remove('hide'); },
  close() { $('#cart').classList.remove('open'); $('#cartOverlay').classList.add('hide'); },
};

const APP = {
  cur: 'home',
  catSel: null,
  state: { stores: [], products: [], best: [], offers: [], categories: [], ads: [] },

  async home() {
    this.cur = 'home';
    UI.load(true);
    try {
      const [st, pr, ca, ofF] = await Promise.all([
        api('/api/stores'), api('/api/products'), api('/api/categories'), api('/api/offers'),
      ]);
      this.state.stores = st.stores || st || [];
      this.state.products = pr.products || [];
      this.state.categories = ca.categories || ca || [];
      this.state.offers = ofF.offers || ofF || [];
      this.catSel = null;
      this.renderHome();
      this.setHero();
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  async setHero() {
    const s = $('#heroStats');
    if (!s) return;
    try {
      const cfg = await api('/api/settings');
      s.innerHTML = `
        <div><b>${this.state.stores.length}</b><span>متجر نشط</span></div>
        <div><b>${this.state.products.length}+</b><span>منتج</span></div>
        <div><b>${cfg.delivery_rate || 'سريع'}</b><span>توصيل</span></div>
        <div><b>${cfg.platform_name || 'زبون'}</b><span>منصة الكوت</span></div>`;
    } catch (_) {}
  },

  pcard(p, isOff = false) {
    const img = UI.img(p.image, '100%', '52px');
    return `<div class="pcard">
      ${p.has_offer ? `<span class="off">-${Math.round((p.offer_percent || 0))}%</span>` : ''}
      ${isOff ? `<span class="tag">🔥 عرض</span>` : ''}
      <div class="img" onclick="APP.product(${p.id})">${img}</div>
      <button class="heart ${this.fav.includes(p.id) ? 'on' : ''}" onclick="APP.toggleFav(${p.id}, this)">${this.fav.includes(p.id) ? '❤️' : '♡'}</button>
      <div class="b">
        <div class="pn" onclick="APP.product(${p.id})">${p.name}</div>
        <div class="ps" onclick="APP.store(${p.store_id})">🏬 ${p.store_name}</div>
        <div class="pr"><b>${fmt(priceOf(p))}</b>${p.old_price && priceOf(p) < p.old_price ? `<s>${fmt(p.old_price)}</s>` : ''}</div>
        <button class="add" onclick="APP.addBuy(${p.id})">أضف للسلة</button>
      </div>
    </div>`;
  },

  renderHome() {
    const s = this.state;
    const cats = `<div class="cats">${[{ name: 'الكل', icon: '🛍️' }, ...(s.categories || [])].map(c => `
      <div class="cat ${this.catSel && this.catSel.id === c.id ? 'on' : ''}" onclick="APP.pickCat(${c.id || 'null'}, this)"><i>${c.icon || '📦'}</i>${c.name}</div>`).join('')}</div>`;
    $('#screen').innerHTML = `
      <section class="hero">
        <h1>كل ما تتمناه 🤲<br>من متاجر الكوت</h1>
        <p>ملابس، مكياج، ألعاب، إلكترونيات وأكثر — اطلب ووصلك الباب، والدفع عند الاستلام.</p>
        <div class="cta">
          <a class="cta-main" href="#stores" onclick="document.getElementById('shops')?.scrollIntoView({behavior:'smooth'});return false;">🛍️ تسوق الآن</a>
          <a class="cta-ghost" href="/download">📲 حمّل التطبيق</a>
        </div>
        <div class="hero-stats" id="heroStats"></div>
      </section>
      <section class="sect"><div class="sect-head"><h2>التسوق حسب <em>القسم</em></h2></div>${cats}</section>
      ${s.offers.length ? `<section class="sect"><div class="sect-head"><h2>🔥 <em>عروض</em> اليوم</h2></div>
        <div class="offers">${s.offers.map(o => `<div class="offcard" onclick="APP.product(${o.id})">
          <div class="img">${UI.img(o.image, '100%', '32px')}</div>
          <div><b>${o.name}</b><div class="p">${fmt(priceOf(o))}<s>${fmt(o.price)}</s></div>
          <div class="pc">-${Math.round(o.offer_percent || 0)}% خصم</div></div></div>`).join('')}</div></section>` : ''}
      <section class="sect" id="shops"><div class="sect-head"><h2>🏬 <em>المتاجر</em></h2><a href="#stores" onclick="APP.view('stores');return false;">كل المتاجر ←</a></div>
        <div class="stores">${s.stores.slice(0, 8).map(st => this.storeCard(st)).join('')}</div></section>
      <section class="sect"><div class="sect-head"><h2>⭐ <em>الأكثر مبيعاً</em></h2><a href="#prods" onclick="APP.view('prods');return false;">كل المنتجات ←</a></div>
        <div class="prods">${s.products.slice(0, 8).map(p => this.pcard(p)).join('')}</div></section>`;
  },

  storeCard(st) {
    return `<div class="store" onclick="APP.store(${st.id})">
      <div class="store-cover">${UI.img(st.logo, '100%', '40px')}</div>
      <div class="store-b">
        <div class="store-logo">${UI.img(st.logo, '100%', '24px')}</div>
        <div style="flex:1">
          <div class="store-n">${st.name}</div>
          <div class="store-m">⭐ ${(st.rating_avg || '5.0')} · ${st.products_count || 0} منتج · ${st.address || ''}</div>
        </div>
      </div>
    </div>`;
  },

  async store(id) {
    this.cur = 'store:' + id;
    UI.load(true);
    try {
      const [sd, pd] = await Promise.all([api('/api/stores/' + id), api('/api/products?store_id=' + id)]);
      const st = sd.store || sd;
      const prods = pd.products || [];
      $('#screen').innerHTML = `<div class="sect" style="margin-top:22px">
        <div class="store-head">
          <div class="logo">${UI.img(st.logo, '100%', '38px')}</div>
          <div style="flex:1;text-align:right">
            <h1>${st.name}</h1>
            <div class="meta">⭐ ${st.rating_avg || '5.0'} · ${prods.length} منتج${st.is_open ? '' : ' · مغلق حالياً'}
              ${st.address ? ` · ${st.address}` : ''} ${st.phone ? ` · 📞 ${st.phone}` : ''}</div>
          </div>
        </div>
        <div class="chips">
          <span class="chip on">كل المنتجات</span>
          <span class="chip">التوصيل: ${st.delivery_fee ? fmt(st.delivery_fee) : 'مجاني'}</span>
          ${st.free_delivery_min ? `<span class="chip">مجاني فوق ${fmt(st.free_delivery_min)}</span>` : ''}
        </div>
        ${prods.length ? `<div class="prods">${prods.map(p => this.pcard(p)).join('')}</div>`
          : `<div class="noprod"><span class="e">📭</span>ماكو منتجات بهذا المحل بعد</div>`}
      </div>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  async search(q) {
    q = (q || '').trim();
    if (!q) return this.home();
    this.cur = 'search';
    UI.load(true);
    try {
      const d = await api('/api/products?q=' + encodeURIComponent(q));
      const rs = d.products || [];
      $('#screen').innerHTML = `<div class="res-top">نتائج البحث عن <b>«${q}»</b> — ${rs.length} منتج</div>
        <section class="sect">${rs.length ? `<div class="prods">${rs.map(p => this.pcard(p)).join('')}</div>`
          : `<div class="noprod"><span class="e">🔍</span>ما لقينا نتائج ل«${q}»<br><small>جرّب كلمة أقصر أو عامة</small></div>`}</section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  async view(v) {
    if (v === 'stores') { this.cur = 'stores'; await this.allStores(); }
    else if (v === 'prods') { this.cur = 'prods'; await this.allProds(); }
    else if (v === 'fav') { this.cur = 'fav'; await this.favPage(); }
    else if (v === 'orders') { this.cur = 'orders'; await this.orders(); }
    else if (v === 'profile') { this.cur = 'profile'; this.profile(); }
  },

  async allStores() {
    UI.load(true);
    try {
      const d = await api('/api/stores');
      const sts = d.stores || d || [];
      $('#screen').innerHTML = `<section class="sect" style="margin-top:24px"><div class="sect-head"><h2>🏬 كل <em>المتاجر</em></h2></div>
        <div class="stores">${sts.map(s => this.storeCard(s)).join('')}</div></section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  async allProds(sort, catId) {
    UI.load(true);
    try {
      const params = new URLSearchParams();
      if (this.catSel) params.set('category_id', this.catSel.id);
      if (sort === 'best') params.set('best', 'true');
      if (sort === 'low') params.set('sort', 'price_asc');
      if (sort === 'high') params.set('sort', 'price_desc');
      if (sort === 'discount') params.set('sort', 'discount');
      const u = '/api/products' + (params.toString() ? '?' + params : '');
      const d = await api(u);
      const ps = d.products || [];
      const chip = (k, t, on) => `<span class="chip ${on ? 'on' : ''}" onclick="APP.allProds('${k}', ${catId || 'null'})">${t}</span>`;
      $('#screen').innerHTML = `<section class="sect" style="margin-top:24px">
        <div class="sect-head"><h2>🛍️ كل <em>المنتجات</em></h2></div>
        <div class="chips">${chip('all', 'الكل', !sort || sort === 'all')}${chip('best', '⭐ الأفضل')}${chip('low', 'السعر: أدنى')}${chip('high', 'السعر: أعلى')}${chip('discount', '💸 الخصم')}</div>
        ${ps.length ? `<div class="prods">${ps.map(p => this.pcard(p)).join('')}</div>`
          : `<div class="noprod"><span class="e">📭</span>ماكو منتجات بعد</div>`}</section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  pickCat(id) {
    this.catSel = id ? { id } : null;
    this.allProds('all', id);
  },

  async product(id) {
    UI.load(true);
    try {
      const d = await api('/api/products/' + id);
      const p = d.product;
      const vars = p.variants || [];
      const price = priceOf(p);
      $('#pModal').innerHTML = `<div class="box">
        <div class="g">${UI.img(p.image, '100%', '90px')}
          ${p.has_offer ? `<span class="tag">-${Math.round(p.offer_percent)}%</span>` : ''}
          <span class="x" onclick="APP.closeProduct()">✕</span></div>
        <div class="i">
          <h2>${p.name}</h2>
          <div class="sname" onclick="APP.store(${p.store_id});APP.closeProduct()">🏬 ${p.store_name}</div>
          <div class="prices"><b>${fmt(price)}</b>${p.old_price && price < p.old_price ? `<s>${fmt(p.old_price)}</s>` : ''}</div>
          ${p.description ? `<div class="desc">${p.description}</div>` : ''}
          ${vars.length ? `<div class="vars" id="pvars">${vars.map((v, i) => `<span class="var ${v.stock === 0 ? 'off' : i === 0 ? 'on' : ''}" data-i="${i}" onclick="APP.varSel(this);return false;">${v.color ? v.color + ' · ' : ''}${v.name} ${v.stock === 0 ? '(نفد)' : ''}</span>`).join('')}</div>` : ''}
          <div class="qty"><button onclick="APP.pQty(-1)">−</button><b id="pqty">1</b><button onclick="APP.pQty(1)">+</button></div>
          <button class="addbig" onclick="APP.pAdd()">🛒 أضف للسلة — ${fmt(price)}</button>
          <div class="lnote" style="margin-top:10px">الدفع عند الاستلام · توصيل سريع داخل الكوت</div>
        </div>
      </div>`;
      this._p = { ...p, vars, selVar: vars.filter(v => v.stock > 0)[0] || null, qty: 1 };
      $('#pModal').classList.remove('hide');
      $('#pOverlay').classList.remove('hide');
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },
  varSel(el) {
    if (el.classList.contains('off')) return;
    document.querySelectorAll('#pvars .var').forEach(x => x.classList.remove('on'));
    el.classList.add('on');
    this._p.selVar = this._p.vars[+el.dataset.i];
  },
  pQty(d) { this._p.qty = Math.max(1, this._p.qty + d); $('#pqty').textContent = this._p.qty; },
  async pAdd() {
    const ok = await CART.add(this._p.id, this._p.selVar ? this._p.selVar.id : null, null, this._p.qty);
    if (ok) await this.cartCount();
  },
  closeProduct() { $('#pModal').classList.add('hide'); $('#pOverlay').classList.add('hide'); },

  /* المفضلة */
  fav: [],
  async loadFav() {
    if (!LS.token) return;
    try {
      const d = await api('/api/customer/favorites');
      this.fav = (d.favorites || d.products || []).map(x => x.product_id ?? x.id);
    } catch (_) { }
  },
  async toggleFav(id, el) {
    if (!LS.token) { UI.toast('سجّل دخولك أولاً', 'err'); return UI.openLogin(); }
    try {
      const fav = this.fav.includes(id);
      if (fav) { await api('/api/customer/favorites/' + id, { method: 'DELETE' }); this.fav = this.fav.filter(x => x !== id); }
      else { await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: id }) }); this.fav.push(id); }
      if (el) { el.textContent = fav ? '♡' : '❤️'; el.classList.toggle('on', !fav); }
      if (this.cur === 'fav') this.favPage();
    } catch (e) { UI.toast(e.message, 'err'); }
  },
  async favPage() {
    if (!LS.token) return this.requireLogin('شاهد مفضلتك');
    UI.load(true);
    try {
      const d = await api('/api/customer/favorites');
      const items = d.favorites || d.products || [];
      this.fav = items.map(x => x.product_id ?? x.id);
      $('#screen').innerHTML = `<section class="sect" style="margin-top:24px"><div class="sect-head"><h2>❤️ <em>المفضلة</em></h2></div>
        ${items.length ? `<div class="prods">${items.map(x => this.pcard({ ...x, id: x.product_id ?? x.id, image: x.image, name: x.name, store_id: x.store_id, store_name: x.store_name, price: x.price, old_price: x.old_price, has_offer: x.has_offer, offer_price: x.offer_price, offer_percent: x.offer_percent })).join('')}</div>`
        : `<div class="noprod"><span class="e">🤍</span>ماكو مفضلات بعد</div>`}</section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  /* الطلبات */
  async orders() {
    if (!LS.token) return this.requireLogin('شاهد طلباتك');
    UI.load(true);
    try {
      const d = await api('/api/customer/orders');
      const orders = d.orders || [];
      const stl = { new: 'جديد', pending: 'قيد التحضير', ready: 'جاهز', delivering: 'بالتوصيل', delivered: 'تم التسليم', cancelled: 'ملغي', returned: 'مرتجع' };
      $('#screen').innerHTML = `<section class="sect" style="margin-top:24px"><div class="sect-head"><h2>📦 <em>طلباتي</em></h2></div>
        ${orders.length ? orders.map(o => `<div class="ord">
          <div class="ord-top">
            <b>${o.code} · ${o.store_name}</b>
            <span class="st ${o.status}">${stl[o.status] || o.status}</span>
          </div>
          <div class="ord-items">${(o.items || []).map(i => `• ${i.name} × ${i.qty} — ${fmt(i.price)}`).join('<br>')}</div>
          <div class="tot">الإجمالي: <em>${fmt(o.total)}</em> ${o.delivery_fee ? `(توصيل ${fmt(o.delivery_fee)})` : ''}</div>
        </div>`).join('') : `<div class="noprod"><span class="e">📦</span>ماكو طلبات بعد — ابدأ التسوق!</div>`}
      </section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  /* حسابي */
  profile() {
    if (!LS.token) return this.requireLogin('افتح حسابك');
    const m = LS.me || {};
    $('#screen').innerHTML = `<section class="sect" style="margin-top:24px"><div class="prof">
      <h2>👤 حسابي</h2>
      <div class="row"><b>الاسم</b><span>${m.name || '—'}</span></div>
      <div class="row"><b>رقم الهاتف</b><span>${m.phone || '—'}</span></div>
      <div class="row"><b>نقاطي</b><span>${m.points || 0} نقطة</span></div>
      <div class="row"><b>كود الدعوة</b><span>${m.referral_code || '—'}</span></div>
      <div class="row"><b>الأدوار</b><span>${(m.roles || [m.role]).join('، ')}</span></div>
      <div class="lnote" style="margin-top:14px">الطلبات، المفضلة والعناوين كلها داخل حسابك.</div>
    </div></section>`;
  },

  requireLogin(msg) {
    $('#screen').innerHTML = `<section class="sect"><div class="noprod"><span class="e">🔐</span>${msg} يتطلب تسجيل دخول</div></section>`;
    UI.openLogin();
  },

  /* الشراء */
  async checkout() {
    const items = await CART.load();
    if (!items.length) return UI.toast('سلتك فاضية', 'err');
    if (!LS.token) return this.requireLogin('أكمل الطلب');
    const groups = {};
    for (const it of items) (groups[it.store_id] = groups[it.store_id] || { name: it.store_name, items: [] }).items.push(it);
    let govs = [];
    try { const g = await api('/api/governorates'); govs = g.governorates || g || []; } catch (_) {}
    const gOpts = `<option value="">اختر المحافظة</option>` + govs.map(g => `<option value="${g.id}">${g.name}</option>`).join('');
    $('#cart').classList.remove('open');
    $('#cartOverlay').classList.add('hide');
    $('#screen').innerHTML = `<section class="sect" style="margin-top:24px">
      <div class="prof" style="max-width:640px">
        <h2>🚚 إتمام الطلب</h2>
        <div class="lnote" style="margin-bottom:14px">${Object.keys(groups).length} طلب من ${Object.keys(groups).length} محل — يوصلوك كلهم بنفس الوقت.</div>
        <div class="lf"><label>المحافظة</label><select id="chk-gov">${gOpts}</select></div>
        <div class="lf"><label>القضاء / المنطقة</label><input id="chk-district" placeholder="مثال: مركز الكوت — حي النصر"></div>
        <div class="lf"><label>العنوان التفصيلي</label><input id="chk-addr" placeholder="الشارع / محل إرشاد / علامة فارقة"></div>
        <div class="lf"><label>ملاحظات للمندوب (اختياري)</label><input id="chk-note" placeholder="مثال: اتصل قبل الوصول"></div>
        <div class="lf"><label>رقم استقبال الطلب</label><input id="chk-phone" value="${(LS.me && LS.me.phone) || ''}" placeholder="07701234567"></div>
        <div class="lnote" style="margin-bottom:14px">💵 الدفع عند الاستلام — إجمالي المحلات: ${fmt(items.reduce((a, b) => a + priceOf(b) * b.qty, 0))}</div>
        <button class="lbtn amber" onclick="APP.placeOrder()">✅ تأكيد الطلب</button>
      </div></section>`;
  },

  async placeOrder() {
    const gov = $('#chk-gov').value;
    const dist = $('#chk-district').value.trim();
    const addr = $('#chk-addr').value.trim();
    const note = $('#chk-note').value.trim();
    const phone = $('#chk-phone').value.trim();
    if (!gov || !dist || !addr) return UI.toast('أكمل المحافظة والمنطقة والعنوان', 'err');
    const address = `${dist} — ${addr}`;
    UI.load(true);
    try {
      const items = await CART.load();
      const groups = {};
      for (const it of items) (groups[it.store_id] = groups[it.store_id] || { name: it.store_name, items: [] }).items.push(it);
      const ctrl = [];
      for (const [sid, g] of Object.entries(groups)) {
        const d = await api('/api/customer/orders', { method: 'POST', body: JSON.stringify({
          store_id: +sid, address, note: `${phone ? '📞 ' + phone + ' — ' : ''}${note}`, payment_method: 'cod' }) });
        ctrl.push(d.order || d);
      }
      await CART.render();
      this.cartCount();
      $('#screen').innerHTML = `<section class="sect"><div class="prof" style="max-width:560px;text-align:center">
        <div style="font-size:64px;margin-bottom:10px">🎉</div>
        <h2>تم استلام طلبك بنجاح!</h2>
        <div class="lnote" style="margin:14px 0">أرقام الطلبات: <b>${(ctrl.map(c => c.code || c.order?.code).filter(Boolean) || []).join('، ')}</b><br>
        سيتواصل معك المحل أو المندوب لتأكيد التوصيل — الدفع عند الاستلام.</div>
        <button class="lbtn" onclick="APP.view('orders')">📦 تابع طلباتك</button>
      </div></section>`;
    } catch (e) { UI.toast(e.message, 'err'); } finally { UI.load(false); }
  },

  cartToggle() { if (LS.token) CART.open(); else this.requireLogin('افتح السلة'); },
  cartClose() { CART.close(); },
  async cartCount() {
    if (LS.token) {
      try { const d = await api('/api/customer/cart'); UI.badge('cartBadge', d.items.reduce((a, b) => a + b.qty, 0)); } catch (_) {}
    }
  },
  logout() { AUTH.logout(); },
};

/* ═══ بدء ═══ */
(async function boot() {
  const u = location.hash.replace('#/', '').split(/[?&]/)[0];
  const route = u && u !== '/' ? u : 'home';
  UI.load(true);
  try {
    await Promise.all([APP.loadFav(), APP.cartCount()]);
  } catch (_) {}
  await AUTH.refresh();
  if (route === 'orders') await APP.view('orders');
  else if (route === 'fav') await APP.view('fav');
  else if (route === 'profile') await APP.view('profile');
  else if (route === 'stores') await APP.view('stores');
  else if (route === 'search') {
    const q = new URLSearchParams(location.hash.split('?')[1]).get('q');
    if (q) APP.search(q); else APP.home();
  } else if (route === 'prods') await APP.view('prods');
  else APP.home();
  UI.load(false);
})();

document.addEventListener('click', (e) => { if (!e.target.closest('.user-pop')) UI.closeUser(); });