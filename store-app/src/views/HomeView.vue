<script setup>
/* ═══ الرئيسية — نفس ترتيب أقسام التطبيق تماماً ═══
   البانر ← محلات مميزة ← إطلالات من مشترياتك (مسجل) ← ترند اليوم ← جديدنا
   ترند اليوم شبكة كاملة بلا حد، وجديدنا شريط أفقي بصفيّن (مثل prodStrip) */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { api } from '../api';
import { useApp } from '../state';
import { bindDragScroll, usePullRefresh } from '../composables/useGestures';
import ProdCard from '../components/ProdCard.vue';
import Promo from '../components/Promo.vue';
import StoreCard from '../components/StoreCard.vue';
import OutfitCard from '../components/OutfitCard.vue';
import EmptyState from '../components/EmptyState.vue';

const { state } = useApp();
const stores = ref([]);
const best = ref([]);
const recent = ref([]);
const outfits = ref([]);
const loading = ref(true);

const load = async () => {
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
};

const storeStripEl = ref(null);
const outfitStripEl = ref(null);
const newStripEl = ref(null);
const scrollStrip = (elRef, dir) => {
  const el = elRef.value;
  if (!el) return;
  /* فحص اتجاه التمرير الفعلي (RTL يختلف بين المتصفحات) ثم نحرّك بنفس الوحدة */
  const a = el.scrollLeft;
  el.scrollLeft = a + dir;
  const moved = el.scrollLeft - a;
  el.scrollLeft = a;
  if (!moved) return;
  el.scrollBy({ left: moved * el.clientWidth * 0.8, behavior: 'smooth' });
};

onMounted(() => {
  load();
  /* سحب الشرائط بالماوس + سحب للأسفل يحدّث */
  const stops = [bindDragScroll(storeStripEl.value), bindDragScroll(outfitStripEl.value), bindDragScroll(newStripEl.value)];
  const stopPull = usePullRefresh(load);
  onBeforeUnmount(() => { stops.forEach((s) => s?.()); stopPull?.(); });
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
      <div v-else class="strip-wrap">
        <button class="strip-arrow prev" aria-label="السابق" @click="scrollStrip(storeStripEl, -1)"><span class="msm">chevron_right</span></button>
        <div ref="storeStripEl" class="store-strip">
          <StoreCard v-for="s in stores" :key="s.id" :s="s" />
        </div>
        <button class="strip-arrow next" aria-label="التالي" @click="scrollStrip(storeStripEl, 1)"><span class="msm">chevron_left</span></button>
      </div>
    </section>

    <!-- ═══ إطلالات من مشترياتك — مسجل فقط ═══ -->
    <section v-if="outfits.length" class="section" aria-labelledby="outfits-h">
      <div class="section-head"><h2 id="outfits-h">👔 إطلالات من مشترياتك</h2></div>
      <div class="strip-wrap">
        <button class="strip-arrow prev" aria-label="السابق" @click="scrollStrip(outfitStripEl, -1)"><span class="msm">chevron_right</span></button>
        <div ref="outfitStripEl" class="outfit-strip">
          <OutfitCard v-for="o in outfits" :key="(o.seed || {}).id ?? o.id" :o="o" />
        </div>
        <button class="strip-arrow next" aria-label="التالي" @click="scrollStrip(outfitStripEl, 1)"><span class="msm">chevron_left</span></button>
      </div>
    </section>

    <!-- ═══ ترند اليوم — شبكة كاملة بلا زر عرض الكل مثل التطبيق ═══ -->
    <section class="section" aria-labelledby="best-h">
      <div class="section-head"><h2 id="best-h">🔥 ترند</h2></div>
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
      <div class="strip-wrap">
        <button class="strip-arrow prev" aria-label="السابق" @click="scrollStrip(newStripEl, -1)"><span class="msm">chevron_right</span></button>
        <div ref="newStripEl" class="prod-strip-2">
          <div v-for="(pg, i) in stripPages" :key="i" class="ps2-page" :class="{ 'two': hasTwoRows && pg.length > 2 }">
            <div v-for="p in pg" :key="p.id" class="ps2-cell">
              <ProdCard :p="p" variant="home" />
            </div>
          </div>
        </div>
        <button class="strip-arrow next" aria-label="التالي" @click="scrollStrip(newStripEl, 1)"><span class="msm">chevron_left</span></button>
      </div>
    </section>

    <EmptyState v-if="!loading && !best.length && !recent.length" icon="🏪" title="ماكو منتجات بعد" sub="لحظة — المتاجر تسجّل منتجاتها هسه" />
  </div>
</template>