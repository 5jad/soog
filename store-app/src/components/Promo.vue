<script setup>
/* ═══ شريط الإعلانات (Promo) — رئيسية: بطاقات عروض المتاجر الممولة ═══ */
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { api, S } from '../api';

const router = useRouter();
const ads = ref([]);

onMounted(async () => {
  try {
    const d = await api('/api/ads');
    ads.value = (d.ads || []).filter((a) => a.status === 'active');
  } catch (_) {}
});
</script>

<template>
  <div v-if="ads.length" class="promo-row">
    <div v-for="a in ads" :key="a.id" class="promo-card" :style="{ backgroundImage: a.bg_gradient ? `linear-gradient(135deg, ${(a.bg_gradient || '').split(',')[0]?.trim() || 'var(--primary-deep)'}, ${(a.bg_gradient || '').split(',')[1]?.trim() || 'var(--primary)'})` : 'var(--grad-primary)' }" @click="a.link_url && a.link_url.startsWith('/') ? router.push(a.link_url) : null">
      <div class="promo-info">
        <span v-if="a.tag" class="promo-tag">{{ a.tag }}</span>
        <h3>{{ a.headline || a.store_name }}</h3>
        <p v-if="a.subline">{{ a.subline }}</p>
      </div>
      <img v-if="S(a.image)" class="promo-img" :src="S(a.image)" alt="" loading="lazy" />
    </div>
  </div>
</template>

<style scoped>
.promo-row { display: grid; gap: var(--sp-3); grid-template-columns: 1fr; }
@media (min-width: 768px) { .promo-row { grid-template-columns: repeat(2, 1fr); } }
.promo-card {
  position: relative;
  border-radius: var(--r-lg);
  padding: var(--sp-5) var(--sp-5);
  min-height: 150px;
  color: var(--white);
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  box-shadow: var(--sh-md);
  cursor: pointer;
  transition: transform var(--t-base) var(--ease), box-shadow var(--t-base) var(--ease);
}
.promo-card:hover { transform: translateY(-3px); box-shadow: var(--sh-lg); }
.promo-info { position: relative; z-index: 1; max-width: 60%; }
.promo-tag { background: var(--accent); color: var(--white); font-size: var(--fs-2xs); font-weight: 800; padding: 3px 10px; border-radius: var(--r-pill); }
.promo-info h3 { font-size: var(--fs-lg); margin-block: var(--sp-2); color: var(--white); }
.promo-info p { font-size: var(--fs-sm); opacity: .85; }
.promo-img { width: 96px; height: 96px; border-radius: var(--r-lg); object-fit: cover; box-shadow: var(--sh-md); flex-shrink: 0; }
</style>