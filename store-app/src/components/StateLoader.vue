<script setup>
/* ═══ لودر زجاجي — دائرة blur + سكوتر التوصيل (مثل التطبيق) ═══ */
import LottieBox from './LottieBox.vue';

const props = defineProps({
  width: { type: Number, default: 96 },
  height: { type: Number, default: 96 },
});
</script>

<template>
  <div class="loader-glass-wrap">
    <div class="loader-glass">
      <LottieBox asset-key="main_loader" :loop="true" :width="props.width" :height="props.height" fallback="🛵" />
    </div>
  </div>
</template>

<style scoped>
.loader-glass-wrap {
  display: grid;
  place-items: center;
  padding: 40px;
}
.loader-glass {
  width: 120px;
  height: 120px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgba(255, 255, 255, 0.55);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.6);
  box-shadow: var(--sh-md);
}
</style>