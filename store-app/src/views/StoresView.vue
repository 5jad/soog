<script setup>
/* ═══ المتاجر — شبكة بطاقات + محل بحث سريع ═══ */
import { ref, computed, onMounted } from 'vue';
import { api } from '../api';
import { loadCategories } from '../state';
import StoreCard from '../components/StoreCard.vue';

const stores = ref([]);
const cats = ref([]);
const catId = ref(0);
const loading = ref(true);
const q = ref('');

onMounted(async () => {
  try {
    const [st, c] = await Promise.all([api('/api/stores'), loadCategories()]);
    stores.value = st.stores || [];
    cats.value = c;
  } catch (_) {}
  loading.value = false;
});

const filtered = computed(() => {
  const t = q.value.trim();
  return stores.value.filter((s) => {
    if (catId.value && s.category_id !== catId.value) return false;
    if (t && !((s.name || '').includes(t) || (s.district_name || '').includes(t))) return false;
    return true;
  });
});

const openCount = computed(() => stores.value.filter((s) => s.open_now).length);
</script>

<template>
  <div class="container-narrow">
    <div class="page-head">
      <h1>المتاجر <span class="num text-muted" style="font-size:var(--fs-base)">({{ stores.length }})</span></h1>
      <p class="sub">{{ openCount > 0 ? `مفتوح الآن: ${openCount} متجر` : 'متاجر منطقة الكوت وواسط' }}</p>
    </div>

    <!-- فلترة -->
    <div class="filter-row">
      <div class="search-pill" style="flex:1;max-width:420px;min-width:200px">
        <span class="msm">search</span>
        <input v-model="q" placeholder="ابحث باسم المتجر أو المنطقة…" />
      </div>
      <button class="chip" :class="{ active: catId === 0 }" @click="catId = 0">الكل</button>
      <button v-for="c in cats" :key="c.id" class="chip" :class="{ active: catId === c.id }" @click="catId = c.id">{{ c.icon }} {{ c.name }}</button>
    </div>

    <div v-if="loading" class="stores-grid">
      <div v-for="i in 6" :key="i" class="skeleton" style="height:230px"></div>
    </div>
    <div v-else-if="filtered.length" class="stores-grid">
      <StoreCard v-for="s in filtered" :key="s.id" :s="s" />
    </div>
    <div v-else class="empty">
      <span class="msm">storefront</span>
      <h3>ماكو متاجر مطابقة</h3>
      <p>جرب بحث ثاني أو غيّر التصنيف</p>
    </div>
  </div>
</template>