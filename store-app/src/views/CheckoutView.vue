<script setup>
/* ═══ إتمام الطلب — عنوان + توصيل + كوبون + نقاط + إنشاء الطلبات (بالأقسام) ═══ */
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, isRaw } from '../api';
import LottieBox from '../components/LottieBox.vue';
import EmptyState from '../components/EmptyState.vue';
import StateLoader from '../components/StateLoader.vue';

const { state, toast, refreshCartCount } = useApp();
const router = useRouter();

const items = ref([]);
const groups = ref([]);
const addresses = ref([]);
const governorates = ref([]);
const points = ref(0);
const loading = ref(true);
const busy = ref(false);

/* النموذج */
const addressId = ref(null);
const newAddr = ref(false);
const addrForm = ref({ label: '', governorate_id: '', district_id: '', details: '' });
const note = ref('');
const couponCode = ref('');
const usePoints = ref(false);
const done = ref(0);   /* عدد الطلبات المنفذة — يفتح شاشة النجاح */

const fee = ref(0);
const feeFallback = ref(false);
const couponDiscount = ref(0);
const couponApplied = ref('');

const groupId = (`zb-` + Date.now().toString(36) + Math.random().toString(36).slice(2, 8)).toUpperCase();

const groupOf = (list) => {
  const m = new Map();
  for (const it of list) {
    if (!m.has(it.store_id)) m.set(it.store_id, []);
    m.get(it.store_id).push(it);
  }
  return [...m.entries()];
};

const loadCart = async () => {
  try {
    const d = await api('/api/customer/cart');
    items.value = d.items || [];
    groups.value = groupOf(items.value);
  } catch (_) { items.value = []; groups.value = []; }
};

const getAddresses = async () => {
  try {
    const a = await api('/api/customer/addresses');
    addresses.value = a.addresses || a || [];
    if (Array.isArray(a)) addresses.value = a;
    if (addresses.value.length) addressId.value = addresses.value[0].id;
  } catch (_) { addresses.value = []; }
};

onMounted(async () => {
  if (!state.user) { loading.value = false; return; }
  await Promise.all([loadCart(), getAddresses()]);
  try {
    const [g, pt] = await Promise.all([api('/api/governorates'), api('/api/customer/points')]);
    governorates.value = g.governorates || [];
    points.value = pt.balance || 0;
  } catch (_) {}
  loading.value = false;
  if (groups.value.length) await estimateFee();
});

const subtotal = computed(() => items.value.reduce((a, b) => a + priceOf(b) * Number(b.qty), 0));
const selectedAddress = computed(() => addresses.value.find((a) => a.id === addressId.value));
const selectedGov = computed(() => governorates.value.find((g) => g.id === Number(addrForm.value.governorate_id)));
const districtsOf = computed(() => selectedGov.value?.districts || []);
const total = computed(() => Math.max(0, subtotal.value + fee.value - couponDiscount.value - calcPoints.value));

/* ❯ احسب التوصيل */
const estimateFee = async () => {
  const ids = groups.value.map(([sid]) => sid);
  if (!ids.length) return;
  try {
    const qp = new URLSearchParams({ store_ids: ids.join(',') });
    if (addressId.value) qp.set('address_id', addressId.value);
    const d = await api('/api/customer/delivery-estimate?' + qp.toString());
    fee.value = d.fee || 1500;
    feeFallback.value = !!d.fallback;
  } catch (e) { toast(e.message, false); }
};

/* ❯ الكوبون */
const applyCoupon = async () => {
  couponApplied.value = '';
  couponDiscount.value = 0;
  if (!couponCode.value.trim()) return;
  const sid = groups.value[0]?.[0];
  try {
    const d = await api('/api/customer/cart/apply-coupon', { method: 'POST', body: JSON.stringify({ store_id: sid, code: couponCode.value, subtotal: subtotal.value }) });
    couponDiscount.value = d.discount || 0;
    couponApplied.value = d.code;
    toast('الكوبون مفعّل ✓');
  } catch (e) { toast(e.message, false); }
};

/* ❯ النقاط — كل 100 نقطة = 1,000 د.ع */
const calcPoints = computed(() => {
  if (!usePoints.value || !points.value) return 0;
  const caps = Math.min(points.value, Math.floor(subtotal.value / 1000) * 100);
  return Math.floor(caps / 100) * 1000;
});

const canSubmit = computed(() => !!addressId.value || newAddr.value);
const submitAll = async () => {
  if (!groups.value.length) { toast('السلة فاضية'); return; }
  if (!newAddr.value && !addressId.value) { toast('اختر أو أضف عنواناً'); return; }
  busy.value = true;
  let created = 0;
  const orderGroup = groupId;
  try {
    for (let i = 0; i < groups.value.length; i++) {
      const [sid, list] = groups.value[i];
      const body = {
        store_id: sid,
        note: note.value.trim(),
        payment_method: 'cod',
        group_id: orderGroup,
        group_store_ids: groups.value.map(([id]) => id).join(','),
        coupon_code: couponApplied.value,
        redeem_points: usePoints.value ? Math.floor(points.value / 100) * 100 : 0,
        address_id: newAddr.value ? (await addAddress())?.id : addressId.value,
        address: !newAddr.value ? `${selectedAddress.value?.label} — ${selectedAddress.value?.details}` : addrForm.value.details,
      };
      const d = await api('/api/customer/orders', { method: 'POST', body: JSON.stringify(body) });
      created++;
      if (created === 1) await loadCart(); /* أول أمر: الباقي خرج من السلة لاحقاً */
    }
    refreshCartCount();
    done.value = created;   /* شاشة النجاح بدل التوست */
  } catch (e) {
    toast(e.message, false);
    if (e.message?.includes('verify')) toast('أكّد رقمك عبر تلغرام أولاً', false);
  }
  busy.value = false;
};

/* ❯ إضافة عنوان جديد */
/* إحداثيات الجهاز إن سمح المستخدم — تُستخدم بحساب التوصيل بالمسافة والتتبع الحي */
const getCoords = () => new Promise((resolve) => {
  if (!navigator.geolocation) return resolve(null);
  navigator.geolocation.getCurrentPosition(
    (pos) => resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
    () => resolve(null),
    { timeout: 6000, maximumAge: 300000 },
  );
});

const addAddress = async () => {
  const f = addrForm.value;
  if (!f.label.trim() || !f.governorate_id || !f.district_id || !f.details.trim()) {
    toast('أكمل حقول العنوان الجديد', false);
    throw new Error('ناقص');
  }
  const c = await getCoords();
  const d = await api('/api/customer/addresses', { method: 'POST', body: JSON.stringify({
    label: f.label.trim(),
    governorate_id: Number(f.governorate_id),
    district_id: Number(f.district_id),
    details: f.details.trim(),
    ...(c ? { lat: c.lat, lng: c.lng } : {}),
  }) });
  addresses.value.unshift(d.address || d);
  addressId.value = d.address?.id ?? addresses.value[0]?.id;
  return d.address || d;
};

const num2 = (n) => Number(n).toLocaleString('ar-IQ');
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>إتمام الطلب</h1><p class="sub">راجع كل شي وسوّي الطلب — دفع كاش عند الاستلام</p></div>

    <!-- ═══ شاشة نجاح الطلب — مثل التطبيق (كونفيتي + خلفية خضراء) ═══ -->
    <div v-if="done > 0" class="flex-col gap-3" style="max-width:480px;margin-inline:auto;text-align:center;padding-block:var(--sp-8)">
      <LottieBox asset-key="order_success" :width="150" :height="150" fallback="✅" />
      <h1 class="h2" style="color:var(--success-deep)">انطلق طلبك بنجاح 🎉</h1>
      <p class="text-sm text-muted">أرسلنا {{ done }} {{ done === 1 ? 'طلب' : 'طلبات' }} — مندوبنا براسلك</p>
      <p class="text-xs text-muted">السلة انصفّرت بعد الطلب — أرقام الطلبات وتتبّع التوصيل من «طلباتي»</p>
      <button class="btn btn-primary btn-lg btn-block" @click="router.push('/orders')">📦 شوف طلباتي</button>
      <button class="btn btn-ghost" style="margin-top:4px" @click="router.push('/')">عودة للتسوق</button>
    </div>

    <div v-if="loading" class="loader-block"><StateLoader /></div>

    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <div v-else-if="!groups.length" class="empty">
      <span class="msm">shopping_bag</span>
      <h3>سلتك فاضية</h3>
      <button class="btn btn-accent btn-md" @click="router.push('/stores')">تسوق الآن</button>
    </div>

    <div v-else class="cart-layout">
      <div class="flex-col gap-5">
        <!-- العنوان -->
        <section class="panel panel-pad">
          <h2 class="h3" style="margin-block-end:var(--sp-4)">📍 عنوان التوصيل</h2>
          <div class="flex-col gap-2" style="margin-block-end:var(--sp-3)">
            <label v-for="a in addresses" :key="a.id" class="radio-card" :class="{ active: addressId === a.id && !newAddr }" @click="newAddr = false; addressId = a.id">
              <span class="radio-dot"></span>
              <span>
                <b style="display:block">{{ a.label }}</b>
                <small class="text-muted">{{ a.details }}</small>
              </span>
            </label>
          </div>
          <label class="radio-card" :class="{ active: newAddr }" @click="newAddr = true">
            <span class="radio-dot"></span>
            <span><b>عنوان جديد</b></span>
          </label>
          <div v-if="newAddr" class="flex-col gap-3" style="margin-block-start:var(--sp-4)">
            <div class="field"><label>اسم العنوان</label><input v-model="addrForm.label" class="input" placeholder="مثلاً: البيت / المحل" /></div>
            <div class="grid gap-3" style="grid-template-columns:1fr 1fr">
              <div class="field">
                <label>المحافظة</label>
                <select v-model="addrForm.governorate_id" class="select"><option value="">اختر…</option><option v-for="g in governorates" :key="g.id" :value="g.id">{{ g.name }}</option></select>
              </div>
              <div class="field">
                <label>القضاء</label>
                <select v-model="addrForm.district_id" class="select" :disabled="!selectedGov"><option value="">اختر…</option><option v-for="d in districtsOf" :key="d.id" :value="d.id">{{ d.name }}</option></select>
              </div>
            </div>
            <div class="field"><label>التفاصيل (الشارع/المنطقة/أقرب علامة)</label><textarea v-model="addrForm.details" class="textarea" rows="2"></textarea></div>
          </div>
        </section>

        <!-- المحلات -->
        <section v-for="([sid, list], i) in groups" :key="sid" class="panel panel-pad">
          <div class="flex between gap-2" style="border-block-end:1px solid var(--line);padding-block-end:var(--sp-3);margin-block-end:var(--sp-2)">
            <b style="color:var(--primary)">{{ list[0].store_name }}</b>
            <span class="text-xs text-muted">🚚 {{ i === 0 ? fmt(fee) + (feeFallback ? ' (تقديري)' : '') : 'مجاني ضمن الرحلة' }}</span>
          </div>
          <div v-for="it in list" :key="it.id" class="line-item" style="padding-block:var(--sp-2)">
            <div class="th" style="width:56px;height:56px">
              <img v-if="S(it.image) && !isRaw(it.image)" :src="S(it.image)" alt="" />
            </div>
            <div class="meta">
              <span class="name">{{ it.name }}</span>
              <span v-if="it.variant" class="variant">{{ it.variant }}</span>
              <div class="prow"><span class="price num">{{ fmt(priceOf(it) * it.qty) }}</span><span class="text-xs text-muted">× {{ it.qty }}</span></div>
            </div>
          </div>
          <div class="sum-row" style="margin-block-start:var(--sp-2)"><span>مجموع المتجر</span><strong class="num">{{ fmt(list.reduce((a, b) => a + priceOf(b) * Number(b.qty), 0)) }}</strong></div>
        </section>

        <!-- ملاحظة -->
        <section class="panel panel-pad">
          <h2 class="h3" style="margin-block-end:var(--sp-3)">ملاحظة للتوصيل</h2>
          <textarea v-model="note" class="textarea" rows="2" placeholder="اختياري — اكتب أي تفصيلة مهمة للمندوب"></textarea>
        </section>
      </div>

      <!-- الملخص -->
      <aside class="panel panel-pad" style="position:sticky;inset-block-start:calc(var(--header-h) + var(--sp-5))">
        <h2 class="h3" style="margin-block-end:var(--sp-3)">الملخص</h2>
        <div class="sum-row"><span>المنتجات</span><span class="num">{{ fmt(subtotal) }}</span></div>
        <div class="sum-row"><span>التوصيل ({{ groups.length }} {{ groups.length > 1 ? 'رحلة واحدة' : 'رحلة' }})</span><span class="num">{{ fmt(fee) }}</span></div>

        <!-- كوبون -->
        <div class="coupon-line" style="margin-block:var(--sp-3)">
          <input v-model="couponCode" class="input" placeholder="كود الكوبون (اختياري)" style="text-transform:uppercase" />
          <button class="btn btn-soft btn-md" @click="applyCoupon">تطبيق</button>
        </div>
        <div v-if="couponDiscount > 0" class="sum-row" style="color:var(--success-deep)"><span>خصم الكوبون {{ couponApplied }}</span><strong class="num">−{{ fmt(couponDiscount) }}</strong></div>

        <!-- نقاط -->
        <label v-if="points > 0" class="radio-card" style="margin-block:var(--sp-3);padding:var(--sp-3)" @click="usePoints = !usePoints">
          <span class="radio-dot"></span>
          <span class="flex-1">
            <b style="display:block">استبدال النقاط ({{ num2(points) }} نقطة)</b>
            <small class="text-muted">كل 100 نقطة = 1,000 د.ع خصم</small>
          </span>
        </label>
        <div v-if="usePoints && calcPoints > 0" class="sum-row" style="color:var(--success-deep)"><span>خصم النقاط</span><strong class="num">−{{ fmt(calcPoints) }}</strong></div>

        <div class="sum-total"><span>الإجمالي</span><span class="num">{{ fmt(total) }}</span></div>
        <p class="text-xs text-muted" style="margin-block-start:var(--sp-2)">الدفع: <b>كاش عند الاستلام</b></p>
        <button class="btn btn-accent btn-lg btn-block" style="margin-block-start:var(--sp-4)" :disabled="busy" @click="submitAll">
          {{ busy ? '… جارٍ إنشاء الطلب' : `تأكيد الطلب — ${fmt(total)}` }}
        </button>
      </aside>
    </div>
  </div>
</template>