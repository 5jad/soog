<script setup>
/* ═══ الشريط السفلي — موبايل وآيباد فقط (ديسكتوب يختفي) ═══ */
import { useApp } from '../state';

const { state } = useApp();
</script>

<template>
  <nav class="bottom-nav" aria-label="تنقل رئيسي">
    <RouterLink class="bn-item" to="/" exact-active-class="router-link-exact-active">
      <span class="msm">home</span><span>الرئيسية</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/offers">
      <span class="msm">local_fire_department</span><span>العروض</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/stores">
      <span class="msm">storefront</span><span>المتاجر</span>
    </RouterLink>
    <RouterLink class="bn-item" to="/fav">
      <span class="msm">favorite</span><span>المفضلة</span>
    </RouterLink>
    <RouterLink class="bn-item" :to="state.user ? '/account' : '/account'">
      <span class="msm">person</span><span>حسابي</span>
    </RouterLink>
  </nav>
</template>