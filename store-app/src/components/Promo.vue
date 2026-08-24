<script setup>
/* ═══ بوكس الإعلان — سلايدر تلقائي بنفس تصميم التطبيق ═══
   سلايد بعرض كامل + نقاط مؤشر + تنقل تلقائي كل 4 ثوانٍ.
   الصورة تغطي البانر، وبدونها يسقط تدرج كحلي (أو bg_gradient من الأدمن).
   النص أسفل اليمين: عنوان + سطر + اسم المتجر فوق طبقة داكنة. */
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { api, S, isRaw } from '../api';

const router = useRouter();
const ads = ref([]);
const page = ref(0);
let timer = null;

/* الإعلان الافتراضي — مثل التطبيق تماماً: بدون إعلانات فعالة
   يظهر بانر «تسوق في الشهر الفضيل» حتى لا تبقى المساحة فاضية */
const fallbackAd = {
  id: -1,
  title: '🌙 تسوق في الشهر الفضيل',
  subtitle: 'لرجالك ونسائك وأطفالك — خصومات على كل الطلبيات',
  store_name: 'زبون · الكوت',
};

onMounted(async () => {
  try {
    const d = await api('/api/ads');
    ads.value = (d.ads || []).filter((a) => a.status === 'active');
    if (ads.value.length > 1) {
      timer = setInterval(() => {
        page.value = (page.value + 1) % ads.value.length;
      }, 4000);
    }
  } catch (_) {}
});
onUnmounted(() => { if (timer) clearInterval(timer); });

const showAds = computed(() => ads.value.length ? ads.value : [fallbackAd]);
const displayed = () => showAds.value;
const cur = computed(() => displayed()[Math.min(page.value, displayed().length - 1)]);

const imgOk = (a) => { const v = S(a.image); return !!(v && !isRaw(v)); };

const go = (a) => { if (a && a.link_url && a.link_url.startsWith('/')) router.push(a.link_url); };
</script>

<template>
  <div class="ad-carousel">
    <div class="ad-stage">
      <div
        v-for="(a, i) in displayed()" :key="a.id"
        class="ad-slide" :class="{ on: i === page }"
        :style="imgOk(a) ? {} : { background: 'var(--grad-primary)' }"
        @click="go(a)"
      >
        <img v-if="imgOk(a)" :src="S(a.image)" :alt="a.headline || a.store_name" loading="lazy" />
        <div class="ad-scrim"></div>
        <div class="ad-info">
          <span v-if="a.tag" class="ad-tag">{{ a.tag }}</span>
          <h3>{{ a.title || a.headline || a.store_name }}</h3>
          <p v-if="a.subtitle || a.subline">{{ a.subtitle || a.subline }}</p>
          <small v-if="a.store_name">{{ a.store_name }}</small>
        </div>
      </div>
    </div>
    <div v-if="displayed().length > 1" class="ad-dots">
      <button
        v-for="(a, i) in displayed()" :key="a.id"
        class="ad-dot" :class="{ on: i === page }"
        :aria-label="'إعلان ' + (i + 1)"
        @click="page = i"
      ></button>
    </div>
  </div>
</template>

<style scoped>
.ad-carousel { margin-block-start: var(--sp-5); }
.ad-stage {
  position: relative;
  height: 180px; /* نفس ارتفاع بانر التطبيق */
  border-radius: var(--r-lg);
  overflow: hidden;
  box-shadow: var(--sh-md);
}
@media (min-width: 768px) { .ad-stage { height: 220px; } }
@media (min-width: 1024px) { .ad-stage { height: 300px; } }
@media (min-width: 1440px) { .ad-stage { height: 380px; } } /* بعرض الشاشة الكامل البانر يحتاج ارتفاع أكبر حتى ما يصير شريط ممطوط */
.ad-slide {
  position: absolute; inset: 0;
  opacity: 0;
  transform: scale(1.04);
  transition: opacity var(--t-slow) var(--ease-out), transform var(--t-slow) var(--ease-out);
  cursor: pointer;
  background: var(--grad-primary);
}
.ad-slide.on { opacity: 1; transform: none; z-index: 1; }
.ad-slide img { width: 100%; height: 100%; object-fit: cover; display: block; user-select: none; }
.ad-scrim { position: absolute; inset: 0; background: linear-gradient(180deg, transparent 28%, rgba(10, 17, 32, .72)); }
.ad-info { position: absolute; inset-block-end: var(--sp-3); inset-inline: var(--sp-4); color: var(--white); }
.ad-tag { display: inline-block; background: var(--accent); font-weight: 800; font-size: var(--fs-2xs); padding: 2px 10px; border-radius: var(--r-pill); margin-block-end: 5px; }
.ad-info h3 { font-size: var(--fs-xl); font-weight: 900; line-height: 1.3; }
.ad-info p { font-size: var(--fs-xs); opacity: .92; }
.ad-info small { display: block; font-size: var(--fs-2xs); opacity: .75; margin-block-start: 2px; }
.ad-dots { display: flex; justify-content: center; gap: 6px; margin-block-start: 9px; }
.ad-dot {
  width: 6px; height: 6px;
  border-radius: var(--r-pill);
  background: var(--primary);
  opacity: .22;
  border: none; padding: 0; cursor: pointer;
  transition: width var(--t-base) var(--ease), opacity var(--t-base) var(--ease);
}
.ad-dot.on { width: 17px; opacity: 1; }
</style>