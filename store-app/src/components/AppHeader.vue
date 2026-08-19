<script setup>
/* ═══ هيدر متجاوب: موبايل = شعار + بحث منسدل + سلة · ديسكتوب = شعار + تنقل + بحث + سلة ═══ */
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';

const { state } = useApp();
const router = useRouter();

const q = ref('');
const searching = ref(false);   /* بحث الجوال: سطر إضافي */

const isLogged = computed(() => !!state.user);

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
        <span class="logo-text">زبون<small>WASIT</small></span>
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
        <!-- فتح بحث الجوال -->
        <button class="icon-btn search-toggle" aria-label="بحث" @click="searching = !searching">
          <span class="msm">{{ searching ? 'close' : 'search' }}</span>
        </button>

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

    <!-- بحث الجوال (سطر ثانٍ) -->
    <form v-if="searching" class="header-search mobile" @submit.prevent="doSearch">
      <span class="msm">search</span>
      <input v-model="q" type="search" placeholder="ابحث عن منتج…" autofocus />
      <span v-if="q" class="msm" style="cursor:pointer" @click="q = ''">close</span>
    </form>
  </header>
</template>

<style scoped>
.search-desktop { display: none; }
@media (min-width: 768px) { .search-desktop { display: flex; max-width: 340px; } }
@media (min-width: 1024px) { .search-desktop { max-width: 420px; } }
.search-toggle { display: grid; }
@media (min-width: 768px) { .search-toggle { display: none; } }
/* السلة عنصر الديسكتوب فقط — الجوال يستخدم الزر العائم مثل التطبيق */
.cart-desktop { display: none; }
@media (min-width: 1024px) { .cart-desktop { display: grid; } }
.header .header-in { gap: var(--sp-2); }
</style>