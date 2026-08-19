<script setup>
/* ═══ App — الغلاف العام: هيدر + مسار + دراور السلة + دخول + توست ═══ */
import { onMounted } from 'vue';
import { useApp } from './state';
import AppHeader from './components/AppHeader.vue';
import AppBottomNav from './components/AppBottomNav.vue';
import AppFooter from './components/AppFooter.vue';
import CartDrawer from './components/CartDrawer.vue';
import LoginModal from './components/LoginModal.vue';
import FloatingCartFab from './components/FloatingCartFab.vue';

const { loadMe, refreshCartCount, refreshFavsCount, toasts } = useApp();

onMounted(async () => {
  await loadMe();
  refreshCartCount();
  refreshFavsCount();
});
</script>

<template>
  <div class="shell">
    <AppHeader />
    <main>
      <div class="with-botnav">
        <RouterView />
      </div>
    </main>
    <AppFooter />
    <AppBottomNav />
    <FloatingCartFab />

    <!-- التوست -->
    <div class="toasts">
      <TransitionGroup name="toast">
        <div v-for="t in toasts" :key="t.id" class="toast" :class="t.ok ? 'ok' : 'err'">
          <span class="msm">{{ t.ok ? 'check_circle' : 'error' }}</span>
          <span>{{ t.msg }}</span>
        </div>
      </TransitionGroup>
    </div>

    <CartDrawer />
    <LoginModal />
  </div>
</template>

<style>
.shell main { min-width: 0; }
/* انتقالات التوست */
.toast-enter-active, .toast-leave-active { transition: all var(--t-slow) var(--ease-spring); }
.toast-enter-from { opacity: 0; transform: translateY(12px) scale(.96); }
.toast-leave-to { opacity: 0; transform: translateY(8px) scale(.96); }
</style>