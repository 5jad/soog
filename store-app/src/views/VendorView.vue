<script setup>
/* ═══ لوحة التاجر — إحصائيات + طلبات + منتجات + محفظة + متجر ═══ */
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, fmt, st, S, isRaw, num, timeAgo } from '../api';
import { bindSwipeTabs } from '../composables/useGestures';
import EmptyState from '../components/EmptyState.vue';
import StateLoader from '../components/StateLoader.vue';

const { state, toast, refreshCartCount } = useApp();
const route = useRoute();
const router = useRouter();

/* تبديل التبويب + تزامن الـ URL مع الشريط السفلي */
const setTab = (t) => {
  tab.value = t;
  router.replace({ path: '/vendor', query: { tab: t } });
};

/* سحب أفقي فوق محتوى اللوحة يبدّل بين الصفحات */
const pagesEl = ref(null);
const swipeTab = (d) => {
  const i = TAB_KEYS.indexOf(tab.value);
  setTab(TAB_KEYS[(i + d + TAB_KEYS.length) % TAB_KEYS.length]);
};

/* عنوان الصفحة — كل قسم عنوانه الخاص (مثل الموبايل) */
const headTitle = computed(() => ({ orders: 'الطلبات', products: 'منتجاتي', store: 'متجري', wallet: 'المحفظة والسحب', coupons: 'الكوبونات', week: 'أرباح الأسبوع' }[tab.value] || 'لوحة التاجر'));
const headSub = computed(() => ({ orders: 'استقبل طلبات متجرك وجهّزها', products: 'أضف وعدّل منتجات متجرك', store: store.value?.name || 'بيانات متجرك', wallet: 'رصيدك وسحبك وأرباحك', coupons: 'خصومات توزعها على زبونك', week: 'توزيع أرباحك يوم بيوم' }[tab.value] || ''));

/* تبويبات اللوحة تطابق query — الشريط السفلي يوصل بـ /vendor?tab=… */
const TAB_KEYS = ['orders', 'products', 'store', 'coupons', 'wallet', 'week'];
watch(() => route.query.tab, (v) => {
  if (v && TAB_KEYS.includes(v)) tab.value = v;
}, { immediate: true });

const tab = ref('orders');
const store = ref(null);
const stats = ref(null);
const orders = ref([]);
const products = ref([]);
const wallet = ref(null);
const week = ref([]);
const coupons = ref([]);
const loading = ref(true);
const busy = ref(false);

/* شاشات فرعية */
const statusFilter = ref('all');
const vacay = ref(false);
const newProd = ref(false);
const prodForm = ref({ name: '', price: '', category_id: '', description: '' });
const cats = ref([]);
const editProd = ref(null);
const offerForm = ref({ product_id: null, percent: '' });
const couponForm = ref({ code: '', percent: '', flat: '', min_total: '', expires_at: '' });
const withdrawAmount = ref('');
const storeForm = ref({ name: '', description: '', delivery_fee: '', free_delivery_min: '' });
const storeEdit = ref(false);

/* تاجر جديد بلا متجر — نموذج إنشاء المحل */
const createForm = ref({ name: '', category_id: '', description: '', phone: '', address: '' });
const createBusy = ref(false);

const loadAll = async () => {
  if (!state.user) return;
  loading.value = true;
  try {
    const st0 = await api('/api/vendor/store');
    store.value = st0.store || st0;
    vacay.value = !!store.value?.on_vacation;
    storeForm.value = { name: store.value?.name || '', description: store.value?.description || '', delivery_fee: store.value?.delivery_fee ?? '', free_delivery_min: store.value?.free_delivery_min ?? '' };
    if (!store.value) { loading.value = false; return; } /* ماكو محل — يظهر نموذج الإنشاء */
    const [stt, or, pr, wl, wk, cp] = await Promise.all([
      api('/api/vendor/stats'), api('/api/vendor/orders'),
      api('/api/vendor/products'), api('/api/vendor/wallet'),
      api('/api/vendor/week-earnings').catch(() => ({})), api('/api/vendor/coupons').catch(() => ({})),
    ]);
    stats.value = stt.stats || stt;
    orders.value = or.orders || or || [];
    products.value = pr.products || pr || [];
    wallet.value = wl.wallet || wl;
    week.value = wk.week_earnings || [];
    coupons.value = cp.coupons || [];
  } catch (e) { toast(e.message, false); }
  loading.value = false;
};
onMounted(async () => {
  const stopSw = bindSwipeTabs(pagesEl.value, { onPrev: () => swipeTab(-1), onNext: () => swipeTab(1) });
  onBeforeUnmount(() => stopSw?.());
  if (!route.query.tab) router.replace({ path: '/vendor', query: { tab: tab.value } }); /* توحيد الـ URL مع الشريط السفلي */
  try { const c = await api('/api/categories'); cats.value = c.categories || []; } catch (_) {}
  loadAll();
});

const filteredOrders = computed(() => orders.value.filter((o) => statusFilter.value === 'all' || o.status === statusFilter.value));
const totalEarn = computed(() => stats.value?.total_earnings || 0);

const createStore = async () => {
  const f = createForm.value;
  if (f.name.trim().length < 3) { toast('أدخل اسم متجرك', false); return; }
  if (!f.category_id) { toast('اختر قسم المتجر', false); return; }
  createBusy.value = true;
  try {
    await api('/api/vendor/store', { method: 'POST', body: JSON.stringify({
      name: f.name.trim(), category_id: Number(f.category_id), description: f.description.trim(),
      phone: f.phone.trim(), address: f.address.trim(),
    }) });
    toast('انطلق متجرك — بانتظار توثيق الأدمن ⏳');
    await loadAll();
  } catch (e) { toast(e.message, false); }
  createBusy.value = false;
};

const setStatus = async (o, status) => {
  try {
    await api(`/api/vendor/orders/${o.id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) });
    o.status = status;
    toast('حُدّثت حالة الطلب');
  } catch (e) { toast(e.message, false); }
};

const saveStore = async () => {
  busy.value = true;
  try {
    const d = await api('/api/vendor/store', { method: 'PATCH', body: JSON.stringify({
      name: storeForm.value.name, description: storeForm.value.description,
      delivery_fee: Number(storeForm.value.delivery_fee) || 0, free_delivery_min: Number(storeForm.value.free_delivery_min) || 0,
    }) });
    store.value = d.store || d;
    storeEdit.value = false;
    toast('حُفظت بيانات المتجر');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

const toggleVacay = async () => {
  try {
    await api('/api/vendor/store/vacation', { method: 'PATCH', body: JSON.stringify({ on_vacation: !vacay.value }) });
    vacay.value = !vacay.value;
    toast(vacay.value ? 'المتجر ويا إجازة — ما تصله طلبات' : 'رجع المتجر يشتغل');
  } catch (e) { toast(e.message, false); }
};

const addProduct = async () => {
  const f = prodForm.value;
  if (!f.name.trim() || !f.price || !f.category_id) { toast('أكمل اسم المنتج والسعر والتصنيف', false); return; }
  busy.value = true;
  try {
    const d = await api('/api/vendor/products', { method: 'POST', body: JSON.stringify({ name: f.name.trim(), price: Number(f.price), category_id: Number(f.category_id), description: f.description.trim(), images: prodImgs.value }) });
    products.value.unshift(d.product);
    newProd.value = false;
    prodForm.value = { name: '', price: '', category_id: '', description: '' };
    prodImgs.value = [];
    toast('أُضيف المنتج');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

/* فتح نموذج التعديل — نطبع نسخة مع مصفوفة صور مضمونة */
const openEdit = (p) => {
  editProd.value = { ...p, images: Array.isArray(p.images) ? [...p.images] : [] };
};

const saveProduct = async () => {
  if (!editProd.value) return;
  busy.value = true;
  try {
    const d = await api(`/api/vendor/products/${editProd.value.id}`, { method: 'PATCH', body: JSON.stringify({
      name: editProd.value.name, price: Number(editProd.value.price), description: editProd.value.description || '',
      images: editProd.value.images || [],
    }) });
    const i = products.value.findIndex((x) => x.id === editProd.value.id);
    if (i > -1) products.value[i] = d.product;
    editProd.value = null;
    toast('حُدّث المنتج');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

/* ═══ صور المنتج — رفع متعدد (حتى 8) بنفس مسار تطبيق الموبايل ═══ */
const MAX_IMGS = 8;
const prodImgs = ref([]);      /* صور النموذج الجديد */
const imgBusy = ref(false);
const imgInput = ref(null);    /* input[type=file] مخفي */
let imgTarget = 'new';         /* وين تنضاف الصور: new | edit */

/* ضغط الصورة بالمتصفح قبل الرفع — أقصى 1200px بجودة 82% */
const compressImg = (file) => new Promise((resolve, reject) => {
  const url = URL.createObjectURL(file);
  const img = new Image();
  img.onload = () => {
    const k = Math.min(1, 1200 / Math.max(img.width, img.height));
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(img.width * k));
    c.height = Math.max(1, Math.round(img.height * k));
    c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
    URL.revokeObjectURL(url);
    resolve(c.toDataURL('image/jpeg', 0.82));
  };
  img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('صورة غير صالحة')); };
  img.src = url;
});

const imgsList = () => (imgTarget === 'edit' ? editProd.value?.images ?? [] : prodImgs.value);

const pickImages = (target) => {
  if (imgBusy.value) return;
  imgTarget = target;
  imgInput.value?.click();
};

const onImagesPicked = async (e) => {
  const files = [...(e.target.files || [])];
  e.target.value = '';
  if (!files.length) return;
  const room = MAX_IMGS - imgsList().length;
  if (room <= 0) { toast(`أكثر ${MAX_IMGS} صور للمنتج`, false); return; }
  if (files.length > room) toast(`المكان يكفي ${room} صور بس — الباقي تجاهلناه`, false);
  imgBusy.value = true;
  try {
    const dataUris = [];
    for (const f of files.slice(0, room)) dataUris.push(await compressImg(f));
    const d = await api('/api/uploads/upload', { method: 'POST', body: JSON.stringify({ files: dataUris }) });
    imgsList().push(...(d.urls || []));
    toast('انضافت الصور ✓');
  } catch (err) { toast(err.message, false); }
  imgBusy.value = false;
};

const removeImage = (target, i) => {
  (target === 'edit' ? editProd.value?.images : prodImgs.value)?.splice(i, 1);
};

const removeProduct = async (p) => {
  if (!confirm(`تحذف «${p.name}»؟`)) return;
  try { await api(`/api/vendor/products/${p.id}`, { method: 'DELETE' }); products.value = products.value.filter((x) => x.id !== p.id); toast('حُذف المنتج'); }
  catch (e) { toast(e.message, false); }
};

const applyOffer = async (p) => {
  const percent = offerForm.value.percent;
  if (!percent || Number(percent) <= 0 || Number(percent) > 90) { toast('النسبة بين 1 و90', false); return; }
  try {
    await api(`/api/vendor/products/${p.id}/offer`, { method: 'POST', body: JSON.stringify({ percent: Number(percent) }) });
    p.has_offer = true; p.offer_percent = Number(percent);
    offerForm.value = { product_id: null, percent: '' };
    toast('تفعّل العرض ✓');
  } catch (e) { toast(e.message, false); }
};

const addCoupon = async () => {
  const f = couponForm.value;
  if (!f.code.trim() || (!f.percent && !f.flat)) { toast('أدخل الكود ونسبة أو مبلغ', false); return; }
  try {
    const d = await api('/api/vendor/coupons', { method: 'POST', body: JSON.stringify({
      code: f.code.trim().toUpperCase(), percent: f.percent ? Number(f.percent) : null, flat: f.flat ? Number(f.flat) : null, min_total: Number(f.min_total) || 0,
      expires_at: f.expires_at || null,
    }) });
    coupons.value.unshift(d.coupon);
    couponForm.value = { code: '', percent: '', flat: '', min_total: '', expires_at: '' };
    toast('أُنشئ الكوبون');
  } catch (e) { toast(e.message, false); }
};

const delCoupon = async (c) => {
  try { await api(`/api/vendor/coupons/${c.id}`, { method: 'DELETE' }); coupons.value = coupons.value.filter((x) => x.id !== c.id); toast('حُذف الكوبون'); }
  catch (e) { toast(e.message, false); }
};

const withdraw = async () => {
  const amt = Number(withdrawAmount.value);
  if (!amt || amt < 5000) { toast('السحب من 5,000 فما فوق', false); return; }
  try {
    await api('/api/vendor/wallet/withdraw', { method: 'POST', body: JSON.stringify({ amount: amt }) });
    toast('سُجّل طلب السحب — الأدمن يراجعه');
    withdrawAmount.value = '';
  } catch (e) { toast(e.message, false); }
};

const imgOf = (p) => S(p.image);
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>{{ headTitle }}</h1><p class="sub">{{ headSub || store?.name }}</p></div>

    <div v-if="loading" class="loader-block"><StateLoader /></div>
    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول بحساب تاجر</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <template v-else>
      <!-- ═══ تاجر جديد بلا متجر — أنشئ متجرك ═══ -->
      <div v-if="!store" class="panel panel-pad flex-col gap-3" style="max-width:560px;margin-inline:auto">
        <span style="font-size:38px;text-align:center">🏪</span>
        <h2 class="h3" style="text-align:center">أنشئ متجرك</h2>
        <p class="text-sm text-muted" style="text-align:center">خطوة وحدة وتفتح محلّك على زبون — بعدها تكمل كل شي من لوحة التاجر</p>
        <div class="grid gap-3" style="grid-template-columns:1fr 1fr">
          <div class="field"><label>اسم المتجر *</label><input v-model="createForm.name" class="input" maxlength="60" placeholder="مثل: أزياء الكوت" /></div>
          <div class="field"><label>القسم *</label><select v-model="createForm.category_id" class="select"><option value="">اختر…</option><option v-for="c in cats" :key="c.id" :value="c.id">{{ c.name }}</option></select></div>
        </div>
        <div class="field"><label>الوصف</label><textarea v-model="createForm.description" class="textarea" rows="2" placeholder="شنو يقدم متجرك؟"></textarea></div>
        <div class="grid gap-3" style="grid-template-columns:1fr 1fr">
          <div class="field"><label>الهاتف</label><input v-model="createForm.phone" class="input" inputmode="tel" placeholder="07XXXXXXXXX" maxlength="15" /></div>
          <div class="field"><label>العنوان</label><input v-model="createForm.address" class="input" placeholder="منطقة / شارع" /></div>
        </div>
        <button class="btn btn-primary btn-lg btn-block" :disabled="createBusy" @click="createStore">{{ createBusy ? '…' : 'أنشئ متجري' }}</button>
      </div>

      <div v-else ref="pagesEl">
      <!-- ═══ الصفحة: الطلبات ═══ -->
      <template v-if="tab === 'orders'">
        <!-- الإحصائيات — ملخص سريع بصفحة الطلبات -->
        <div v-if="stats" class="stat-grid" style="margin-block-end:var(--sp-5)">
          <div class="stat"><span class="msm">receipt_long</span><span class="n num">{{ stats.orders_total ?? orders.length }}</span><span class="l">إجمالي الطلبات</span></div>
          <div class="stat"><span class="msm">trending_up</span><span class="n num">{{ fmt(totalEarn) }}</span><span class="l">إجمالي الأرباح</span></div>
          <div class="stat"><span class="msm">inventory_2</span><span class="n num">{{ products.length }}</span><span class="l">المنتجات</span></div>
          <div class="stat"><span class="msm">local_fire_department</span><span class="n num">{{ stats.offers_active ?? products.filter((p) => p.has_offer).length }}</span><span class="l">عروض مفعلة</span></div>
        </div>

        <div class="filter-row" style="margin-block-end:var(--sp-3)">
          <button class="chip" :class="{ active: statusFilter === 'all' }" @click="statusFilter = 'all'">الكل</button>
          <button v-for="s in ['new','pending','ready','delivering','delivered','cancelled']" :key="s" class="chip" :class="{ active: statusFilter === s }" @click="statusFilter = s">{{ st(s)[0] }}</button>
        </div>
        <div class="flex-col gap-3">
          <EmptyState v-if="!filteredOrders.length" icon="📥" title="ماكو طلبات" sub="تصلك الطلبات جديدة هنا فور وصولها" />
          <article v-for="o in filteredOrders" :key="o.id" class="order-card">
            <div class="order-head">
              <div class="flex-col gap-1">
                <span class="num">{{ o.code }}</span>
                <span class="date">{{ timeAgo(o.created_at) }} · {{ o.items?.length || 0 }} عناصر</span>
              </div>
              <div class="flex gap-2 wrap" style="align-items:center">
                <span class="num" style="font-weight:800">{{ fmt(o.total) }}</span>
                <span class="st-pill" :class="st(o.status)[1]"><span class="dot"></span>{{ st(o.status)[0] }}</span>
              </div>
            </div>
            <div class="order-body">
              <div v-if="o.address_text" class="text-xs text-muted" style="margin-block-end:var(--sp-2)">📍 {{ o.address_text }}</div>
              <div v-for="it in (o.items || [])" :key="it.id" class="line-item" style="padding-block:var(--sp-2)">
                <div class="th" style="width:48px;height:48px"><span class="emoji" :style="it.name">{{ it.name.slice(0,1) }}</span></div>
                <div class="meta">
                  <span class="name">{{ it.name }} <small v-if="it.variant" class="variant">({{ it.variant }})</small></span>
                  <div class="prow"><span class="price num">{{ fmt(it.price) }}</span><span class="text-xs text-muted">× {{ it.qty }}</span></div>
                </div>
              </div>
            </div>
            <div class="order-foot" style="flex-wrap:wrap">
              <span class="text-xs text-muted">👤 {{ o.user_name }} · {{ o.phone ? o.phone : '' }}</span>
              <div class="order-actions">
                <button v-if="o.status === 'new'" class="btn btn-primary btn-sm" @click="setStatus(o, 'pending')">قبول الطلب</button>
                <button v-if="o.status === 'pending'" class="btn btn-primary btn-sm" @click="setStatus(o, 'ready')">جهّز الطلب</button>
                <button v-if="o.status === 'ready'" class="btn btn-soft btn-sm" disabled>بانتظار المندوب</button>
                <button v-if="o.status === 'delivering'" class="btn btn-ghost btn-sm" disabled>بالتوصيل…</button>
                <button v-if="['new','pending'].includes(o.status)" class="btn btn-ghost btn-sm text-danger" @click="setStatus(o, 'cancelled')">إلغاء</button>
              </div>
            </div>
          </article>
        </div>
      </template>

      <!-- ═══ الصفحة: المنتجات ═══ -->
      <template v-else-if="tab === 'products'">
        <div class="flex gap-2 wrap" style="margin-block-end:var(--sp-4)">
          <button class="btn btn-accent btn-md" @click="newProd = !newProd">
            <span class="msm">add</span> {{ newProd ? 'إغلاق' : 'منتج جديد' }}
          </button>
          <button class="btn btn-ghost btn-md" @click="setTab('coupons')"><span class="msm">confirmation_number</span> إدارة الكوبونات</button>
        </div>
        <div v-if="newProd" class="panel panel-pad flex-col gap-3" style="margin-block-end:var(--sp-4)">
          <div class="grid gap-3" style="grid-template-columns:1fr 1fr">
            <div class="field"><label>اسم المنتج *</label><input v-model="prodForm.name" class="input" /></div>
            <div class="field"><label>السعر (د.ع) *</label><input v-model="prodForm.price" class="input" inputmode="numeric" /></div>
          </div>
          <div class="field">
            <label>التصنيف *</label>
            <select v-model="prodForm.category_id" class="select"><option value="">اختر…</option><option v-for="c in cats" :key="c.id" :value="c.id">{{ c.name }}</option></select>
          </div>
          <div class="field"><label>الوصف</label><textarea v-model="prodForm.description" class="textarea" rows="2"></textarea></div>
          <!-- ═══ صور المنتج (حتى 8) ═══ -->
          <div class="field">
            <label>الصور <span class="hint">({{ prodImgs.length }}/8) — اختياري، أول صورة تصير الغلاف</span></label>
            <div class="img-strip">
              <div v-for="(u, i) in prodImgs" :key="u" class="img-chip">
                <img :src="S(u)" alt="" />
                <button type="button" class="chip-x" aria-label="حذف الصورة" @click="removeImage('new', i)">×</button>
              </div>
              <button v-if="prodImgs.length < 8" type="button" class="add-img" :disabled="imgBusy" @click="pickImages('new')">
                <span class="msm">{{ imgBusy ? 'progress_activity' : 'add_a_photo' }}</span>
                <small>{{ imgBusy ? 'جاري الرفع…' : 'أضف صور' }}</small>
              </button>
            </div>
          </div>
          <button class="btn btn-primary btn-md" :disabled="busy" @click="addProduct">إضافة</button>
        </div>

        <EmptyState v-if="!products.length" icon="📦" title="ماكو منتجات" sub="أضف أول منتج لمتجرك" />
        <div v-else class="table-wrap">
          <table class="dash">
            <thead><tr><th>المنتج</th><th>السعر</th><th>المخزون</th><th>العرض</th><th>حالة</th><th></th></tr></thead>
            <tbody>
              <tr v-for="p in products" :key="p.id">
                <td>
                  <div class="flex gap-2">
                    <div class="th" style="width:44px;height:44px;border-radius:var(--r-sm);background:var(--img-ph);overflow:hidden;position:relative">
                      <img v-if="imgOf(p) && !isRaw(p.image)" :src="imgOf(p)" alt="" style="width:100%;height:100%;object-fit:cover" />
                    </div>
                    <b class="clamp-2" style="max-width:220px">{{ p.name }}</b>
                  </div>
                </td>
                <td><b class="num">{{ fmt(p.has_offer && p.offer_price ? p.offer_price : p.price) }}</b><small v-if="p.has_offer" class="text-xs text-muted"><s>{{ fmt(p.price) }}</s></small></td>
                <td class="num">{{ p.stock ?? 0 }}</td>
                <td>
                  <div v-if="!offerForm.product_id || offerForm.product_id !== p.id" class="flex gap-2">
                    <span v-if="p.has_offer" class="badge badge-disc">{{ p.offer_percent }}%</span>
                    <button class="btn btn-ghost btn-sm" style="color:var(--primary-light)" @click="offerForm = { product_id: p.id, percent: '' }">عرض</button>
                  </div>
                  <div v-else class="flex gap-2">
                    <input v-model="offerForm.percent" class="input" inputmode="numeric" placeholder="%" style="height:var(--btn-h-sm);width:64px" />
                    <button class="btn btn-primary btn-sm" @click="applyOffer(p)">حفظ</button>
                  </div>
                </td>
                <td><span class="badge" :class="p.is_available ? 'badge-new' : 'badge-sold'">{{ p.is_available ? 'متاح' : 'موقوف' }}</span></td>
                <td>
                  <div class="flex gap-1">
                    <button class="x" aria-label="تعديل" @click="openEdit(p)"><span class="msm" style="font-size:18px">edit</span></button>
                    <button class="x" aria-label="حذف" @click="removeProduct(p)"><span class="msm" style="font-size:18px">delete</span></button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- تعديل منتج -->
        <div v-if="editProd" class="modal-mask" @click.self="editProd = null">
          <div class="modal-panel">
            <div class="modal-head"><h3>تعديل {{ editProd.name }}</h3><button class="modal-close" @click="editProd = null"><span class="msm">close</span></button></div>
            <div class="modal-body flex-col gap-3">
              <div class="field"><label>الاسم</label><input v-model="editProd.name" class="input" /></div>
              <div class="field"><label>السعر</label><input v-model="editProd.price" class="input" inputmode="numeric" /></div>
              <div class="field"><label>الوصف</label><textarea v-model="editProd.description" class="textarea" rows="3"></textarea></div>
              <!-- ═══ صور المنتج (حتى 8) ═══ -->
              <div class="field">
                <label>الصور <span class="hint">({{ editProd.images.length }}/8)</span></label>
                <div class="img-strip">
                  <div v-for="(u, i) in editProd.images" :key="u" class="img-chip">
                    <img :src="S(u)" alt="" />
                    <button type="button" class="chip-x" aria-label="حذف الصورة" @click="removeImage('edit', i)">×</button>
                  </div>
                  <button v-if="editProd.images.length < 8" type="button" class="add-img" :disabled="imgBusy" @click="pickImages('edit')">
                    <span class="msm">{{ imgBusy ? 'progress_activity' : 'add_a_photo' }}</span>
                    <small>{{ imgBusy ? 'جاري الرفع…' : 'أضف صور' }}</small>
                  </button>
                </div>
              </div>
              <button class="btn btn-primary btn-lg btn-block" :disabled="busy" @click="saveProduct">حفظ التعديلات</button>
            </div>
          </div>
        </div>

        <!-- input ملف مخفي — يخدم نموذجي الإضافة والتعديل -->
        <input ref="imgInput" type="file" accept="image/*" multiple hidden @change="onImagesPicked" />
      </template>

      <!-- ═══ الصفحة: متجري ═══ -->
      <template v-else-if="tab === 'store'">
        <div class="panel panel-pad flex-col gap-3" style="margin-block-end:var(--sp-4)">
          <div class="flex between gap-3" style="flex-wrap:wrap">
            <div>
              <b style="font-size:var(--fs-lg)">{{ store?.name }}</b>
              <p class="text-xs text-muted">{{ store?.status === 'approved' ? '✅ متجر موثق ونشط' : '⏳ بانتظار توثيق الأدمن' }}</p>
            </div>
            <div class="flex gap-2 wrap">
              <button class="btn btn-outline btn-sm" @click="storeEdit = !storeEdit">تعديل المتجر</button>
              <button class="btn" :class="vacay ? 'btn-accent btn-sm' : 'btn-ghost btn-sm'" @click="toggleVacay">
                {{ vacay ? 'رجّع المتجر للعمل' : 'ويا إجازة' }}
              </button>
            </div>
          </div>
          <RouterLink v-if="store?.id" class="btn btn-ghost btn-md" :to="`/stores/${store.id}`">
            شوف متجرك بعيون الزبون 👀
          </RouterLink>
        </div>

        <div v-if="storeEdit" class="panel panel-pad flex-col gap-3" style="margin-block-end:var(--sp-4)">
          <h2 class="h3">تعديل بيانات المتجر</h2>
          <div class="field"><label>الاسم</label><input v-model="storeForm.name" class="input" /></div>
          <div class="field"><label>الوصف</label><textarea v-model="storeForm.description" class="textarea" rows="2"></textarea></div>
          <div class="grid gap-3" style="grid-template-columns:1fr 1fr">
            <div class="field"><label>سعر التوصيل (د.ع)</label><input v-model="storeForm.delivery_fee" class="input" inputmode="numeric" /></div>
            <div class="field"><label>توصيل مجاني فوق (د.ع)</label><input v-model="storeForm.free_delivery_min" class="input" inputmode="numeric" /></div>
          </div>
          <button class="btn btn-primary btn-md" :disabled="busy" @click="saveStore">حفظ</button>
        </div>
      </template>

      <!-- ═══ الصفحة: المحفظة ═══ -->
      <template v-else-if="tab === 'wallet'">
        <div class="flex-col gap-4" style="max-width:560px">
          <div class="wallet-card">
            <div class="l">💰 الرصيد المتاح للسحب</div>
            <div class="n num">{{ fmt(wallet?.balance || 0) }}</div>
            <div class="l">أرباح اليوم: {{ fmt(wallet?.today || 0) }} · معلقة: {{ fmt(wallet?.pending || 0) }}</div>
          </div>
          <div class="panel panel-pad flex gap-2">
            <input v-model="withdrawAmount" class="input" inputmode="numeric" placeholder="المبلغ (5,000 فما فوق)" />
            <button class="btn btn-accent btn-md" @click="withdraw">سحب</button>
          </div>
          <button class="btn btn-ghost btn-md" @click="setTab('week')"><span class="msm">bar_chart</span> أرباح الأسبوع</button>
          <div v-if="(wallet?.reports || []).length" class="flex-col gap-2">
            <div v-for="r in wallet.reports" :key="r.id" class="info-row">
              <span class="k">تقرير كاش {{ r.receipt_no || '' }} · {{ timeAgo(r.created_at) }}</span>
              <span class="v num">{{ fmt(r.net) }}</span>
            </div>
          </div>
        </div>
      </template>

      <!-- ═══ الصفحة: الكوبونات ═══ -->
      <template v-else-if="tab === 'coupons'">
        <button class="btn btn-ghost btn-sm" style="margin-block-end:var(--sp-4)" @click="setTab('products')"><span class="msm">arrow_forward</span> رجوع للمنتجات</button>
        <div class="flex-col gap-4">
          <div class="panel panel-pad flex-col gap-3">
            <h2 class="h3">كوبون جديد</h2>
            <div class="grid gap-3" style="grid-template-columns:repeat(auto-fit,minmax(140px,1fr))">
              <div class="field"><label>الكود</label><input v-model="couponForm.code" class="input" placeholder="SAVE10" /></div>
              <div class="field"><label>نسبة %</label><input v-model="couponForm.percent" class="input" inputmode="numeric" /></div>
              <div class="field"><label>مبلغ ثابت</label><input v-model="couponForm.flat" class="input" inputmode="numeric" /></div>
              <div class="field"><label>الحد الأدنى</label><input v-model="couponForm.min_total" class="input" inputmode="numeric" /></div>
              <div class="field"><label>الانتهاء</label><input v-model="couponForm.expires_at" class="input" type="date" /></div>
            </div>
            <button class="btn btn-primary btn-md" @click="addCoupon">إنشاء الكوبون</button>
          </div>
          <div v-if="coupons.length" class="flex-col gap-2">
            <div v-for="c in coupons" :key="c.id" class="panel panel-pad flex between gap-3" style="padding:var(--sp-3) var(--sp-4)">
              <div class="flex gap-3" style="align-items:center">
                <span class="badge" style="background:rgba(212,175,55,.16);color:var(--gold);font-size:var(--fs-sm)">{{ c.code }}</span>
                <span class="text-sm">{{ c.percent ? c.percent + '%' : fmt(c.flat) }} خصم</span>
                <span class="text-xs text-muted">أدنى {{ fmt(c.min_total) }} <template v-if="c.expires_at">· حتى {{ c.expires_at.slice(0, 10) }}</template></span>
              </div>
              <button class="x" aria-label="حذف" @click="delCoupon(c)"><span class="msm">delete</span></button>
            </div>
          </div>
        </div>
      </template>

      <!-- ═══ الصفحة: أرباح الأسبوع ═══ -->
      <template v-else-if="tab === 'week'">
        <button class="btn btn-ghost btn-sm" style="margin-block-end:var(--sp-4)" @click="setTab('wallet')"><span class="msm">arrow_forward</span> رجوع للمحفظة</button>
        <EmptyState v-if="!week.length" icon="📊" title="ماكو بيانات بعد" />
        <div v-else class="table-wrap">
          <table class="dash">
            <thead><tr><th>اليوم</th><th>الطلبات</th><th>الإيرادات</th><th>التوصيل</th><th>صافي</th></tr></thead>
            <tbody>
              <tr v-for="w in week" :key="w.date">
                <td>{{ w.date }}</td>
                <td class="num">{{ w.orders }}</td>
                <td class="num">{{ fmt(w.revenue) }}</td>
                <td class="num">{{ fmt(w.delivery_fees) }}</td>
                <td><b class="num">{{ fmt(w.net) }}</b></td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
      </div>
    </template>
  </div>
</template>