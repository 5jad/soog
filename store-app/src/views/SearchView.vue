<script setup>
/* ═══ بحث وفئات — سطر بحث + زر فلترة + المنتجات مقسمة حسب الفئة ═══
   كل فئة: رأس (أيقونة + اسم + عدد) + معاينة صفّين، و«عرض الكل» يوسّعها
   عامودي بنفس الصفحة. إذا جايب ترقية بحث (?q=) تطلع النتائج عامودي مباشرة. */
import { ref, computed, onMounted, watch, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { api } from '../api';
import { loadCategories } from '../state';
import ProdCard from '../components/ProdCard.vue';
import EmptyState from '../components/EmptyState.vue';

const route = useRoute();
const products = ref([]);
const cats = ref([]);
const loading = ref(true);
const q = ref('');
const query = ref(String(route.query.q || ''));
const sort = ref('new');
const priceOpen = ref(false);
const minP = ref('');
const maxP = ref('');
const sizes = ref([]);
const colors = ref([]);
const meta = ref(null);
const expanded = ref(new Set());  // الفئات الموسّعة
const expandedAll = ref(new Map()); // منتجات الفئة الكاملة عند التوسيع
const previewN = ref(4);

const setPreviewN = () => {
  previewN.value = window.matchMedia('(min-width: 640px)').matches ? 8 : 4;
};
onMounted(() => { setPreviewN(); window.addEventListener('resize', setPreviewN); });
onUnmounted(() => window.removeEventListener('resize', setPreviewN));

/* جلب المنتجات بفلاتر الحالية — بدون كلمة بحث: الكل، وبها: النتائج */
const fetchProducts = async (opts = {}) => {
  loading.value = true;
  try {
    const params = new URLSearchParams({ limit: '100' });
    if (query.value) params.set('q', query.value);
    if (sort.value === 'price_asc' || sort.value === 'price_desc' || sort.value === 'discount' || sort.value === 'best') params.set('sort', sort.value);
    if (minP.value) params.set('min_price', minP.value);
    if (maxP.value) params.set('max_price', maxP.value);
    if (sizes.value.length) params.set('sizes', sizes.value.join(','));
    if (colors.value.length) params.set('colors', colors.value.join(','));
    const d = await api('/api/products?' + params.toString());
    products.value = d.products || [];
  } catch (_) { products.value = []; }
  loading.value = false;
};

const loadCats = async () => { cats.value = await loadCategories(); };
const loadMeta = async () => {
  try { meta.value = await api('/api/products/meta'); } catch (_) {}
};

onMounted(async () => {
  await Promise.all([loadCats(), loadMeta()]);
  fetchProducts();
});
watch(() => route.query.q, (v) => { query.value = String(v || ''); q.value = query.value; fetchProducts(); });
watch([sort, minP, maxP, sizes, colors], () => {
  expanded.value = new Set();
  expandedAll.value = new Map();
  fetchProducts();
});

/* المجموع حسب الفئة (بنفس ترتيب التصنيفات) */
const groups = computed(() => {
  const m = new Map();
  for (const p of products.value) {
    const cid = Number(p.category_id);
    if (!m.has(cid)) m.set(cid, []);
    m.get(cid).push(p);
  }
  const byCat = new Map(m);
  return cats.value
    .filter((c) => byCat.has(c.id))
    .map((c) => ({ cat: c, items: byCat.get(c.id) }));
});

const total = computed(() => products.value.length);

/* توسيع/طي فئة — يجلب كل منتجاتها بفلاتر الحالية */
const toggleExpand = async (cid) => {
  const wasOpen = expanded.value.has(cid);
  expanded.value = new Set(expanded.value);
  if (wasOpen) { expanded.value.delete(cid); return; }
  expanded.value.add(cid);
  if (expandedAll.value.has(cid)) return;
  try {
    const params = new URLSearchParams({ category_id: cid, limit: '100' });
    if (sort.value === 'price_asc' || sort.value === 'price_desc' || sort.value === 'discount' || sort.value === 'best') params.set('sort', sort.value);
    if (minP.value) params.set('min_price', minP.value);
    if (maxP.value) params.set('max_price', maxP.value);
    if (sizes.value.length) params.set('sizes', sizes.value.join(','));
    if (colors.value.length) params.set('colors', colors.value.join(','));
    const d = await api('/api/products?' + params.toString());
    expandedAll.value = new Map(expandedAll.value).set(cid, d.products || []);
  } catch (_) { expanded.value.delete(cid); expanded.value = new Set(expanded.value); }
};

const doSearch = () => {
  query.value = q.value.trim();
  if (query.value !== String(route.query.q || '')) {
    history.replaceState(null, '', '#/search' + (query.value ? `?q=${encodeURIComponent(query.value)}` : ''));
  }
  expanded.value = new Set();
  fetchProducts();
};

const toggleSize = (s) => {
  if (sizes.value.includes(s)) sizes.value = sizes.value.filter((x) => x !== s);
  else sizes.value = [...sizes.value, s];
};
const toggleColor = (c) => {
  if (colors.value.includes(c)) colors.value = colors.value.filter((x) => x !== c);
  else colors.value = [...colors.value, c];
};
const clearFilters = () => { sort.value = 'new'; minP.value = ''; maxP.value = ''; sizes.value = []; colors.value = []; };
</script>

<template>
  <div class="container-narrow">
    <div class="page-head">
      <h1>بحث وفئات <span v-if="query" class="num text-muted" style="font-size:var(--fs-base)">({{ total }})</span></h1>
      <p class="sub" v-if="!query">ابحث عن منتج أو تصفح التصنيفات — كل فئة معاينة بأول منتجاتها</p>
      <p class="sub" v-else>نتائج «{{ query }}»</p>
    </div>

    <!-- بحث + فلترة -->
    <div class="filter-row">
      <form class="search-pill" style="flex:1;max-width:480px;min-width:200px" @submit.prevent="doSearch">
        <span class="msm">search</span>
        <input v-model="q" type="search" placeholder="ابحث عن منتج…" />
        <button type="button" class="clear-x" v-if="q" aria-label="مسح" @click="q = ''"><span class="msm">close</span></button>
      </form>
      <button class="chip filter-btn" :class="{ active: priceOpen }" @click="priceOpen = !priceOpen">
        <span class="msm" style="font-size:18px">tune</span> فلتر
      </button>
    </div>

    <!-- لوحة الفلاتر -->
    <Transition name="fade-down">
      <div v-if="priceOpen" class="panel panel-pad" style="margin-block-end:var(--sp-4)">
        <div class="flex between" style="margin-block-end:var(--sp-3)">
          <label style="font-weight:800;font-size:var(--fs-sm)">الفلاتر</label>
          <button class="text-link" @click="clearFilters">مسح الكل</button>
        </div>
        <div class="flex gap-2 wrap">
          <button class="chip" :class="{ active: sort === 'new' }" @click="sort = 'new'">الأحدث</button>
          <button class="chip" :class="{ active: sort === 'best' }" @click="sort = 'best'">الأعلى تقييماً</button>
          <button class="chip" :class="{ active: sort === 'discount' }" @click="sort = 'discount'">أكبر خصم</button>
          <button class="chip" :class="{ active: sort === 'price_asc' }" @click="sort = 'price_asc'">السعر ↑</button>
          <button class="chip" :class="{ active: sort === 'price_desc' }" @click="sort = 'price_desc'">السعر ↓</button>
        </div>
        <div class="flex gap-2" style="margin-block-start:var(--sp-3)">
          <div class="field" style="flex:1"><label>أدنى سعر</label><input v-model="minP" class="input" inputmode="numeric" placeholder="من" /></div>
          <div class="field" style="flex:1"><label>أعلى سعر</label><input v-model="maxP" class="input" inputmode="numeric" placeholder="إلى" /></div>
        </div>
        <div v-if="meta && (meta.sizes || []).length" style="margin-block-start:var(--sp-3)">
          <label style="font-weight:700;font-size:var(--fs-sm)">المقاس</label>
          <div class="flex gap-2 wrap" style="margin-block-start:var(--sp-2)">
            <button v-for="s in meta.sizes" :key="s" class="chip" :class="{ active: sizes.includes(s) }" @click="toggleSize(s)">{{ s }}</button>
          </div>
        </div>
        <div v-if="meta && (meta.colors || []).length" style="margin-block-start:var(--sp-3)">
          <label style="font-weight:700;font-size:var(--fs-sm)">اللون</label>
          <div class="flex gap-2 wrap" style="margin-block-start:var(--sp-2)">
            <button v-for="c in meta.colors" :key="c" class="chip" :class="{ active: colors.includes(c) }" @click="toggleColor(c)">{{ c }}</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- نتائج البحث العامودية -->
    <template v-if="query">
      <div v-if="loading" class="products-grid">
        <div v-for="i in 8" :key="i" class="skeleton" style="aspect-ratio:.7/1;border-radius:var(--r-card)"></div>
      </div>
      <div v-else-if="products.length" class="products-grid">
        <ProdCard v-for="p in products" :key="p.id" :p="p" variant="category" />
      </div>
      <EmptyState v-else lottie="no_results" icon="🔍" title="ماكو نتائج" sub="جرب كلمات أخرى أو أزل الفلاتر" />
    </template>

    <!-- التصنيفات: كل فئة بصفّين + عرض الكل -->
    <template v-else>
      <div v-if="loading" class="products-grid">
        <div v-for="i in 8" :key="i" class="skeleton" style="aspect-ratio:.7/1;border-radius:var(--r-card)"></div>
      </div>
      <template v-else>
        <section v-for="g in groups" :key="g.cat.id" class="cat-block" aria-labelledby="'cat-h-' + g.cat.id">
          <div class="cat-head">
            <h2 :id="'cat-h-' + g.cat.id"><span class="cat-icon">{{ g.cat.icon }}</span> {{ g.cat.name }}
              <small class="num">{{ g.items.length }}</small>
            </h2>
            <button class="viewall-btn" :class="{ on: expanded.has(g.cat.id) }" @click="toggleExpand(g.cat.id)">
              <span v-if="expanded.has(g.cat.id)">طيّ <span class="msm">keyboard_arrow_up</span></span>
              <span v-else>عرض الكل <span class="msm">keyboard_arrow_down</span></span>
            </button>
          </div>
          <div class="cat-grid">
            <ProdCard
              v-for="p in (expanded.has(g.cat.id) ? (expandedAll.get(g.cat.id) || []) : g.items.slice(0, previewN))"
              :key="p.id" :p="p" variant="category"
            />
          </div>
        </section>
        <EmptyState v-if="!groups.length" icon="📦" title="ماكو منتجات بعد" sub="لحظة — المتاجر تسجّل منتجاتها هسه" />
      </template>
    </template>
  </div>
</template>