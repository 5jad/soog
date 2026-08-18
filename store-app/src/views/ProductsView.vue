<script setup>
/* ═══ صفحة المنتجات الموحدة — modes: all | cat | search | offers ═══
   ديسكتوب: سايدبار تصنيفات · موبايل: شرائح + فلتر منسدل */
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { api } from '../api';
import { loadCategories } from '../state';
import ProdCard from '../components/ProdCard.vue';

const route = useRoute();
const mode = computed(() => route.meta.mode || 'all');
const products = ref([]);
const total = ref(0);
const loading = ref(true);
const cats = ref([]);
const query = ref('');
const sort = ref('new');
const priceOpen = ref(false);
const minP = ref('');
const maxP = ref('');
const sizes = ref([]);
const colors = ref([]);
const meta = ref(null);

const loadCats = async () => { cats.value = await loadCategories(); };
const loadMeta = async () => {
  try { meta.value = await api('/api/products/meta'); } catch (_) {}
};
onMounted(() => { loadCats(); loadMeta(); });

const fetchProducts = async () => {
  loading.value = true;
  try {
    const params = new URLSearchParams({ limit: '60' });
    if (mode.value === 'cat') params.set('category_id', route.params.id);
    if (mode.value === 'search') {
      query.value = String(route.query.q || '');
      if (query.value) params.set('q', query.value);
    }
    if (mode.value === 'offers') params.set('offer', 'true');
    if (sort.value === 'price_asc' || sort.value === 'price_desc' || sort.value === 'discount' || sort.value === 'best') params.set('sort', sort.value);
    if (minP.value) params.set('min_price', minP.value);
    if (maxP.value) params.set('max_price', maxP.value);
    if (sizes.value.length) params.set('sizes', sizes.value.join(','));
    if (colors.value.length) params.set('colors', colors.value.join(','));
    const d = await api('/api/products?' + params.toString());
    products.value = d.products || [];
    total.value = d.total || 0;
  } catch (_) { products.value = []; }
  loading.value = false;
};
onMounted(fetchProducts);
watch(() => route.fullPath, fetchProducts);
watch([sort, minP, maxP, sizes, colors], fetchProducts);

const title = computed(() => {
  if (mode.value === 'search') return 'نتائج البحث';
  if (mode.value === 'offers') return 'العروض';
  if (mode.value === 'cat') { const c = cats.value.find((x) => x.id === Number(route.params.id)); return c ? c.name : 'التصنيف'; }
  return 'كل المنتجات';
});

const toggleSize = (s) => {
  if (sizes.value.includes(s)) sizes.value = sizes.value.filter((x) => x !== s);
  else sizes.value = [...sizes.value, s];
};
const toggleColor = (c) => {
  if (colors.value.includes(c)) colors.value = colors.value.filter((x) => x !== c);
  else colors.value = [...colors.value, c];
};
</script>

<template>
  <div class="container-narrow">
    <div class="page-head">
      <h1>{{ title }} <span class="num text-muted" style="font-size:var(--fs-base)">({{ total }})</span></h1>
      <p class="sub" v-if="mode === 'search' && query">نتائج «{{ query }}»</p>
    </div>

    <div class="with-sidebar">
      <!-- سايدبار التصنيفات (ديسكتوب) -->
      <aside class="sidebar">
        <div class="sidebar-card">
          <h3>التصنيفات</h3>
          <ul>
            <li><RouterLink to="/prods" exact-active-class="active">الكل</RouterLink></li>
            <li v-for="c in cats" :key="c.id">
              <RouterLink :to="`/cat/${c.id}`" :class="{ active: activeCat === c.id }">{{ c.icon }} {{ c.name }}</RouterLink>
            </li>
          </ul>
        </div>
        <div class="sidebar-card" style="margin-block-start:var(--sp-4)">
          <h3>السعر (د.ع)</h3>
          <div class="flex gap-2">
            <input v-model="minP" class="input" inputmode="numeric" placeholder="من" style="height:var(--btn-h-sm)" />
            <input v-model="maxP" class="input" inputmode="numeric" placeholder="إلى" style="height:var(--btn-h-sm)" />
          </div>
        </div>
      </aside>

      <div>
        <!-- شريط الترتيب + فتح فلتر الموبايل -->
        <div class="filter-row">
          <button class="chip" :class="{ active: sort === 'new' }" @click="sort = 'new'">الأحدث</button>
          <button class="chip" :class="{ active: sort === 'best' }" @click="sort = 'best'">الأفضل تقييماً</button>
          <button class="chip" :class="{ active: sort === 'discount' }" @click="sort = 'discount'">أكبر خصم</button>
          <button class="chip" :class="{ active: sort === 'price_asc' }" @click="sort = 'price_asc'">السعر ↑</button>
          <button class="chip" :class="{ active: sort === 'price_desc' }" @click="sort = 'price_desc'">السعر ↓</button>
          <button class="chip mobile-filter" :class="{ active: priceOpen }" @click="priceOpen = !priceOpen">
            <span class="msm" style="font-size:18px">tune</span> فلتر
          </button>
        </div>

        <!-- فلتر الموبايل منسدل -->
        <div v-if="priceOpen" class="panel panel-pad" style="margin-block-end:var(--sp-4)">
          <div class="flex gap-2">
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

        <div v-if="loading" class="products-grid">
          <div v-for="i in 8" :key="i" class="skeleton" style="height:280px"></div>
        </div>
        <div v-else-if="products.length" class="products-grid">
          <ProdCard v-for="p in products" :key="p.id" :p="p" :variant="mode" />
        </div>
        <div v-else class="empty">
          <span class="msm">search_off</span>
          <h3>ماكو نتائج</h3>
          <p>جرب كلمات أخرى أو أزل الفلاتر</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mobile-filter { display: inline-flex; }
@media (min-width: 1024px) { .mobile-filter { display: none; } }
</style>