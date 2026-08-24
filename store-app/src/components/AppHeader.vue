<script setup>
/* ═══ هيدر متجاوب: موبايل = شعار + تنقل + سلة · ديسكتوب = شعار + تنقل + بحث + سلة ═══ */
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { getTheme, toggleTheme } from '../theme';

const { state } = useApp();
const router = useRouter();

const q = ref('');
const searching = ref(false);   /* بحث الجوال: مؤجل — صفحة /search هي المرجع */
const dark = ref(getTheme() === 'dark');

const flipTheme = () => { dark.value = toggleTheme() === 'dark'; };

const isLogged = computed(() => !!state.user);

/* كل حساب يشوف مدخل لوحته المخصصة بالهيدر مباشرة */
const panelLink = computed(() => {
  if (!state.user) return null;
  const r = state.user.role;
  if (r === 'vendor') return { label: 'لوحة التاجر', icon: 'storefront', path: '/vendor' };
  if (r === 'delivery') return { label: 'لوحة المندوب', icon: 'directions_bike', path: '/delivery' };
  if (r === 'admin') return { label: 'لوحة الأدمن', icon: 'admin_panel_settings', path: '/admin' };
  return null;
});

const doSearch = () => {
  const t = q.value.trim();
  if (!t) return;
  router.push({ path: '/search', query: { q: t } });
  searching.value = false;
};

const go = (path) => router.push(path);
</script>

<template>
  <header class="header">
    <div class="container header-in">
      <!-- الشعار -->
      <RouterLink to="/" class="logo tap" aria-label="زبون">
        <span class="logo-mark">ز</span>
        <span class="logo-text">زبون</span>
      </RouterLink>

      <!-- بحث ديسكتوب/آيباد (≥768) -->
      <form class="header-search search-desktop" @submit.prevent="doSearch">
        <span class="msm">search</span>
        <input v-model="q" type="search" placeholder="ابحث عن منتج…" />
        <button class="btn btn-primary btn-sm" type="submit" aria-label="بحث">بحث</button>
      </form>

      <!-- تنقل ديسكتوب (≥1024) -->
      <nav class="nav-links desktop-only">
        <RouterLink class="nav-link" to="/" exact-active-class="router-link-exact-active">الرئيسية</RouterLink>
        <RouterLink class="nav-link" to="/stores">المتاجر</RouterLink>
        <RouterLink class="nav-link" to="/search">بحث وفئات</RouterLink>
        <RouterLink class="nav-link" to="/fav">المفضلة</RouterLink>
      </nav>

      <!-- أفعال اليمين -->
      <div class="flex gap-2" style="margin-inline-start:auto">
        <button class="icon-btn" :aria-label="dark ? 'الوضع النهاري' : 'الوضع الليلي'" @click="flipTheme">
          <span class="msm">{{ dark ? 'light_mode' : 'dark_mode' }}</span>
        </button>
        <RouterLink v-if="panelLink" class="btn btn-soft btn-sm panel-chip mobile-hidden" :to="panelLink.path" :target="state.user.role === 'admin' ? '_blank' : undefined">
          <span class="msm">{{ panelLink.icon }}</span> {{ panelLink.label }}
        </RouterLink>
        <button v-if="!isLogged" class="btn-login mobile-hidden" @click="state.loginOpen = true">
          <span class="msm" style="font-size:18px">person</span> دخول
        </button>
        <RouterLink v-if="isLogged" class="icon-btn" to="/notifications" aria-label="الإشعارات">
          <span class="msm">notifications</span>
        </RouterLink>
        <RouterLink class="icon-btn" to="/account" aria-label="حسابي">
          <span class="msm">person</span>
        </RouterLink>

        <RouterLink class="icon-btn cart-desktop" to="/cart" aria-label="السلة">
          <span class="msm">shopping_bag</span>
          <span v-if="state.cartCount > 0" class="header-badge num">{{ state.cartCount }}</span>
        </RouterLink>
      </div>
    </div>
  </header>
</template>

<style scoped>
.search-desktop { display: none; }
@media (min-width: 768px) { .search-desktop { display: flex; max-width: 340px; } }
@media (min-width: 1024px) { .search-desktop { max-width: 420px; } }
/* السلة عنصر الديسكتوب فقط — الجوال يستخدم زر السلة بالشريط السفلي */
.cart-desktop { display: none; }
@media (min-width: 1024px) { .cart-desktop { display: grid; } }
.header .header-in { gap: var(--sp-2); }
</style>