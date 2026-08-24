<script setup>
/* ═══ دراور السلة — موبايل: ورقة تصعد من تحت · ديسكتوب: من الجانب ═══ */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, priceOf, isRaw, emojiOf } from '../api';
import { bindDismissDrag } from '../composables/useGestures';
import EmptyState from './EmptyState.vue';
import StateLoader from './StateLoader.vue';

const { state, toast, refreshCartCount } = useApp();
const router = useRouter();

const items = ref([]);
const loading = ref(false);

const load = async () => {
  if (!state.user) return;
  loading.value = true;
  try {
    const d = await api('/api/customer/cart');
    items.value = d.items || [];
  } catch (_) { items.value = []; }
  loading.value = false;
};

onMounted(load);

const subtotal = computed(() => items.value.reduce((a, b) => a + priceOf(b) * Number(b.qty), 0));
const count = computed(() => items.value.reduce((a, b) => a + Number(b.qty), 0));

const imgOf = (it) => S(it.image);
const emojiOfItem = (it) => (!imgOf(it) || isRaw(it.image)) ? emojiOf(it) : '';
const sold = (it) => it.stock === 0;

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
  try {
    await api(`/api/customer/cart/${it.id}`, { method: 'DELETE' });
    refreshCartCount();
    toast('حُذف من السلة');
  } catch (e) { toast(e.message, false); load(); }
};

const close = () => { state.cartDrawer = false; };
const checkout = () => { close(); router.push('/checkout'); };

/* سحب للأسفل على اللوحة يقفل الدروار (مثل الموبايل) */
const panelEl = ref(null);
onMounted(() => {
  const stop = bindDismissDrag(panelEl.value, { onClose: close });
  onBeforeUnmount(() => stop?.());
});
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="state.cartDrawer" class="drawer-mask" @click.self="close">
        <div class="scrim"></div>
        <aside ref="panelEl" class="drawer-panel">
          <div class="grab-handle" aria-hidden="true"></div>
          <div class="drawer-head">
            <h3>سلة التسوق <small class="num" style="color:var(--muted)">({{ count }})</small></h3>
            <button class="modal-close" aria-label="إغلاق" @click="close"><span class="msm">close</span></button>
          </div>

          <div class="drawer-body">
            <div v-if="loading" class="loader-block" style="padding:var(--sp-6)"><StateLoader :width="54" :height="54" /></div>
            <EmptyState v-else-if="!items.length" icon="🛍️" title="سلتك فاضية" sub="زر المتاجر واختار ما يعجبك — التوصيل يستغرق 30–60 دقيقة" action="تسوق الآن" @act="close; router.push('/stores')" />
            <template v-else>
              <div v-for="it in items" :key="it.id" class="line-item">
                <div class="th">
                  <img v-if="imgOf(it) && !isRaw(it.image)" :src="imgOf(it)" alt="" />
                  <span v-else class="emoji">{{ emojiOfItem(it) }}</span>
                </div>
                <div class="meta">
                  <span class="name clamp-2">{{ it.name }}</span>
                  <span v-if="it.variant" class="variant">{{ it.variant }}</span>
                  <span class="variant" style="font-weight:600;color:var(--primary-light)">{{ it.store_name }}</span>
                  <div class="prow">
                    <span class="price num">{{ fmt(priceOf(it) * it.qty) }}</span>
                    <div class="flex gap-2">
                      <div class="qty">
                        <button aria-label="ناقص" @click="setQty(it, -1)">−</button>
                        <span class="num">{{ it.qty }}</span>
                        <button aria-label="زائد" :disabled="sold(it)" @click="setQty(it, 1)">+</button>
                      </div>
                      <button class="x" aria-label="حذف" @click="remove(it)"><span class="msm">delete</span></button>
                    </div>
                  </div>
                </div>
              </div>
            </template>
          </div>

          <div v-if="items.length" class="drawer-foot">
            <div class="sum-row"><span>المجموع</span><strong class="num">{{ fmt(subtotal) }}</strong></div>
            <p class="text-xs text-muted" style="margin-block:4px">سعر التوصيل يُحسب في إتمام الطلب حسب موقعك</p>
            <button class="btn btn-accent btn-lg btn-block" @click="checkout">إتمام الطلب</button>
          </div>
        </aside>
      </div>
    </Transition>
  </Teleport>
</template>

<style>
.fade-enter-active, .fade-leave-active { transition: opacity var(--t-base) var(--ease); }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>