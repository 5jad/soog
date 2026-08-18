<script setup>
/* ═══ الرئيسية — Hero + تصنيفات + إعلانات + متاجر + عروض + وصل حديثاً ═══
   ترتيب الأقسام حسب الشاشة: موبايل = شرائح · ديسكتوب = شبكات أوسع */
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { api } from '../api';
import { loadCategories } from '../state';
import ProdCard from '../components/ProdCard.vue';
import StoreCard from '../components/StoreCard.vue';
import Promo from '../components/Promo.vue';

const router = useRouter();
const categories = ref([]);
const stores = ref([]);
const offers = ref([]);
const newProds = ref([]);
const loading = ref(true);

onMounted(async () => {
  try {
    const [cats, st, of, np] = await Promise.all([
      loadCategories(),
      api('/api/stores?limit=8'),
      api('/api/offers?limit=8'),
      api('/api/products?limit=8'),
    ]);
    categories.value = cats;
    stores.value = (st.stores || []).slice(0, 8);
    offers.value = (of.products || []).slice(0, 8);
    newProds.value = (np.products || []).slice(0, 8);
  } catch (_) {}
  loading.value = false;
});
</script>

<template>
  <div class="container-narrow">
    <!-- ═══ Hero ═══ -->
    <section class="hero">
      <div class="hero-inner">
        <span class="hero-pill">🚚 توصيل 30–60 دقيقة داخل الكوت</span>
        <h1>كل ما تتمناه<br /><em>بمكان واحد</em></h1>
        <p>متاجر منطقتك على موبايلك — ملابس، مكياج، ألعاب، إلكترونيات… ادفع كاش عند الاستلام.</p>
        <div class="hero-actions">
          <button class="btn btn-accent btn-lg" @click="router.push('/stores')">
            تصفح المتاجر <span class="msm">arrow_back</span>
          </button>
          <button class="btn hero-ghost btn-lg" @click="router.push('/offers')">
            🔥 عروض اليوم
          </button>
        </div>
        <div class="hero-stats">
          <div><b class="num">60+</b><span>متجر محلي</span></div>
          <div><b class="num">2,000+</b><span>منتج</span></div>
          <div><b class="num">15</b><span>دقيقة توصيل سريع</span></div>
        </div>
      </div>
      <div class="hero-blob b1"></div>
      <div class="hero-blob b2"></div>
    </section>

    <!-- ═══ التصنيفات ═══ -->
    <section class="section" aria-labelledby="cats">
      <div class="section-head">
        <h2 id="cats">التصنيفات</h2>
      </div>
      <div v-if="loading" class="chips-row">
        <div v-for="i in 6" :key="i" class="skeleton" style="width:120px;height:44px;border-radius:var(--r-pill);flex-shrink:0"></div>
      </div>
      <div v-else class="chips-row">
        <RouterLink v-for="c in categories" :key="c.id" class="chip" :to="`/cat/${c.id}`">
          <span>{{ c.icon || '🛍️' }}</span>{{ c.name }}
        </RouterLink>
      </div>
    </section>

    <!-- ═══ الإعلانات ═══ -->
    <section v-if="!loading" class="section">
      <Promo />
    </section>

    <!-- ═══ المتاجر المقترحة ═══ -->
    <section class="section" aria-labelledby="stores-h">
      <div class="section-head">
        <h2 id="stores-h">متاجر مميزة</h2>
        <RouterLink class="more" to="/stores">الكل <span class="msm">chevron_left</span></RouterLink>
      </div>
      <div v-if="loading" class="stores-grid">
        <div v-for="i in 4" :key="i" class="skeleton" style="height:230px"></div>
      </div>
      <div v-else-if="stores.length" class="stores-grid">
        <StoreCard v-for="s in stores" :key="s.id" :s="s" />
      </div>
    </section>

    <!-- ═══ العروض ═══ -->
    <section class="section" aria-labelledby="offers-h">
      <div class="section-head">
        <h2 id="offers-h">🔥 عروض اليوم</h2>
        <RouterLink class="more" to="/offers">الكل <span class="msm">chevron_left</span></RouterLink>
      </div>
      <div v-if="loading" class="products-grid">
        <div v-for="i in 4" :key="i" class="skeleton" style="height:260px"></div>
      </div>
      <div v-else-if="offers.length" class="products-grid">
        <ProdCard v-for="p in offers" :key="p.id" :p="p" variant="home" />
      </div>
    </section>

    <!-- ═══ وصل حديثاً ═══ -->
    <section class="section" aria-labelledby="new-h">
      <div class="section-head">
        <h2 id="new-h">وصل حديثاً</h2>
        <RouterLink class="more" to="/prods">الكل <span class="msm">chevron_left</span></RouterLink>
      </div>
      <div v-if="loading" class="products-grid">
        <div v-for="i in 4" :key="i" class="skeleton" style="height:260px"></div>
      </div>
      <div v-else-if="newProds.length" class="products-grid">
        <ProdCard v-for="p in newProds" :key="p.id" :p="p" variant="home" />
      </div>
    </section>
  </div>
</template>

<style scoped>
/* ═══ Hero — تدرج كحلي زجاجي مع هالات مضيئة ═══ */
.hero {
  position: relative;
  overflow: hidden;
  border-radius: var(--r-xl);
  background: var(--grad-hero);
  color: var(--white);
  padding: var(--sp-7) var(--sp-5);
  margin-block-start: var(--sp-5);
  box-shadow: var(--sh-lg);
}
@media (min-width: 768px) { .hero { padding: var(--sp-9) var(--sp-8); } }
@media (min-width: 1024px) { .hero { padding: var(--sp-10) var(--sp-9); } }
.hero-inner { position: relative; z-index: 2; max-width: 640px; }
.hero-pill {
  display: inline-flex; align-items: center;
  background: rgba(255,255,255,.14);
  border: 1px solid rgba(255,255,255,.22);
  -webkit-backdrop-filter: var(--glass-blur);
  backdrop-filter: var(--glass-blur);
  padding: 6px 14px;
  border-radius: var(--r-pill);
  font-size: var(--fs-xs);
  font-weight: 700;
}
.hero h1 { color: var(--white); font-size: var(--fs-4xl); font-weight: 900; margin-block: var(--sp-4); }
.hero h1 em { font-style: normal; background: var(--grad-gold); -webkit-background-clip: text; background-clip: text; color: transparent; }
.hero p { font-size: var(--fs-md); opacity: .9; max-width: var(--measure); }
.hero-actions { display: flex; gap: var(--sp-3); flex-wrap: wrap; margin-block: var(--sp-6); }
.hero-ghost { background: rgba(255,255,255,.14); color: var(--white); border: 1px solid rgba(255,255,255,.25); }
.hero-ghost:hover { background: rgba(255,255,255,.22); }
.hero-stats { display: flex; gap: var(--sp-6); flex-wrap: wrap; }
.hero-stats b { display: block; font-family: var(--f-disp); font-size: var(--fs-xl); }
.hero-stats span { font-size: var(--fs-xs); opacity: .8; }
.hero-blob { position: absolute; border-radius: 50%; filter: blur(2px); }
.b1 { inset-inline-end: -8%; inset-block-start: -30%; width: 46%; aspect-ratio: 1; background: radial-gradient(circle, rgba(74,111,165,.5), transparent 70%); }
.b2 { inset-inline-start: 30%; inset-block-end: -55%; width: 40%; aspect-ratio: 1; background: radial-gradient(circle, rgba(242,86,15,.28), transparent 70%); }
</style>