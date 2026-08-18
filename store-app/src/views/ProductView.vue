<script setup>
/* ═══ صفحة المنتج — صور + مقاسات + إضافة للسلة + متجر + وصف ═══ */
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, pct, emojiOf, isRaw, timeAgo, num } from '../api';
import ProdCard from '../components/ProdCard.vue';

const route = useRoute();
const router = useRouter();
const { state, toast, refreshCartCount } = useApp();

const p = ref(null);
const loading = ref(true);
const qty = ref(1);
const variant = ref(null);
const related = ref([]);
const busy = ref(false);
const favBusy = ref(false);

const load = async () => {
  loading.value = true;
  try {
    const d = await api(`/api/products/${route.params.id}`);
    p.value = d.product;
    variant.value = null;
    if (d.product.variants?.length === 1 && !d.product.variants[0].name && !d.product.variants[0].color) variant.value = d.product.variants[0];
    const rel = await api(`/api/products?category_id=${d.product.category_id}&limit=4`);
    related.value = (rel.products || []).filter((x) => x.id !== d.product.id).slice(0, 4);
  } catch (_) {}
  loading.value = false;
};
onMounted(load);
watch(() => route.params.id, load);

const img = computed(() => p.value && S(p.value.image));
const emoji = computed(() => p.value && (!img.value || isRaw(p.value.image)) ? emojiOf(p.value) : '');
const off = computed(() => pct(p.value));
const sold = computed(() => p.value?.stock === 0 || p.value?.is_available === false);
const unitPrice = computed(() => priceOf(p.value));
const total = computed(() => unitPrice.value * qty.value);

const pickVariant = (v) => { variant.value = v; qty.value = 1; };
const variantLabel = (v) => [v.color, v.name].filter(Boolean).join(' · ');
const addToCart = async () => {
  if (!state.user) { toast('سجّل دخول أولاً للإضافة للسلة'); state.loginOpen = true; return; }
  busy.value = true;
  try {
    const body = { product_id: p.value.id, qty: qty.value };
    if (variant.value) body.variant_id = variant.value.id;
    const d = await api('/api/customer/cart', { method: 'POST', body: JSON.stringify(body) });
    if (d.count !== undefined) state.cartCount = d.count;
    else refreshCartCount();
    toast('أُضيف للسلة ✓');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

const buyNow = async () => {
  await addToCart();
  if (!state.user) return;
  setTimeout(() => { state.cartDrawer = false; router.push('/checkout'); }, 350);
};

const toggleFav = async () => {
  if (!state.user) { toast('سجّل دخول أولاً للمفضلة'); state.loginOpen = true; return; }
  favBusy.value = true;
  try {
    if (p.value.fav) { await api(`/api/customer/favorites/${p.value.id}`, { method: 'DELETE' }); p.value.fav = false; }
    else { await api('/api/customer/favorites', { method: 'POST', body: JSON.stringify({ product_id: p.value.id }) }); p.value.fav = true; toast('أُضيف للمفضلة'); }
  } catch (e) { toast(e.message, false); }
  favBusy.value = false;
};
</script>

<template>
  <div class="container-narrow">
    <div v-if="loading" class="prod-page">
      <div class="skeleton" style="aspect-ratio:1;border-radius:var(--r-xl)"></div>
      <div class="flex-col gap-4"><div class="skeleton" style="height:40px"></div><div class="skeleton" style="height:80px"></div><div class="skeleton" style="height:54px"></div></div>
    </div>

    <template v-else-if="p">
      <div class="prod-page">
        <!-- الصورة -->
        <div class="prod-gallery">
          <img v-if="img && !isRaw(p.image)" :src="img" :alt="p.name" />
          <span v-else class="emoji-big">{{ emoji }}</span>
          <div class="badges">
            <span v-if="off > 0" class="badge badge-disc">خصم {{ off }}%</span>
            <span v-if="sold" class="badge badge-sold">نفد</span>
          </div>
          <button class="fav-btn" :class="{ on: p.fav }" :disabled="favBusy" aria-label="مفضلة" @click="toggleFav">
            <span class="msm">favorite</span>
          </button>
        </div>

        <div class="flex-col gap-5">
          <!-- العنوان والسعر -->
          <div>
            <div class="prod-head-line">
              <h1 class="prod-title">{{ p.name }}</h1>
            </div>
            <p v-if="p.category_name" class="prod-sub">ضمن تصنيف {{ p.category_name }}</p>
            <div class="price-line" style="margin-block:var(--sp-4)">
              <span class="now num">{{ fmt(unitPrice) }}</span>
              <span v-if="off > 0" class="old num">{{ fmt(p.price) }}</span>
              <span v-if="off > 0" class="save">وفّرت {{ fmt(p.price - unitPrice) }}</span>
            </div>
            <div class="flex gap-3" style="font-size:var(--fs-xs);color:var(--muted);flex-wrap:wrap">
              <span v-if="p.stock !== undefined" :style="sold ? 'color:var(--danger);font-weight:800' : ''">
                {{ sold ? 'نفد المخزون' : `المخزون: ${num(p.stock)}` }}
              </span>
              <span v-if="p.sold_count">· مباع {{ num(p.sold_count) }}</span>
              <span v-if="p.rating_avg">· ⭐ {{ Number(p.rating_avg).toFixed(1) }}</span>
            </div>
          </div>

          <!-- المقاسات/الألوان -->
          <div v-if="p.variants?.length && !(p.variants.length === 1 && !p.variants[0].name && !p.variants[0].color)">
            <label style="font-weight:800;font-size:var(--fs-sm)">الاختيارات</label>
            <div class="flex gap-2 wrap" style="margin-block-start:var(--sp-2)">
              <button
                v-for="v in p.variants" :key="v.id"
                class="chip"
                :class="{ active: variant?.id === v.id }"
                :disabled="v.stock === 0"
                style="opacity: v.stock === 0 ? .45 : 1"
                @click="pickVariant(v)"
              >
                {{ variantLabel(v) }} <small v-if="v.stock === 0" style="opacity:.8">(نفد)</small>
              </button>
            </div>
          </div>

          <!-- الكمية والأزرار -->
          <div class="flex gap-3" style="flex-wrap:wrap;align-items:center">
            <div class="qty" style="padding:6px">
              <button aria-label="ناقص" @click="qty = Math.max(1, qty - 1)">−</button>
              <span class="num" style="font-size:var(--fs-md)">{{ qty }}</span>
              <button aria-label="زائد" @click="qty = Math.min(99, qty + 1)">+</button>
            </div>
            <span class="text-sm text-muted">الإجمالي: <b class="num" style="color:var(--primary)">{{ fmt(total) }}</b></span>
          </div>

          <div class="prod-actions">
            <button class="btn btn-outline btn-lg flex-1" :disabled="sold || busy" @click="addToCart">
              <span class="msm">add_shopping_cart</span> أضف للسلة
            </button>
            <button class="btn btn-accent btn-lg flex-1" :disabled="sold || busy" @click="buyNow">
              <span class="msm">flash_on</span> اشترِ الآن
            </button>
          </div>

          <!-- المتجر -->
          <RouterLink :to="`/stores/${p.store_id}`" class="store-chip">
            <div class="store-logo">
              <img v-if="S(p.store_logo) && !isRaw(p.store_logo)" :src="S(p.store_logo)" alt="" />
            </div>
            <div class="in">
              <b>{{ p.store_name }}</b>
              <small>{{ p.delivery_fee !== undefined ? `توصيل ${fmt(p.delivery_fee)}` : '' }} · {{ p.is_open ? 'مفتوح الآن' : 'مغلق' }}</small>
            </div>
            <span class="msm" style="color:var(--primary-light)">chevron_left</span>
          </RouterLink>

          <!-- الوصف -->
          <section v-if="p.description">
            <h2 class="h3" style="margin-block-end:var(--sp-2)">الوصف</h2>
            <p class="desc">{{ p.description }}</p>
          </section>
        </div>
      </div>

      <!-- منتجات مشابهة -->
      <section v-if="related.length" class="section">
        <div class="section-head"><h2>منتجات مشابهة</h2><RouterLink class="more" to="/prods">الكل <span class="msm">chevron_left</span></RouterLink></div>
        <div class="products-grid">
          <ProdCard v-for="r in related" :key="r.id" :p="r" variant="home" />
        </div>
      </section>
    </template>

    <div v-else class="empty">
      <span class="msm">block</span>
      <h3>المنتج غير موجود</h3>
      <button class="btn btn-primary btn-md" @click="router.push('/')">الرئيسية</button>
    </div>
  </div>
</template>