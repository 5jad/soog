<script setup>
/* ═══ طلباتي — بطاقات الطلبات مع الحالة والإجراءات ═══ */
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, st, fmtDate, isRaw } from '../api';
import { usePullRefresh } from '../composables/useGestures';
import EmptyState from '../components/EmptyState.vue';
import StateLoader from '../components/StateLoader.vue';

const { state, toast } = useApp();
const router = useRouter();

const orders = ref([]);
const loading = ref(true);

const load = async () => {
  if (!state.user) { loading.value = false; return; }
  loading.value = true;
  try {
    const d = await api('/api/customer/orders');
    orders.value = d.orders || d || [];
  } catch (_) { orders.value = []; }
  loading.value = false;
};

onMounted(() => {
  load();
  const stopPull = usePullRefresh(load);   /* سحب للأسفل يحدّث */
  onBeforeUnmount(() => stopPull?.());
});

const itemsOf = (o) => o.items || [];
const cancel = async (o) => {
  if (!confirm('متأكد تلغي الطلب؟')) return;
  try {
    await api(`/api/customer/orders/${o.id}/cancel`, { method: 'POST' });
    o.status = 'cancelled';
    toast('أُلغي الطلب');
  } catch (e) { toast(e.message, false); }
};
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>طلباتي</h1><p class="sub">تابع طلباتك وتوصيلها</p></div>

    <div v-if="loading && !orders.length" class="loader-block"><StateLoader /></div>
    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>
<EmptyState v-else-if="!orders.length" icon="🧾" title="ماكو طلبات بعد" sub="أول طلبك وبصير بالبيج هذا مباشرة" />

    <div v-else class="flex-col gap-4" style="max-width:860px">
      <article v-for="o in orders" :key="o.id" class="order-card">
        <div class="order-head">
          <div class="flex-col gap-1">
            <span class="num">{{ o.code }}</span>
            <span class="date">{{ fmtDate(o.created_at) }}</span>
          </div>
          <div class="flex gap-2">
            <span v-if="o.payment_method === 'cod'" class="text-xs text-muted">كاش</span>
            <span class="st-pill" :class="st(o.status)[1]"><span class="dot"></span>{{ st(o.status)[0] }}</span>
          </div>
        </div>
        <div class="order-body">
          <div v-if="itemsOf(o).length" class="order-items">
            <RouterLink v-for="it in itemsOf(o)" :key="it.id" :to="`/product/${it.product_id}`" class="th" :title="it.name">
              <img v-if="S(it.image) && !isRaw(it.image)" :src="S(it.image)" alt="" loading="lazy" />
            </RouterLink>
          </div>
          <div class="flex between gap-3 wrap">
            <span class="order-type"><span class="msm" style="font-size:16px">storefront</span> {{ o.store_name || `متجر #${o.store_id}` }}</span>
            <span class="total num">الإجمالي {{ fmt(o.total) }}</span>
          </div>
        </div>
        <div class="order-actions">
          <button class="btn btn-primary btn-sm" @click="router.push(`/orders/${o.id}`)">التفاصيل</button>
          <button v-if="['new','pending'].includes(o.status)" class="btn btn-ghost btn-sm text-danger" @click="cancel(o)">إلغاء</button>
          <RouterLink v-else-if="o.status === 'ready'" class="btn btn-soft btn-sm" :to="`/orders/${o.id}/track`">تتبع المندوب</RouterLink>
          <RouterLink v-else-if="o.status === 'delivering'" class="btn btn-soft btn-sm" :to="`/orders/${o.id}/track`">تتبع المندوب</RouterLink>
        </div>
      </article>
    </div>
  </div>
</template>