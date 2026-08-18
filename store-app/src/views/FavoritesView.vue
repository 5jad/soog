<script setup>
/* ═══ المفضلة — المنتجات + المتاجر المفضلة ═══ */
import { ref, onMounted } from 'vue';
import { useApp } from '../state';
import { api } from '../api';
import ProdCard from '../components/ProdCard.vue';
import StoreCard from '../components/StoreCard.vue';

const { state, toast } = useApp();

const products = ref([]);
const favStores = ref([]);
const tab = ref('products');

onMounted(async () => {
  if (!state.user) return;
  try {
    const [d, s] = await Promise.all([api('/api/customer/favorites'), api('/api/customer/store-favorites')]);
    products.value = d.products || d.favorites || d || [];
    favStores.value = s.favorites || [];
  } catch (e) { toast(e.message, false); }
});

const onRemoveFav = (p) => { products.value = products.value.filter((x) => x.id !== p.id); };
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>المفضلة</h1><p class="sub">منتجات ومتاجر تحبها — ترجعها بيّ جلسة وحدة</p></div>

    <div v-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <template v-else>
      <div class="tabs">
        <button class="tab" :class="{ active: tab === 'products' }" @click="tab = 'products'">المنتجات ({{ products.length }})</button>
        <button class="tab" :class="{ active: tab === 'stores' }" @click="tab = 'stores'">المتاجر ({{ favStores.length }})</button>
      </div>

      <div v-if="tab === 'products'">
        <div v-if="products.length" class="products-grid">
          <ProdCard v-for="p in products" :key="p.id" :p="p" variant="favorites" @remove-fav="onRemoveFav" />
        </div>
        <div v-else class="empty">
          <span class="msm">favorite_border</span>
          <h3>ماكو منتجات مفضلة بعد</h3>
          <p>اضغط ♥ على أي منتج وبيه يجي هنا</p>
        </div>
      </div>

      <div v-else>
        <div v-if="favStores.length" class="stores-grid">
          <StoreCard v-for="s in favStores" :key="s.id" :s="s" />
        </div>
        <div v-else class="empty">
          <span class="msm">storefront</span>
          <h3>ماكو متاجر مفضلة</h3>
          <p>تابع متاجرك المفضلة بتوصيل أسرع</p>
        </div>
      </div>
    </template>
  </div>
</template>