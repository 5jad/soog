<script setup>
/* ═══ الحالة الفارغة — Lottie empty_state/no_results + عنوان + وصف + زر ═══ */
import LottieBox from './LottieBox.vue';

defineProps({
  icon: { type: String, default: '🛍️' },
  lottie: { type: String, default: 'empty_state' },
  title: { type: String, required: true },
  sub: { type: String, default: '' },
  action: { type: String, default: '' },
});
const emit = defineEmits(['act']);
</script>

<template>
  <div class="empty" style="padding: var(--sp-8) var(--sp-4)">
    <LottieBox :asset-key="lottie" :width="120" :height="120" :fallback="icon" />
    <h3>{{ title }}</h3>
    <p v-if="sub">{{ sub }}</p>
    <button v-if="action" class="btn btn-accent btn-md" style="margin-block-start: var(--sp-4)" @click="emit('act')">{{ action }}</button>
  </div>
</template>