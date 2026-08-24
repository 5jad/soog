<script setup>
/* ═══ السلة الكاملة — نفس منطق دراور السلة بعرض أكبر + توصيل وتجميع حسب المتجر ═══ */
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, isRaw, emojiOf } from '../api';
import EmptyState from '../components/EmptyState.vue';
import StateLoader from '../components/StateLoader.vue';

const { state, toast, refreshCartCount } = useApp();
const router = useRouter();

const items = ref([]);
const loading = ref(true);

const load = async () => {
  if (!state.user) { loading.value = false; return; }
  try {
    const d = await api('/api/customer/cart');
    items.value = d.items || [];
  } catch (_) { items.value = []; }
  loading.value = false;
};
onMounted(load);

/* تجميع حسب المتجر */
const groups = computed(() => {
  const m = new Map();
  for (const it of items.value) {
    if (!m.has(it.store_id)) m.set(it.store_id, []);
    m.get(it.store_id).push(it);
  }
  return [...m.entries()];
});

const subtotal = computed(() => items.value.reduce((a, b) => a + priceOf(b) * Number(b.qty), 0));
const count = computed(() => items.value.reduce((a, b) => a + Number(b.qty), 0));

const setQty = async (it, delta) => {
  const nq = Number(it.qty) + delta;
  if (nq < 1) return remove(it);
  if (nq > 99) return;
  it.qty = nq;
  try {
    await api(`/api/customer/cart/${it.id}`, { method: 'PATCH', body: JSON.stringify({ qty: nq }) });
    refreshCartCount();
  } catch (e) { toast(e.message, false); it.qty -= delta; }
};

const remove = async (it) => {
  items.value = items.value.filter((x) => x.id !== it.id);
  try { await api(`/api/customer/cart/${it.id}`, { method: 'DELETE' }); refreshCartCount(); }
  catch (e) { toast(e.message, false); load(); }
};

const imgOf = (it) => S(it.image);
const emojiIt = (it) => (!imgOf(it) || isRaw(it.image)) ? emojiOf(it) : '';
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>سلة التسوق</h1><p class="sub">راجع طلباتك قبل إتمام الطلب</p></div>

    <div v-if="loading" class="loader-block"><StateLoader /></div>

    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <EmptyState v-else-if="!items.length" icon="🛍️" title="سلتك فاضية" sub="زر المتاجر واختار ما يعجبك — التوصيل يستغرق 30–60 دقيقة" action="تسوق الآن" @act="router.push('/stores')" />

    <div v-else class="cart-layout">
      <!-- العناصر مجمعة بالمحلات -->
      <div class="flex-col gap-5">
        <div v-for="[sid, group] in groups" :key="sid" class="panel panel-pad">
          <div class="flex between gap-2" style="margin-block-end:var(--sp-2);border-block-end:1px solid var(--line);padding-block-end:var(--sp-3)">
            <RouterLink :to="`/stores/${sid}`" class="flex gap-2" style="font-weight:800;color:var(--primary)">
              <img v-if="S(group[0].logo) && !isRaw(group[0].logo)" :src="S(group[0].logo)" style="width:22px;height:22px;border-radius:50%;object-fit:cover" alt="" />
              {{ group[0].store_name }}
            </RouterLink>
            <span class="text-xs text-muted">🚚 {{ fmt(group[0].delivery_fee) }}</span>
          </div>
          <div v-for="it in group" :key="it.id" class="line-item">
            <div class="th">
              <img v-if="imgOf(it) && !isRaw(it.image)" :src="imgOf(it)" alt="" />
              <span v-else class="emoji">{{ emojiIt(it) }}</span>
            </div>
            <div class="meta">
              <RouterLink :to="`/product/${it.product_id}`" class="name clamp-2">{{ it.name }}</RouterLink>
              <span v-if="it.variant" class="variant">{{ it.variant }}</span>
              <div class="prow">
                <span class="price num">{{ fmt(priceOf(it) * it.qty) }}</span>
                <div class="flex gap-2">
                  <div class="qty">
                    <button aria-label="ناقص" @click="setQty(it, -1)">−</button>
                    <span class="num">{{ it.qty }}</span>
                    <button aria-label="زائد" :disabled="it.stock === 0" @click="setQty(it, 1)">+</button>
                  </div>
                  <button class="x" aria-label="حذف" @click="remove(it)"><span class="msm">delete</span></button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- الملخص -->
      <aside class="panel panel-pad" style="position:sticky;inset-block-start:calc(var(--header-h) + var(--sp-5))">
        <h2 class="h3" style="margin-block-end:var(--sp-3)">ملخص الطلب</h2>
        <div class="sum-row"><span>المنتجات ({{ count }})</span><span class="num">{{ fmt(subtotal) }}</span></div>
        <div class="sum-row"><span>التوصيل</span><span class="num">يُحسب في إتمام الطلب</span></div>
        <div class="sum-row"><span>الدفع</span><strong>كاش عند الاستلام</strong></div>
        <div class="sum-total"><span>الإجمالي</span><span class="num">{{ fmt(subtotal) }}</span></div>
        <button class="btn btn-accent btn-lg btn-block" style="margin-block-start:var(--sp-4)" @click="router.push('/checkout')">
          إتمام الطلب <span class="msm">arrow_back</span>
        </button>
      </aside>
    </div>
  </div>
</template>