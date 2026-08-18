<script setup>
/* ═══ بطاقة المتجر — غلاف + شعار متداخل + حالة مفتوح/مغلق ═══ */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { S, isRaw, num } from '../api';

const props = defineProps({ s: { type: Object, required: true } });
const router = useRouter();

const cover = computed(() => S(props.s.cover));
const logo = computed(() => S(props.s.logo));
const logoEmoji = computed(() => (!logo.value || isRaw(logo.value)) ? (props.s.category_icon || '🏪') : '');
const open = computed(() => !!props.s.open_now || props.s.is_open);
const openLabel = computed(() => (open.value ? 'مفتوح الآن' : (props.s.next_open_label || 'مغلق')));
</script>

<template>
  <article class="store-card" @click="router.push(`/stores/${s.id}`)">
    <div class="store-cover">
      <img v-if="cover" :src="cover" :alt="s.name" loading="lazy" />
    </div>
    <div class="store-logo">
      <img v-if="logo && !isRaw(logo)" :src="logo" :alt="''" />
      <span v-else class="emoji">{{ logoEmoji }}</span>
    </div>
    <div class="store-info">
      <div class="flex between gap-2">
        <h3 class="store-name ellipsis">{{ s.name }}</h3>
        <span class="store-open" :class="open ? 'yes' : 'no'">
          <span class="dot"></span>{{ openLabel }}
        </span>
      </div>
      <div class="store-meta">
        <span v-if="s.rating > 0" class="stars">
          <span class="msm">star</span><span class="num">{{ Number(s.rating).toFixed(1) }}</span>
        </span>
        <span v-if="s.district_name">{{ s.district_name }}</span>
        <span v-if="s.delivery_fee !== undefined">{{ num(s.delivery_fee) }} د.ع توصيل</span>
      </div>
    </div>
  </article>
</template>