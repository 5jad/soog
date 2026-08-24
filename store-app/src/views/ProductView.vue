<script setup>
/* ═══ صفحة المنتج — صور + مقاسات + إضافة للسلة + متجر + وصف ═══ */
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, pct, emojiOf, isRaw, timeAgo, num } from '../api';
import ProdCard from '../components/ProdCard.vue';

const route = useRoute();
const router = useRouter();
const { state, toast, refreshCartCount, cartPop } = useApp();

const p = ref(null);
const loading = ref(true);
const qty = ref(1);
const variant = ref(null);
const related = ref([]);
const outfit = ref(null);
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
    // معاينة الإطلالة المقترحة — تظهر لو القطعة من الأزياء (نفس شرط التطبيق)
    try {
      const o = await api(`/api/outfit/${d.product.id}`);
      if ((o.outfit?.slots || []).length > 1) outfit.value = o;
    } catch (_) {}
  } catch (_) {}
  loading.value = false;
};
onMounted(load);
watch(() => route.params.id, load);

const goOutfit = () => router.push(`/outfit/${route.params.id}`);

const img = computed(() => p.value && S(p.value.image));
const emoji = computed(() => p.value && (!img.value || isRaw(p.value.image)) ? emojiOf(p.value) : '');
const images = computed(() => {
  const raw = (p.value?.images && Array.isArray(p.value.images) && p.value.images.length)
    ? p.value.images : [];
  const ims = raw.map(S).filter(Boolean).filter((v) => !isRaw(v));
  if (ims.length) return ims;
  return img.value && !isRaw(p.value.image) ? [img.value] : [];
});
const activeImg = ref(0);
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
    cartPop();
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
      <div class="skeleton" style="aspect-ratio:3/4;border-radius:var(--r-xl)"></div>
      <div class="flex-col gap-4"><div class="skeleton" style="height:40px"></div><div class="skeleton" style="height:80px"></div><div class="skeleton" style="height:54px"></div></div>
    </div>

    <template v-else-if="p">
      <div class="prod-page">
        <!-- الصورة -->
        <div class="prod-gallery">
          <div v-for="(im, i) in images" :key="i" class="gallery-slide" :class="{ on: i === activeImg }">
            <img :src="im" :alt="p.name" />
          </div>
          <span v-if="!images.length" class="emoji-big">{{ emoji }}</span>
          <div class="badges">
            <span v-if="off > 0" class="badge badge-disc">خصم {{ off }}%</span>
            <span v-if="sold" class="badge badge-sold">نفد</span>
          </div>
          <button class="fav-btn" :class="{ on: p.fav }" :disabled="favBusy" aria-label="مفضلة" @click="toggleFav">
            <span class="msm">favorite</span>
          </button>
          <div v-if="images.length > 1" class="gallery-dots">
            <button
              v-for="(im, i) in images" :key="i"
              class="gd" :class="{ on: i === activeImg }"
              :aria-label="'صورة ' + (i + 1)"
              @click="activeImg = i"
            ></button>
          </div>
        </div>

        <div class="flex-col gap-5">
          <!-- المتجر + العنوان والسعر -->
          <div>
            <RouterLink :to="`/stores/${p.store_id}`" class="prod-store-line">
              <span class="msm">storefront</span>
              <span class="ellipsis">{{ p.store_name }}</span>
              <span v-if="p.rating_avg" class="store-rate">
                <span class="msm" style="font-size:13px;color:var(--star)">star</span>
                {{ Number(p.rating_avg).toFixed(1) }}
              </span>
            </RouterLink>
            <div class="prod-head-line">
              <h1 class="prod-title">{{ p.name }}</h1>
            </div>
            <p v-if="p.category_name" class="prod-sub">ضمن تصنيف {{ p.category_name }}</p>
            <div class="price-line" style="margin-block:var(--sp-4)">
              <span class="now num">{{ fmt(unitPrice) }}</span>
              <span v-if="off > 0" class="old num">{{ fmt(p.price) }}</span>
              <span v-if="off > 0" class="badge badge-disc">خصم {{ off }}%</span>
            </div>
            <small v-if="off > 0" class="saved">وفّرت {{ fmt(p.price - unitPrice) }} 🎉</small>
            <div class="flex gap-3" style="font-size:var(--fs-xs);color:var(--muted);flex-wrap:wrap;align-items:center;margin-block-start:var(--sp-1)">
              <span v-if="p.stock !== undefined" class="stock-pill" :class="sold ? 'no' : 'yes'">
                <span class="dot"></span>{{ sold ? 'نفد المخزون' : 'متوفر الآن' }}
              </span>
              <span v-if="p.sold_count">&#183; مباع {{ num(p.sold_count) }}</span>
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

          <!-- زر التنسيق الذكي «نسّق لي» — نفس التطبيق -->
          <button class="bfit" @click="goOutfit">
            <span class="msm">auto_awesome</span> نسّق لي هذه القطعة ✨
          </button>

          <!-- معاينة الإطلالة المقترحة — نفس التطبيق -->
          <div v-if="outfit" class="outfit-preview" role="button" @click="goOutfit">
            <div class="op-head">
              <b>{{ outfit.outfit.title || 'إطلالة مقترحة' }}</b>
              <span v-if="Number(outfit.outfit.fit) > 0" class="op-fit">توافق {{ outfit.outfit.fit }}/100</span>
            </div>
            <div class="op-slots">
              <div v-for="(s, i) in outfit.outfit.slots" :key="i" class="op-slot">
                <img v-if="S(s.image) && !isRaw(s.image)" :src="S(s.image)" :alt="s.name" loading="lazy" />
                <span v-else class="emoji">{{ emojiOf(s) }}</span>
                <small class="num">{{ fmt(s.price) }}</small>
              </div>
            </div>
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

<style scoped>
/* زر «نسّق لي» — نفس تصميم التطبيق (تدرج كحلي → أزرق) */
.bfit {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px;
  border: none;
  border-radius: 16px;
  background: linear-gradient(135deg, #23273E 0%, #966487 100%);
  color: var(--white);
  font-size: var(--fs-base);
  font-weight: 900;
  cursor: pointer;
  box-shadow: 0 5px 14px rgba(35, 39, 62, .3);
  transition: transform var(--t-fast) var(--ease), box-shadow var(--t-fast) var(--ease);
}
.bfit .msm { font-size: 18px; }
.bfit:hover { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(212, 115, 118, .3); }
.bfit:active { transform: scale(.98); }

/* معاينة الإطلالة — نفس تنسيق التطبيق */
.outfit-preview {
  padding: 12px;
  background: #F7EFF0;
  border: 1px solid rgba(150, 100, 135, .3);
  border-radius: 16px;
  cursor: pointer;
  transition: transform var(--t-fast) var(--ease), box-shadow var(--t-fast) var(--ease);
}
.outfit-preview:hover { transform: var(--hover-raise); box-shadow: var(--sh-md); }
@media (hover: none) { .outfit-preview:hover { transform: none; box-shadow: none; } }
.op-head { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
.op-head b { font-size: 12.5px; color: var(--primary); font-weight: 900; }
.op-fit {
  padding: 3px 8px;
  border-radius: var(--r-pill);
  background: rgba(31, 157, 85, .12);
  color: var(--success-deep);
  font-size: 9.5px;
  font-weight: 900;
  white-space: nowrap;
}
.op-slots { display: flex; gap: 8px; overflow-x: auto; margin-block-start: 9px; padding-block-end: 2px; }
.op-slot { flex-shrink: 0; display: flex; flex-direction: column; align-items: center; gap: 3px; }
.op-slot img {
  width: 42px; height: 42px;
  border-radius: 10px;
  object-fit: cover;
  background: var(--img-ph);
}
.op-slot .emoji {
  width: 42px; height: 42px;
  border-radius: 10px;
  background: var(--img-ph);
  display: grid; place-items: center;
}
.op-slot small { font-size: 9px; color: var(--accent); font-weight: 900; }
</style>