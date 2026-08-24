<script setup>
/* ═══ بطاقة المتجر — البطاقة المصغرة بتصميم التطبيق ═══
   غلاف كامل (صورة أو تدرج بلون حسب ترتيب المتجر) + طبقة داكنة +
   شعار في بوكس أبيض أعلى + اسم وتقييم أسفل فوق الغلاف */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { S, isRaw } from '../api';

const props = defineProps({ s: { type: Object, required: true } });
const router = useRouter();

/* ألوان الغلاف المتناوبة — نفس ألوان التطبيق الأربعة */
const covers = ['#8B3A62', '#D45B8A', '#23273E', '#1789A6'];

const hasCover = computed(() => { const v = S(props.s.cover); return !!(v && !isRaw(v)); });
const cover = computed(() => S(props.s.cover));
const logo = computed(() => S(props.s.logo));
const logoEmoji = computed(() => (!logo.value || isRaw(logo.value)) ? (props.s.category_icon || '🏪') : '');
const grad = computed(() => {
  const id = Number(props.s.id) || 0;
  const c = covers[Math.abs(id) % covers.length];
  return `linear-gradient(135deg, ${c}, #F4C9D8)`;
});
</script>

<template>
  <article class="store-card" @click="router.push(`/stores/${s.id}`)">
    <div class="store-cover" :style="hasCover ? {} : { background: grad }">
      <img v-if="hasCover" :src="cover" :alt="s.name" loading="lazy" />
      <div class="cover-scrim"></div>
      <div class="store-logo">
        <img v-if="logo && !isRaw(logo)" :src="logo" :alt="''" />
        <span v-else class="emoji">{{ logoEmoji }}</span>
      </div>
      <div class="cover-info">
        <h3 class="store-name ellipsis">{{ s.name }}</h3>
        <div class="cover-meta">
          <span class="stars">
            <span class="msm">star</span>
            <span class="num">{{ (Number(s.rating) || 0).toFixed(1) }}</span>
          </span>
          <span class="reviews">• {{ s.reviews_count || 0 }} تقييم</span>
        </div>
      </div>
    </div>
  </article>
</template>