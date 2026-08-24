<script setup>
/* ═══ بطاقة المنتج الموحدة — بنفس تصميم ProdCard بالتطبيق ═══
   home: اسم بسطر + نقاط المتغيرات + سعر ink (بلا اسم متجر)
   category: اسم المتجر + اسم بسطرين + سعر أكبر (بلا نقاط)
   favorites: كـ home + اسم المتجر + قلب أسفل الصورة */
import { computed } from 'vue';
import { useApp } from '../state';
import { api, S, fmt, priceOf, pct, emojiOf, isRaw } from '../api';

const props = defineProps({
  p: { type: Object, required: true },
  variant: { type: String, default: 'home' },   /* home | category | favorites */
  showStore: { type: Boolean, default: true },
});
const emit = defineEmits(['remove-fav', 'added']);

const { state, toast, bumpCart, refreshCartCount, bumpFavs, cartPop } = useApp();

const img = computed(() => S(props.p.image || props.p.cover));
const emoji = computed(() => (!img.value || isRaw(img.value)) ? emojiOf(props.p) : '');
const off = computed(() => pct(props.p));
const sold = computed(() => props.p?.stock === 0 || props.p?.is_available === false);

const isHome = computed(() => props.variant === 'home');
const isFav = computed(() => props.variant === 'favorites');
const isCat = computed(() => !isHome.value && !isFav.value);
/* نقاط ألوان المتغيرات (مثل شي إن) — home/favorites فقط */
const dots = computed(() => {
  const vs = props.p.variants || [];
  const out = [];
  for (const v of vs) {
    const c = dotColor(v?.color || v?.name);
    if (!out.includes(c)) out.push(c);
  }
  return out.slice(0, 4);
});
const dotsMore = computed(() => {
  const vs = props.p.variants || [];
  const out = [];
  for (const v of vs) {
    const c = dotColor(v?.color || v?.name);
    if (!out.includes(c)) out.push(c);
  }
  return out.length > 4 ? out.length - 4 : 0;
});

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
    cartPop();
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
      bumpFavs(-1);
      emit('remove-fav');
    } else {
      await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: props.p.id }) });
      props.p.fav = true;
      bumpFavs(1);
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
      <button v-if="isFav" class="fav-btn card-fav" :class="{ on: p.fav }" :aria-label="p.fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة'" @click="toggleFav">
        <span class="msm">favorite</span>
      </button>
    </div>
    <div class="prod-body">
      <span v-if="showStore && !isHome && p.store_name" class="prod-store ellipsis">{{ p.store_name }}</span>
      <h3 class="prod-name" :class="isCat ? 'l2' : 'l1'">
        <RouterLink :to="`/product/${p.id}`" class="name-link">{{ p.name }}</RouterLink>
      </h3>
      <div v-if="(isHome || isFav) && dots.length" class="prod-dots">
        <span v-for="(c, i) in dots" :key="i" class="pdot" :style="{ background: c }"></span>
        <span v-if="dotsMore" class="dots-more">+{{ dotsMore }}</span>
      </div>
      <span v-if="off > 0" class="prod-old num">{{ fmt(p.price) }}</span>
      <div class="prod-bottom">
        <span class="now num">{{ fmt(priceOf(p)) }}</span>
        <button class="fab-add" :class="{ off: sold }" :disabled="sold" :aria-label="'إضافة للسلة'" @click="addToCart">
          <span class="msm">{{ sold ? 'block' : 'add' }}</span>
        </button>
      </div>
    </div>
  </article>
</template>

<script>
/* لون تقريبي لأسماء الألوان العربية الشائعة — نفس خريطة التطبيق */
function dotColor(name) {
  const n = String(name || '').toLowerCase().trim();
  const map = {
    'أحمر': '#E7352B', 'احمر': '#E7352B', 'red': '#E7352B',
    'أزرق': '#2453CB', 'ازرق': '#2453CB', 'blue': '#2453CB',
    'أسود': '#202126', 'اسود': '#202126', 'black': '#202126',
    'أبيض': '#F5F5F5', 'ابيض': '#F5F5F5', 'white': '#F5F5F5',
    'أخضر': '#1E8A4C', 'اخضر': '#1E8A4C', 'green': '#1E8A4C',
    'أصفر': '#F2C513', 'اصفر': '#F2C513', 'yellow': '#F2C513',
    'بنفسجي': '#7C3AED', 'بنفسجية': '#7C3AED', 'purple': '#7C3AED',
    'وردي': '#F472B6', 'وردية': '#F472B6', 'pink': '#F472B6',
    'رمادي': '#9CA3AF', 'رمادية': '#9CA3AF', 'grey': '#9CA3AF',
    'بني': '#7C4A23', 'بنية': '#7C4A23', 'brown': '#7C4A23',
    'برتقالي': '#F97316', 'برتقالية': '#F97316', 'orange': '#F97316',
  };
  for (const k in map) { if (n.includes(k)) return map[k]; }
  return '#D9DEE7';
}
</script>