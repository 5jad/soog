<script setup>
/* ═══ صفحة متجر — غلاف + معلومات + منتجات + كوبونات + تقييمات ═══ */
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { api, S, fmt, isRaw, num, timeAgo } from '../api';
import ProdCard from '../components/ProdCard.vue';
import EmptyState from '../components/EmptyState.vue';

const route = useRoute();
const router = useRouter();

const store = ref(null);
const products = ref([]);
const reviews = ref([]);
const coupons = ref([]);
const tab = ref('products');
const loading = ref(true);

const load = async () => {
  loading.value = true;
  try {
    const d = await api(`/api/stores/${route.params.id}`);
    store.value = d.store;
    products.value = d.products || [];
    reviews.value = d.reviews || [];
    coupons.value = (d.coupons || []).filter((c) => !c.expires_at || new Date(c.expires_at) > new Date());
  } catch (_) {}
  loading.value = false;
};
onMounted(load);
watch(() => route.params.id, load);

const cover = computed(() => store.value && S(store.value.cover));
const logo = computed(() => store.value && S(store.value.logo));
const logoEmoji = computed(() => (!logo.value || isRaw(logo.value)) ? (store.value?.category_icon || '🏪') : '');
const open = computed(() => !!store.value?.open_now || store.value?.is_open);
const openLabel = computed(() => (open.value ? 'مفتوح الآن' : (store.value?.next_open_label || 'مغلق')));
const pr = computed(() => store.value?.products_count !== undefined ? num(store.value.products_count) : products.value.length);
const rating = computed(() => Number(store.value?.rating || 0).toFixed(1));
const oneLine = (v) => String(v || '').replace(/\n/g, ' ').slice(0, 90);
</script>

<template>
  <div class="container-narrow">
    <div v-if="loading" class="flex-col gap-4" style="padding-block:var(--sp-6)">
      <div class="skeleton" style="height:260px;border-radius:var(--r-xl)"></div>
      <div class="skeleton" style="height:120px"></div>
      <div class="products-grid"><div v-for="i in 4" :key="i" class="skeleton" style="height:260px"></div></div>
    </div>

    <template v-else-if="store">
      <!-- الغلاف -->
      <section class="store-hero">
        <div class="sh-cover">
          <img v-if="cover" :src="cover" alt="" />
          <div v-else class="sh-cover-fallback"><span>{{ store.name.slice(0, 1) }}</span></div>
        </div>
        <div class="sh-info">
          <div class="sh-logo">
            <img v-if="logo && !isRaw(logo)" :src="logo" alt="" />
            <span v-else class="emoji">{{ logoEmoji }}</span>
          </div>
          <div class="sh-main">
            <h1>{{ store.name }}</h1>
            <div class="sh-meta">
              <span v-if="rating > 0" class="stars"><span class="msm">star</span><span class="num">{{ rating }}</span></span>
              <span class="text-muted">·</span>
              <span class="text-muted">{{ store.district_name }} · {{ store.governorate_name }}</span>
              <span class="store-open" :class="open ? 'yes' : 'no'"><span class="dot"></span>{{ openLabel }}</span>
              <span v-if="store.verified" class="badge badge-new" style="background:rgba(212,175,55,.18);color:var(--gold)">✓ موثق</span>
            </div>
            <p v-if="store.description" class="sh-desc">{{ oneLine(store.description) }}</p>
            <div class="sh-extra">
              <span v-if="store.delivery_fee !== undefined" class="text-sm text-muted">🚚 توصيل {{ fmt(store.delivery_fee) }}</span>
              <span v-if="store.free_delivery_min" class="text-sm text-muted">· مجاني فوق {{ fmt(store.free_delivery_min) }}</span>
              <span class="text-sm text-muted">· {{ pr }} منتج</span>
            </div>
          </div>
        </div>
      </section>

      <!-- الكوبونات -->
      <div v-if="coupons.length" class="coupon-strip">
        <span class="msm">confirmation_number</span>
        <div class="flex gap-2" style="overflow-x:auto;scrollbar-width:none">
          <span v-for="c in coupons" :key="c.id" class="coupon-chip">
            {{ c.code }} — خصم {{ c.percent ? c.percent + '%' : fmt(c.flat) }} (أدنى {{ fmt(c.min_total) }})
          </span>
        </div>
      </div>

      <!-- التبويبات -->
      <div class="tabs">
        <button class="tab" :class="{ active: tab === 'products' }" @click="tab = 'products'">المنتجات ({{ products.length }})</button>
        <button class="tab" :class="{ active: tab === 'reviews' }" @click="tab = 'reviews'">التقييمات ({{ reviews.length }})</button>
      </div>

      <div v-if="tab === 'products'">
        <div v-if="products.length" class="products-grid">
          <ProdCard v-for="p in products" :key="p.id" :p="p" :show-store="false" variant="category" />
        </div>
        <EmptyState v-else icon="📦" title="ماكو منتجات بالحالي" sub="رجع بعدين — المتجر يضيف منتجات كل فترة" />
      </div>

      <div v-else class="flex-col gap-3">
        <div v-for="r in reviews" :key="r.id" class="panel panel-pad">
          <div class="flex between gap-2" style="margin-block-end:var(--sp-2)">
            <div class="flex gap-2">
              <span class="stars"><span v-for="i in 5" :key="i" class="msm" style="font-size:16px;color: i <= r.rating ? 'var(--star)' : 'var(--line)'">star</span></span>
              <b class="text-sm">{{ r.user_name }}</b>
            </div>
            <span class="text-xs text-muted">{{ timeAgo(r.created_at) }}</span>
          </div>
          <p v-if="r.comment" class="text-sm">{{ r.comment }}</p>
        </div>
        <div v-if="!reviews.length" class="empty">
          <span class="msm">reviews</span>
          <h3>ماكو تقييمات بعد</h3>
          <p>كن أول من يقيّم هذا المتجر بعد أول طلب</p>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.store-hero { background: var(--surface); border: 1px solid var(--line); border-radius: var(--r-xl); overflow: hidden; box-shadow: var(--sh-sm); }
.sh-cover { height: 150px; position: relative; }
@media (min-width: 768px) { .sh-cover { height: 220px; } }
@media (min-width: 1440px) { .sh-cover { height: 300px; } } /* بعرض الشاشة الكامل الغلاف يحتاج ارتفاع أكبر */
.sh-cover img { width: 100%; height: 100%; object-fit: cover; }
.sh-cover-fallback { width: 100%; height: 100%; background: var(--grad-primary); display: grid; place-items: center; font-family: var(--f-disp); font-size: 64px; color: rgba(255,255,255,.85); }
.sh-info { display: flex; gap: var(--sp-3); padding: 0 var(--sp-4) var(--sp-4); align-items: flex-end; }
.sh-logo { margin-block-start: calc(var(--store-logo) / -2); width: var(--store-logo); height: var(--store-logo); border-radius: var(--r-md); border: 3px solid var(--surface); background: var(--surface); overflow: hidden; box-shadow: var(--sh-md); flex-shrink: 0; }
.sh-logo img { width: 100%; height: 100%; object-fit: cover; }
.sh-logo .emoji { width: 100%; height: 100%; display: grid; place-items: center; font-size: calc(var(--store-logo) * .5); }
.sh-main { flex: 1; min-width: 0; }
.sh-main h1 { font-size: var(--fs-2xl); }
.sh-meta { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; margin-block: var(--sp-2); font-size: var(--fs-xs); }
.sh-desc { color: var(--muted); font-size: var(--fs-sm); }
.sh-extra { margin-block-start: var(--sp-2); display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.coupon-strip { display: flex; align-items: center; gap: var(--sp-3); background: rgba(212,175,55,.1); border: 1px dashed var(--gold); border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-4); margin-block: var(--sp-5); color: var(--gold); }
.coupon-chip { background: var(--surface); border: 1px solid var(--gold); color: var(--gold); font-weight: 800; font-size: var(--fs-xs); padding: 6px 14px; border-radius: var(--r-pill); white-space: nowrap; }
</style>