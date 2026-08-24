<script setup>
/* ═══ انفجار «أُضيف للسلة» — تعتيم + ضباب خلفية + نبضة cart_confirm مركزية
   (مثل addPop بالتطبيق) — يختفي بعد 1.6 ثانية */
import { ref, watch, onUnmounted } from 'vue';
import { useApp } from '../state';
import LottieBox from './LottieBox.vue';

const { state } = useApp();
const show = ref(false);
let hideTimer = null;

watch(() => state.cartPop, (n) => {
  if (n === 0) return;
  show.value = true;
  if (hideTimer) clearTimeout(hideTimer);
  hideTimer = setTimeout(() => { show.value = false; }, 1600);
});

onUnmounted(() => { if (hideTimer) clearTimeout(hideTimer); });
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="show" class="cart-pop-mask">
        <div class="cart-pop-blur"></div>
        <div class="cart-pop-center">
          <LottieBox asset-key="cart_confirm" :width="240" :height="240" fallback="🛍️" />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.cart-pop-mask {
  position: fixed;
  inset: 0;
  z-index: 4000;
  pointer-events: none;
}
.cart-pop-blur {
  position: absolute;
  inset: 0;
  background: rgba(10, 17, 32, 0.2);
  backdrop-filter: blur(2.5px);
  -webkit-backdrop-filter: blur(2.5px);
}
.cart-pop-center {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
}
.fade-enter-active, .fade-leave-active { transition: opacity var(--t-base) var(--ease); }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>