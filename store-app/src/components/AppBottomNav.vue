<script setup>
/* ═══ الشريط السفلي — 5 تبويبات مثل التطبيق تماماً:
   الرئيسية/المتاجر/بحث/المفضلة (شارة)/حسابي — السلة صارت زر عائم (FAB) ═══
   موبايل وآيباد فقط (ديسكتوب يختفي) */
import { useApp } from '../state';

const { state } = useApp();
</script>

<template>
  <nav class="bottom-nav" aria-label="تنقل رئيسي">
    <RouterLink class="bn-item" to="/" exact-active-class="router-link-exact-active">
      <span class="msm">home</span><span>الرئيسية</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/stores">
      <span class="msm">storefront</span><span>المتاجر</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/search">
      <span class="msm">search</span><span>بحث</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/fav">
      <span class="msm">favorite</span><span>المفضلة</span>
      <span v-if="state.favsCount > 0" class="bn-badge num">{{ state.favsCount }}</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/account">
      <span class="msm">person</span><span>حسابي</span>
    </RouterLink>
  </nav>
</template>