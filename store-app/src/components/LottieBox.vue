<script setup>
/* ═══ غلاف Lottie الموحد — نفس قواعد التطبيق ═══
   loop مسموح فقط لـ loading_splash و main_loader · الباقي once
   تقليل الحركة (reduce motion) → يظهر الـ fallback */
import { ref, onMounted, onUnmounted, watch } from 'vue';
import lottie from 'lottie-web';

const props = defineProps({
  assetKey: { type: String, required: true },
  loop: { type: Boolean, default: false },
  width: { type: [Number, String], default: 140 },
  height: { type: [Number, String], default: 140 },
  fallback: { type: String, default: '🛍️' },
});

const PATHS = {
  loading_splash: '/store/lottie/loading_splash.json',
  main_loader: '/store/lottie/main_loader.json',
  order_success: '/store/lottie/order_success.json',
  cart_confirm: '/store/lottie/cart_confirm.json',
  empty_state: '/store/lottie/empty_state.json',
  no_results: '/store/lottie/no_results.json',
};

const allowedLoop = { loading_splash: true, main_loader: true };

const el = ref(null);
let anim = null;

const reduced = () => window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;

const play = () => {
  const path = PATHS[props.assetKey];
  if (!path || reduced()) return; /* fallback */
  if (anim) { anim.destroy(); anim = null; }
  anim = lottie.loadAnimation({
    container: el.value,
    renderer: 'svg',
    loop: props.loop && allowedLoop[props.assetKey] ? true : false,
    autoplay: true,
    path,
  });
};

onMounted(() => { if (!reduced()) play(); });
onUnmounted(() => { if (anim) { anim.destroy(); anim = null; } });
watch(() => props.assetKey, play);
</script>

<template>
  <div class="lottie-box" :style="{ width: width + 'px', height: height + 'px' }">
    <div v-show="!reduced() && PATHS[assetKey]" ref="el" :style="{ width: '100%', height: '100%' }"></div>
    <span v-if="reduced() || !PATHS[assetKey]" class="lottie-fallback" :style="{ fontSize: Math.min(52, Math.max(24, Number(height) * 0.4)) + 'px' }">{{ fallback }}</span>
  </div>
</template>

<style scoped>
.lottie-box { display: grid; place-items: center; }
.lottie-fallback { line-height: 1; user-select: none; }
</style>