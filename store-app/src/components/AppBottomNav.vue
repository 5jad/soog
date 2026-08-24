<script setup>
/* ═══ الشريط السفلي — مخصص حسب الدور (مثل تطبيق الموبايل):
   زبون/زائر: رئيسية/متاجر/بحث/سلة/مفضلة · تاجر: طلبات/منتجات/متجري/محفظة
   مندوب: متاح/رحلتي/محفظة/حسابي · أدمن: لوحة الأدمن/رئيسية/حسابي ═══ */
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useApp } from '../state';

const { state } = useApp();
const route = useRoute();

/* الفاعلية يدوية لأن تبويبات اللوحات query-based (/vendor?tab=x) */
const isBarActive = (it) => {
  if (route.path !== it.to) return false;
  if (it.tab) return route.query.tab === it.tab;
  return true;
};

const items = computed(() => {
  const r = state.user?.role;
  if (r === 'vendor') return [
    { to: '/vendor', tab: 'orders', icon: 'receipt_long', label: 'الطلبات', badge: 0 },
    { to: '/vendor', tab: 'products', icon: 'inventory_2', label: 'المنتجات', badge: 0 },
    { to: '/vendor', tab: 'store', icon: 'storefront', label: 'متجري', badge: 0 },
    { to: '/vendor', tab: 'wallet', icon: 'account_balance_wallet', label: 'المحفظة', badge: 0 },
  ];
  if (r === 'delivery') return [
    { to: '/delivery', tab: 'available', icon: 'radar', label: 'متاح', badge: 0 },
    { to: '/delivery', tab: 'trip', icon: 'route', label: 'رحلتي', badge: 0 },
    { to: '/delivery', tab: 'wallet', icon: 'account_balance_wallet', label: 'المحفظة', badge: 0 },
    { to: '/account', tab: null, icon: 'person', label: 'حسابي', badge: 0 },
  ];
  if (r === 'admin') return [
    { to: '/admin', tab: null, icon: 'admin_panel_settings', label: 'لوحة الأدمن', badge: 0, ext: true },
    { to: '/', tab: null, icon: 'home', label: 'الرئيسية', badge: 0 },
    { to: '/account', tab: null, icon: 'person', label: 'حسابي', badge: 0 },
  ];
  return [
    { to: '/', tab: null, icon: 'home', label: 'الرئيسية', badge: 0 },
    { to: '/stores', tab: null, icon: 'storefront', label: 'المتاجر', badge: 0 },
    { to: '/search', tab: null, icon: 'search', label: 'بحث', badge: 0 },
    { to: '/cart', tab: null, icon: 'shopping_bag', label: 'السلة', badge: state.cartCount },
    { to: '/fav', tab: null, icon: 'favorite', label: 'المفضلة', badge: state.favsCount },
  ];
});
</script>

<template>
  <nav class="bottom-nav" aria-label="تنقل رئيسي">
    <RouterLink v-for="it in items" :key="it.label" class="bn-item"
      :to="it.to" active-class="na" exact-active-class="na"
      :class="{ 'router-link-exact-active': isBarActive(it) }"
      :target="it.ext ? '_blank' : undefined">
      <span class="msm">{{ it.icon }}</span><span>{{ it.label }}</span>
      <span v-if="it.badge > 0" class="bn-badge num">{{ it.badge }}</span>
    </RouterLink>
  </nav>
</template>