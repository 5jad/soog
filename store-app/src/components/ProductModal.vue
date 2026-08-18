<script setup>
/* ═══ معاينة سريعة لمنتج — بوتون معاينة كبير · الجوال: صفحة المنتج مباشرة ═══ */
import { ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, pct, emojiOf, isRaw } from '../api';

const props = defineProps({ productId: { type: Number, default: null } });
const emit = defineEmits(['close']);
const { state, toast } = useApp();
const router = useRouter();

const p = ref(null);
const open = ref(false);
const busy = ref(false);

watch(() => props.productId, async (id) => {
  if (!id) { open.value = false; return; }
  try {
    const d = await api(`/api/products/${id}`);
    p.value = d.product;
    open.value = true;
  } catch (e) { toast(e.message, false); emit('close'); }
});

const off = () => pct(p.value);
const img = () => S(p.value?.image);

const add = async () => {
  if (!state.user) { toast('سجّل دخول أولاً'); state.loginOpen = true; return; }
  busy.value = true;
  try {
    const d = await api('/api/customer/cart', { method: 'POST', body: JSON.stringify({ product_id: p.value.id, qty: 1 }) });
    if (d.count !== undefined) state.cartCount = d.count;
    toast('أُضيف للسلة');
  } catch (e) { toast(e.message, false); }
  busy.value = false;
};

const goFull = () => { open.value = false; emit('close'); router.push(`/product/${p.value.id}`); };
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="open && p" class="modal-mask" @click.self="open = false; emit('close')">
        <div class="modal-panel">
          <div class="modal-head">
            <h3>معاينة سريعة</h3>
            <button class="modal-close" aria-label="إغلاق" @click="open = false; emit('close')"><span class="msm">close</span></button>
          </div>
          <div class="modal-body">
            <div class="qv-wrap">
              <div class="qv-img">
                <img v-if="img() && !isRaw(p.image)" :src="img()" alt="" />
                <span v-else class="emoji">{{ emojiOf(p) }}</span>
                <span v-if="off() > 0" class="badge badge-disc" style="position:absolute;inset-block-start:var(--sp-2);inset-inline-start:var(--sp-2)">خصم {{ off() }}%</span>
              </div>
              <div class="qv-body">
                <h3 class="prod-title" style="font-size:var(--fs-xl)">{{ p.name }}</h3>
                <p class="text-sm text-muted" style="margin-block:var(--sp-1)">{{ p.store_name }}</p>
                <div class="price-line" style="margin-block:var(--sp-2)">
                  <span class="now num">{{ fmt(priceOf(p)) }}</span>
                  <span v-if="off() > 0" class="old num">{{ fmt(p.price) }}</span>
                </div>
                <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="add">أضف للسلة</button>
                <button class="btn btn-ghost btn-block btn-md" style="margin-block-start:var(--sp-2)" @click="goFull">عرض الصفحة الكاملة</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.qv-wrap { display: grid; gap: var(--sp-4); }
@media (min-width: 768px) { .qv-wrap { grid-template-columns: 1fr 1fr; align-items: center; } }
.qv-img { position: relative; aspect-ratio: 4/3; border-radius: var(--r-lg); background: var(--img-ph); overflow: hidden; }
.qv-img img { width: 100%; height: 100%; object-fit: cover; }
.qv-img .emoji { position: absolute; inset: 0; display: grid; place-items: center; font-size: 80px; }
</style>