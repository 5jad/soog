<script setup>
/* ═══ لوحة المندوب — متاح/أونلاين + رحلات + محفظة + تقرير كاش ═══ */
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, fmt, fmtDate, num, timeAgo } from '../api';
import { bindSwipeTabs } from '../composables/useGestures';
import EmptyState from '../components/EmptyState.vue';
import StateLoader from '../components/StateLoader.vue';

const { state, toast } = useApp();
const route = useRoute();
const router = useRouter();

/* تبديل التبويب + تزامن الـ URL مع الشريط السفلي */
const setTab = (t) => {
  tab.value = t;
  router.replace({ path: '/delivery', query: { tab: t } });
};

/* سحب أفقي على محتوى اللوحة يبدّل بين الأقسام */
const contentEl = ref(null);
const swipeTab = (d) => {
  const i = TAB_KEYS.indexOf(tab.value);
  setTab(TAB_KEYS[(i + d + TAB_KEYS.length) % TAB_KEYS.length]);
};

/* تبويبات اللوحة تطابق query — الشريط السفلي يوصل بـ /delivery?tab=… */
const TAB_KEYS = ['available', 'trip', 'wallet'];
watch(() => route.query.tab, (v) => {
  if (v && TAB_KEYS.includes(v)) tab.value = v;
}, { immediate: true });

const online = ref(false);
const available = ref([]);
const trip = ref(null);
const wallet = ref(null);
const stats = ref(null);
const loading = ref(true);
const busy = ref(false);
const reportAmount = ref('');
let poll = null;

const load = async () => {
  try {
    const [on, av, tr, wl, st] = await Promise.all([
      api('/api/delivery/online'),
      api('/api/delivery/available').catch(() => ({ orders: [] })),
      api('/api/delivery/trip').catch(() => ({ trip: null })),
      api('/api/delivery/wallet'),
      api('/api/delivery/stats'),
    ]);
    online.value = on.online;
    available.value = av.orders || [];
    trip.value = tr.trip || null;
    wallet.value = wl.wallet;
    stats.value = st.stats;
  } catch (e) { toast(e.message, false); }
  loading.value = false;
};

const setOnline = async (v) => {
  try {
    await api('/api/delivery/online', { method: 'POST', body: JSON.stringify({ online: v }) });
    online.value = v;
    toast(v ? 'صارت أونلاين — تستلم طلبات' : 'طُفيت من الاستلام');
  } catch (e) { toast(e.message, false); }
};

const accept = async (o) => {
  busy.value = true;
  try {
    const d = await api(`/api/delivery/accept/${o.id}`, { method: 'POST' });
    trip.value = d.trip || d;
    toast('قبلت الطلب — روح للمتجر');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

const pickup = async () => {
  try {
    await api('/api/delivery/pickup', { method: 'POST' });
    toast('استلمت الطلب — انطلق للتوصيل');
    load();
  } catch (e) { toast(e.message, false); }
};

const delivered = async () => {
  try {
    await api('/api/delivery/delivered', { method: 'POST' });
    toast('تم التسليم 🎉');
    trip.value = null;
    load();
  } catch (e) { toast(e.message, false); }
};

const reportCash = async () => {
  const amt = Number(reportAmount.value);
  if (!amt || amt <= 0) { toast('أدخل المبلغ المحصل', false); return; }
  try {
    await api('/api/delivery/cash-report', { method: 'POST', body: JSON.stringify({ total_collected: amt }) });
    toast('سُجّل التقرير — الأدمن يراجع الكاش');
    reportAmount.value = '';
    load();
  } catch (e) { toast(e.message, false); }
};

onMounted(async () => {
  const stopSw = bindSwipeTabs(contentEl.value, { onPrev: () => swipeTab(-1), onNext: () => swipeTab(1) });
  onBeforeUnmount(() => stopSw?.());
  if (!route.query.tab) router.replace({ path: '/delivery', query: { tab: tab.value } }); /* توحيد الـ URL مع الشريط السفلي */
  await load();
  poll = setInterval(load, 15000);
});
onBeforeUnmount(() => { if (poll) clearInterval(poll); });

const tripOrders = computed(() => trip.value ? (trip.value.orders || [trip.value]) : []);
</script>

<template>
  <div class="container-narrow">
    <div class="page-head flex between gap-3" style="align-items:center;flex-wrap:wrap">
      <div><h1>لوحة المندوب</h1><p class="sub">استقبل الرحلات وتبعها من هني</p></div>
      <button class="btn" :class="online ? 'btn-soft btn-lg' : 'btn-accent btn-lg'" @click="setOnline(!online)">
        {{ online ? '🛵 أونلاين — متوقف عن الاستلام؟ اضغط' : 'ابدأ العمل (أونلاين)' }}
      </button>
    </div>

    <div v-if="loading" class="loader-block"><StateLoader /></div>
    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول بحساب مندوب</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <template v-else>
      <!-- محتوى اللوحة قابل للسحب الأفقي للتنقل بين الأقسام -->
      <div ref="contentEl">
      <!-- ═══ متاح — الإحصائيات + الطلبات المتاحة ═══ -->
      <div v-if="tab === 'available'">
        <div v-if="stats" class="stat-grid" style="margin-block-end:var(--sp-5)">
          <div class="stat"><span class="msm">today</span><span class="n num">{{ stats.today_orders }}</span><span class="l">طلبات اليوم</span></div>
          <div class="stat"><span class="msm">check_circle</span><span class="n num">{{ stats.delivered }}</span><span class="l">سلّمت</span></div>
          <div class="stat"><span class="msm">directions_bike</span><span class="n num">{{ stats.delivering }}</span><span class="l">بالتوصيل حالياً</span></div>
          <div class="stat"><span class="msm">payments</span><span class="n num">{{ fmt(wallet?.collected || 0) }}</span><span class="l">كاش محصَّل اليوم</span></div>
        </div>

        <!-- الرحلات المتاحة -->
        <section style="margin-block-end:var(--sp-5)">
          <h2 class="h3" style="margin-block-end:var(--sp-3)">طلبات متاحة بالمنطقة</h2>
          <div v-if="!available.length" class="empty">
            <span class="msm">radar</span>
            <h3>ماكو طلبات بالحالي</h3>
            <p>الطلبات الجديدة تطلع هني فور وصولها — خليك أونلاين</p>
          </div>
          <div v-else class="flex-col gap-3">
            <article v-for="o in available" :key="o.id" class="order-card">
              <div class="order-head">
                <span class="num">{{ o.code }}</span>
                <span class="st-pill st-new"><span class="dot"></span>{{ fmt(o.total) }}</span>
              </div>
              <div class="order-body">
                <div class="info-row"><span class="k">🏪 المحل</span><span class="v">{{ o.store_name }}</span></div>
                <div class="info-row"><span class="k">📍 التوصيل</span><span class="v">{{ o.address_text }}</span></div>
                <div class="info-row"><span class="k">💰 تدفع كاش</span><span class="v num">{{ fmt(o.total) }}</span></div>
              </div>
              <div class="order-foot">
                <span class="text-xs text-muted">🕐 {{ fmtDate(o.created_at) }}</span>
                <button class="btn btn-accent btn-md" :disabled="busy" @click="accept(o)">قبول الطلب</button>
              </div>
            </article>
          </div>
        </section>
      </div>

      <!-- ═══ رحلتي — الرحلة النشطة ═══ -->
      <div v-else-if="tab === 'trip'">
        <section v-if="trip" class="panel" style="margin-block-end:var(--sp-5);border-color:var(--success)">
          <div class="panel-pad" style="display:flex;justify-content:space-between;align-items:center;gap:var(--sp-3);flex-wrap:wrap;background:rgba(31,157,85,.06);border-radius:var(--r-lg) var(--r-lg) 0 0">
            <b style="color:var(--success-deep)">🚚 رحلة نشطة</b>
            <div class="flex gap-2 wrap">
              <button v-if="trip.status === 'assigned' || trip.status === 'accepted'" class="btn btn-primary btn-md" @click="pickup">استلمت الطلب</button>
              <button v-if="trip.status === 'picked_up' || trip.status === 'delivering'" class="btn btn-accent btn-md" @click="delivered">تم التسليم</button>
              <button class="btn btn-ghost btn-sm" @click="load">تحديث</button>
            </div>
          </div>
          <div class="panel-pad">
            <div v-for="o in tripOrders" :key="o.id" class="line-item" v-show="o.code">
              <div class="meta">
                <span class="name">طلب {{ o.code }} — {{ fmt(o.total) }}</span>
                <span class="variant">🏪 {{ o.store_name }} ← 📍 {{ o.address_text }}</span>
              </div>
              <span class="st-pill" :class="o.status === 'delivering' ? 'st-delivering' : 'st-pending'"><span class="dot"></span>{{ o.status }}</span>
            </div>
          </div>
        </section>
        <EmptyState v-else icon="🛵" title="ماكو رحلة حالياً" sub="الطلبات الجديدة تظهر بتبويب «متاح»" />
      </div>

      <!-- ═══ المحفظة — الكاش وتقرير التسليم ═══ -->
      <div v-else-if="tab === 'wallet'" class="flex-col gap-4" style="max-width:560px">
        <div class="wallet-card">
          <div class="l">💰 وصلك من الكاش اليوم</div>
          <div class="n num">{{ fmt(wallet?.collected || 0) }}</div>
          <div class="l">عمولة المندوب: {{ fmt(wallet?.commission || 0) }} · مبلغ بعد العمولة: {{ fmt(wallet?.balance || 0) }}</div>
        </div>
        <div class="panel panel-pad">
          <h2 class="h3" style="margin-block-end:var(--sp-3)">تقرير تسليم الكاش للأدمن</h2>
          <div class="flex gap-2">
            <input v-model="reportAmount" class="input" inputmode="numeric" placeholder="المبلغ المحصَّل (د.ع)" />
            <button class="btn btn-primary btn-md" @click="reportCash">سجّل</button>
          </div>
          <div v-if="(wallet?.reports || []).length" class="flex-col gap-2" style="margin-block-start:var(--sp-4)">
            <div v-for="r in wallet.reports" :key="r.id" class="info-row">
              <span class="k">تقرير {{ r.receipt_no || '' }} · {{ timeAgo(r.created_at) }}</span>
              <span class="v num">{{ fmt(r.net) }}</span>
            </div>
          </div>
        </div>
      </div>
      </div>
    </template>
  </div>
</template>