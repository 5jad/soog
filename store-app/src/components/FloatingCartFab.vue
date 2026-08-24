<script setup>
/* ═══ زر السلة العائم — مثل FloatingCartFab بالتطبيق ═══
   يظهر فوق الشريط السفلي فور إضافة منتج، ويختفي عند فراغ السلة.
   موبايل/آيباد فقط — الديسكتوب يبقى على أيقونة الهيدر.
   تفاعل: نبضة 1.2 عند الإضافة + انضغاط 0.9 عند الضغط */
import { ref, watch } from 'vue';
import { useApp } from '../state';

const { state } = useApp();
const pop = ref(false);

/* نبضة عند تغير العداد (إضافة/إزالة) */
watch(() => state.cartCount, (n, o) => {
  if (n > 0 && n !== o) {
    pop.value = true;
    setTimeout(() => { pop.value = false; }, 240);
  }
});

const open = () => {
  state.cartDrawer = true;
};
</script>

<template>
  <Transition name="fab-pop">
    <button
      v-if="state.cartCount > 0"
      class="cart-fab"
      :class="{ popped: pop }"
      :aria-label="'السلة (' + state.cartCount + ')'"
      @click="open"
    >
      <span class="msm">shopping_cart</span>
      <span v-if="state.cartCount > 0" class="fab-badge num">{{ state.cartCount > 99 ? '99+' : state.cartCount }}</span>
    </button>
  </Transition>
</template>

<style scoped>
.cart-fab {
  position: fixed;
  inset-inline-end: 16px;
  z-index: var(--z-dropdown);
  width: 60px; height: 60px;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  display: grid; place-items: center;
  background: var(--primary);
  color: var(--white);
  box-shadow: 0 6px 16px rgba(35, 39, 62, .3);
  transition: transform var(--t-fast) var(--ease), box-shadow var(--t-fast) var(--ease);
  transform: scale(1);
}
.cart-fab:active { transform: scale(.9) !important; }
.cart-fab.popped { transform: scale(1.2); }
.cart-fab .msm { font-size: 27px; }
.fab-badge {
  position: absolute;
  inset-block-start: 6px;
  inset-inline-start: 6px;
  min-width: 17px; height: 17px;
  padding-inline: 4px;
  border-radius: 9px;
  background: var(--accent);
  color: var(--white);
  font-size: var(--fs-2xs);
  font-weight: 800;
  display: grid; place-items: center;
  line-height: 1;
}

/* يرتفع فوق الشريط السفلي (62px + هوامش صغيرة) */
@media (max-width: 1023.98px) { .cart-fab { bottom: calc(var(--bottomnav-h) + 22px); } }
/* ديسكتوب: مخفي — الهيدر يحمل أيقونة السلة */
@media (min-width: 1024px) { .cart-fab { display: none; } }

/* نبضة الدخول/الخروج */
.fab-pop-enter-active { transition: transform var(--t-base) var(--ease-spring), opacity var(--t-base) var(--ease); }
.fab-pop-leave-active { transition: opacity var(--t-fast) var(--ease); }
.fab-pop-enter-from { transform: scale(.5); opacity: 0; }
.fab-pop-leave-to { opacity: 0; }
</style>