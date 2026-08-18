<script setup>
/* ═══ بطاقة المنتج الموحدة — كل شبكات المنتجات تستخدمها ═══
   options: home (أيقونة الإيموجي أكبر)، category، favorites (مع زر إزالة) */
import { computed } from 'vue';
import { useApp } from '../state';
import { api, S, fmt, priceOf, pct, emojiOf, isRaw } from '../api';

const props = defineProps({
  p: { type: Object, required: true },
  variant: { type: String, default: 'default' },   /* home | category | favorites */
  showStore: { type: Boolean, default: true },
});
const emit = defineEmits(['remove-fav', 'added']);

const { state, toast, bumpCart, refreshCartCount } = useApp();

const img = computed(() => S(props.p.image || props.p.cover));
const emoji = computed(() => (!img.value || isRaw(img.value)) ? emojiOf(props.p) : '');
const off = computed(() => pct(props.p));
const sold = computed(() => props.p?.stock === 0 || props.p?.is_available === false);

const addToCart = async (e) => {
  e.stopPropagation();
  if (sold.value) return;
  if (!state.user) { toast('سجّل دخول أولاً للإضافة للسلة'); state.loginOpen = true; return; }
  try {
    const d = await api('/api/customer/cart', {
      method: 'POST',
      body: JSON.stringify({ product_id: props.p.id, qty: 1 }),
    });
    if (d.count !== undefined) state.cartCount = d.count;
    else bumpCart(1);
    toast('أُضيف للسلة');
    emit('added');
  } catch (e2) {
    toast(e2.message, false);
  }
};

const toggleFav = async (e) => {
  e.stopPropagation();
  if (!state.user) { toast('سجّل دخول أولاً للمفضلة'); state.loginOpen = true; return; }
  try {
    if (props.p.fav) {
      await api(`/api/customer/favorites/${props.p.id}`, { method: 'DELETE' });
      props.p.fav = false;
      emit('remove-fav');
    } else {
      await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: props.p.id }) });
      props.p.fav = true;
      toast('أُضيف للمفضلة');
    }
  } catch (e2) { toast(e2.message, false); }
};
</script>

<template>
  <article class="prod-card">
    <div class="img-wrap">
      <RouterLink v-if="img" :to="`/product/${p.id}`" class="img-link" :aria-label="p.name">
        <img :src="img" :alt="p.name" loading="lazy" />
      </RouterLink>
      <RouterLink v-else-if="emoji" :to="`/product/${p.id}`" class="img-link img-emoji" :aria-label="p.name">{{ emoji }}</RouterLink>
      <div class="badges">
        <span v-if="off > 0" class="badge badge-disc">خصم {{ off }}%</span>
        <span v-if="sold" class="badge badge-sold">نفد</span>
      </div>
      <button class="fav-btn" :class="{ on: p.fav }" :aria-label="p.fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة'" @click="toggleFav">
        <span class="msm">favorite</span>
      </button>
    </div>
    <div class="prod-body">
      <div v-if="showStore && p.store_name" class="prod-store">
        <img v-if="S(p.store_logo) && !isRaw(p.store_logo)" class="store-avatar" :src="S(p.store_logo)" alt="" />
        <span class="ellipsis">{{ p.store_name }}</span>
      </div>
      <h3 class="prod-name clamp-2"><RouterLink :to="`/product/${p.id}`" class="name-link">{{ p.name }}</RouterLink></h3>
      <div class="prod-bottom">
        <div class="prod-price">
          <span class="now num">{{ fmt(priceOf(p)) }}</span>
          <span v-if="off > 0" class="old">{{ fmt(p.price) }}</span>
        </div>
        <button class="fab-add" :class="{ added: sold }" :aria-label="'إضافة للسلة'" @click="addToCart">
          <span class="msm">{{ sold ? 'block' : 'add' }}</span>
        </button>
      </div>
    </div>
  </article>
</template>