<script setup>
/* ═══ تفاصيل طلب — عناصر + حالات + عنوان + كوبون/نقاط + استرجاع ═══ */
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, st, fmtDate, isRaw, copy } from '../api';

const route = useRoute();
const router = useRouter();
const { toast } = useApp();

const o = ref(null);
const loading = ref(true);

const load = async () => {
  try {
    const d = await api(`/api/customer/orders/${route.params.id}`);
    o.value = d.order;
  } catch (e) { toast(e.message, false); }
  loading.value = false;
};
onMounted(load);

const canCancel = computed(() => o.value && ['new', 'pending'].includes(o.value.status));
const canReturn = computed(() => o.value && o.value.status === 'delivered' && !o.value.withdrawn && !o.value.refund);
const isTracking = computed(() => o.value && ['ready', 'delivering'].includes(o.value.status));

const cancel = async () => {
  if (!confirm('متأكد تلغي الطلب؟')) return;
  try { await api(`/api/customer/orders/${o.value.id}/cancel`, { method: 'POST' }); o.value.status = 'cancelled'; toast('أُلغي الطلب'); }
  catch (e) { toast(e.message, false); }
};
const reqReturn = async () => {
  const reason = prompt('شلون المشكلة؟ (اختياري)');
  if (reason === null) return;
  try { await api(`/api/customer/orders/${o.value.id}/return`, { method: 'POST', body: JSON.stringify({ reason }) }); toast('سُجلت محاولة الاسترجاع — المندوب يتواصل معك'); }
  catch (e) { toast(e.message, false); }
};
const rate = async (it, n) => {
  try {
    await api(`/api/customer/orders/${o.value.id}/rate`, { method: 'POST', body: JSON.stringify({ item_id: it.id, rating: n }) });
    it.rating = n;
    toast(`شكراً — ${n} نجوم ⭐`);
  } catch (e) { toast(e.message, false); }
};
const copyCode = () => { if (o.value) copy(o.value.code); toast('نُسخ رمز الطلب'); };
</script>

<template>
  <div class="container-narrow">
    <div class="page-head">
      <button class="btn btn-ghost btn-sm" style="margin-block-end:var(--sp-2)" @click="router.back()">
        <span class="msm">arrow_forward</span> رجوع
      </button>
      <h1>طلب <span class="num">{{ o?.code }}</span></h1>
    </div>

    <div v-if="loading" class="loader-block"><div class="loader"></div></div>

    <div v-else-if="o" class="flex-col gap-4" style="max-width:860px">
      <!-- الحالة -->
      <section class="panel panel-pad flex between gap-3" style="flex-wrap:wrap">
        <div>
          <span class="st-pill" :class="st(o.status)[1]"><span class="dot"></span>{{ st(o.status)[0] }}</span>
          <p class="text-sm text-muted" style="margin-block-start:var(--sp-2)">{{ fmtDate(o.updated_at || o.created_at) }}</p>
        </div>
        <div class="flex gap-2 wrap">
          <button class="btn btn-soft btn-sm" @click="copyCode">نسخ الرمز</button>
          <button v-if="canCancel" class="btn btn-ghost btn-sm text-danger" @click="cancel">إلغاء الطلب</button>
          <RouterLink v-if="isTracking" class="btn btn-accent btn-sm" :to="`/orders/${o.id}/track`">🗺️ تتبع المندوب</RouterLink>
        </div>
      </section>

      <!-- المتجر والعنوان -->
      <section class="panel panel-pad flex-col gap-3">
        <div class="info-row"><span class="k"><span class="msm">storefront</span> المتجر</span><span class="v">{{ o.store_name }}</span></div>
        <div class="info-row"><span class="k"><span class="msm">location_on</span> عنوان التوصيل</span><span class="v" style="font-weight:600">{{ o.address_text }}</span></div>
        <div class="info-row"><span class="k"><span class="msm">notes</span> ملاحظة</span><span class="v" style="font-weight:600">{{ o.note || '—' }}</span></div>
        <div class="info-row"><span class="k"><span class="msm">payments</span> الدفع</span><span class="v">{{ o.payment_method === 'cod' ? 'كاش عند الاستلام' : o.payment_method }}</span></div>
      </section>

      <!-- العناصر -->
      <section class="panel panel-pad">
        <h2 class="h3" style="margin-block-end:var(--sp-2)">العناصر</h2>
        <div v-for="it in o.items" :key="it.id" class="line-item">
          <div class="th">
            <img v-if="S(it.image) && !isRaw(it.image)" :src="S(it.image)" alt="" />
          </div>
          <div class="meta">
            <span class="name">{{ it.name }}</span>
            <span v-if="it.variant" class="variant">{{ it.variant }}</span>
            <div class="prow">
              <span class="price num">{{ fmt(it.price) }} × {{ it.qty }}</span>
              <div v-if="o.status === 'delivered'" class="flex gap-1">
                <button v-for="n in 5" :key="n" class="star-rate" :class="{ on: n <= it.rating }" :aria-label="`${n} نجوم`" @click="rate(it, n)"><span class="msm">star</span></button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- الحساب -->
      <section class="panel panel-pad">
        <div class="sum-row"><span>المنتجات</span><span class="num">{{ fmt(o.subtotal) }}</span></div>
        <div class="sum-row"><span>التوصيل</span><span class="num">{{ fmt(o.delivery_fee) }}</span></div>
        <div v-if="o.coupon_discount" class="sum-row" style="color:var(--success-deep)"><span>كوبون {{ o.coupon_code }}</span><strong class="num">−{{ fmt(o.coupon_discount) }}</strong></div>
        <div v-if="o.points_discount" class="sum-row" style="color:var(--success-deep)"><span>نقاط</span><strong class="num">−{{ fmt(o.points_discount) }}</strong></div>
        <div class="sum-total"><span>الإجمالي</span><span class="num">{{ fmt(o.total) }}</span></div>
        <button v-if="canReturn" class="btn btn-outline btn-md btn-block" style="margin-block-start:var(--sp-4)" @click="reqReturn">
          استرجاع / استبدال — آخر يوم {{ fmtDate(o.deadline) }}
        </button>
        <p v-else-if="o.refund" class="text-sm" style="margin-block-start:var(--sp-3);color:var(--warning)">
          يوجد طلب استرجاع قيد المعالجة ({{ o.refund.status }})
        </p>
      </section>
    </div>
  </div>
</template>

<style scoped>
.star-rate { color: var(--line-strong); transition: color var(--t-fast) var(--ease), transform var(--t-fast) var(--ease); }
.star-rate .msm { font-size: 20px; }
.star-rate.on { color: var(--star); }
.star-rate:hover { transform: scale(1.2); }
</style>