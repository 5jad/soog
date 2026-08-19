<script setup>
/* ═══ الرئيسية — نفس ترتيب أقسام التطبيق تماماً ═══
   البانر ← محلات مميزة ← إطلالات من مشترياتك (مسجل) ← ترند اليوم ← جديدنا
   ترند اليوم شبكة كاملة بلا حد، وجديدنا شريط أفقي بصفيّن (مثل prodStrip) */
import { ref, computed, onMounted } from 'vue';
import { api } from '../api';
import { useApp } from '../state';
import ProdCard from '../components/ProdCard.vue';
import Promo from '../components/Promo.vue';
import StoreCard from '../components/StoreCard.vue';
import OutfitCard from '../components/OutfitCard.vue';

const { state } = useApp();
const stores = ref([]);
const best = ref([]);
const recent = ref([]);
const outfits = ref([]);
const loading = ref(true);

onMounted(async () => {
  try {
    const [s, b, r] = await Promise.all([
      api('/api/stores'),
      api('/api/products?best=true'),
      api('/api/products'),
    ]);
    stores.value = s.stores || [];
    best.value = (b.products || []).slice(0, 24);
    recent.value = r.products || [];
    if (state.user) {
      try {
        const o = await api('/api/outfit/for-me');
        outfits.value = o.outfits || [];
      } catch (_) {}
    }
  } catch (_) {}
  loading.value = false;
});

/* صفحة شريط «جديدنا» — كل صفحة 2×2 (مثل prodStrip بالتطبيق) */
const stripPages = computed(() => {
  const pages = [];
  for (let i = 0; i < recent.value.length; i += 4) {
    pages.push(recent.value.slice(i, i + 4));
  }
  return pages;
});
const hasTwoRows = computed(() => recent.value.length >= 3);
</script>

<template>
  <div class="container-narrow">
    <!-- ═══ البانر الرئيسي — سلايدر تلقائي ═══ -->
    <Promo v-if="!loading" />

    <!-- ═══ محلات مميزة — شريط أفقي موبايل / شبكة ديسكتوب ═══ -->
    <section v-if="loading || stores.length" class="section" aria-labelledby="stores-h">
      <div class="section-head"><h2 id="stores-h">⭐ محلات مميزة</h2></div>
      <div v-if="loading" class="store-strip">
        <div v-for="i in 4" :key="i" class="skeleton" style="flex:0 0 210px;aspect-ratio:1.1/1;border-radius:var(--r-card)"></div>
      </div>
      <div v-else class="store-strip">
        <StoreCard v-for="s in stores" :key="s.id" :s="s" />
      </div>
    </section>

    <!-- ═══ إطلالات من مشترياتك — مسجل فقط ═══ -->
    <section v-if="outfits.length" class="section" aria-labelledby="outfits-h">
      <div class="section-head"><h2 id="outfits-h">👔 إطلالات من مشترياتك</h2></div>
      <div class="outfit-strip">
        <OutfitCard v-for="o in outfits" :key="(o.seed || {}).id ?? o.id" :o="o" />
      </div>
    </section>

    <!-- ═══ ترند اليوم — شبكة كاملة بلا زر عرض الكل مثل التطبيق ═══ -->
    <section class="section" aria-labelledby="best-h">
      <div class="section-head"><h2 id="best-h">🔥 ترند اليوم</h2></div>
      <div v-if="loading" class="products-grid">
        <div v-for="i in 4" :key="i" class="skeleton" style="aspect-ratio:.7/1;border-radius:var(--r-card)"></div>
      </div>
      <div v-else-if="best.length" class="products-grid">
        <ProdCard v-for="p in best" :key="p.id" :p="p" variant="home" />
      </div>
    </section>

    <!-- ═══ جديدنا — شريط أفقي بصفيّن ═══ -->
    <section v-if="recent.length" class="section" aria-labelledby="new-h">
      <div class="section-head"><h2 id="new-h">✨ جديدنا</h2></div>
      <div class="prod-strip-2">
        <div v-for="(pg, i) in stripPages" :key="i" class="ps2-page" :class="{ 'two': hasTwoRows && pg.length > 2 }">
          <div v-for="p in pg" :key="p.id" class="ps2-cell">
            <ProdCard :p="p" variant="home" />
          </div>
        </div>
      </div>
    </section>

    <div v-if="!loading && !best.length && !recent.length" class="empty">
      <span class="msm">storefront</span>
      <h3>ماكو منتجات بعد</h3>
      <p>لحظة — المتاجر تسجّل منتجاتها هسه</p>
    </div>
  </div>
</template>