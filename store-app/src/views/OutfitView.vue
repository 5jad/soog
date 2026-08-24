<script setup>
/* ═══ صفحة الإطلالة الكاملة — «نسّق لي ✨» مثل OutfitScreen بالتطبيق ═══
   فلاتر مناسبة/ميزانية + القطع مع بدائل قابلة للتبديل + تحليل الجودة +
   إضافة الكل للسلة (كل قطعة لمتجرها) */
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, fmt, isRaw, emojiOf } from '../api';
import EmptyState from '../components/EmptyState.vue';

const route = useRoute();
const router = useRouter();
const { state, toast, refreshCartCount } = useApp();

const data = ref(null);
const loading = ref(true);
const occasion = ref('casual');
const budget = ref(0);
const openAlt = ref(null);      /* الدور المفتوح حالياً للبدائل */

const occasions = [
  ['casual', 'كاجوال 😎'], ['work', 'دوام 💼'], ['formal', 'رسمية 🤵'], ['sport', 'رياضية ⚽'],
];
const budgets = [
  ['0', 'بدون حد'], ['100000', 'حتى 100 آلاف'], ['200000', 'حتى 200 ألف'], ['400000', 'حتى 400 ألف'],
];
const roleLabels = {
  top: 'القطعة العلوية', bottom: 'البنطلون', shoes: 'الحذاء', outerwear: 'جاكيت / بليزر',
  watch: 'ساعة', bag: 'حقيبة', fragrance: 'عطر', hat: 'إكسسوار رأس', accessory: 'إكسسوار', other: 'مكملات',
};

const outfit = computed(() => data.value?.outfit || {});
const slots = computed(() => outfit.value?.slots || []);
const fit = computed(() => Number(outfit.value?.fit) || 0);
const alternates = computed(() => outfit.value?.alternates || {});
const total = computed(() => slots.value.reduce((a, b) => a + Number(b.price || 0), 0));
const adding = ref(false);

const load = async () => {
  loading.value = true;
  openAlt.value = null;
  try {
    const d = await api(`/api/outfit/${route.params.id}?occasion=${occasion.value}&budget=${budget.value}`);
    data.value = d;
  } catch (_) { data.value = null; }
  loading.value = false;
};
onMounted(load);

const pickOccasion = (v) => { occasion.value = v; load(); };
const pickBudget = (v) => { budget.value = Number(v); load(); };

const imgOf = (s) => { const v = S(s.image); return (v && !isRaw(s.image)) ? v : ''; };

/* استبدال قطعة ببديلها + إعادة حساب الإجمالي محلياً */
const replaceSlot = (slot, alt) => {
  const idx = slots.value.findIndex((x) => x.id === slot.id);
  if (idx > -1) slots.value[idx] = alt;
  openAlt.value = null;
};

const addAllToCart = async () => {
  if (!state.user) {
    toast('سجّل دخولك أول حتى نضيف الإطلالة', false);
    state.loginOpen = true;
    return;
  }
  adding.value = true;
  let added = 0;
  for (const s of slots.value) {
    try {
      await api('/api/customer/cart', { method: 'POST', body: JSON.stringify({ product_id: s.id, qty: 1 }) });
      added++;
    } catch (_) {}
  }
  adding.value = false;
  if (added > 0) {
    refreshCartCount();
    toast(`أُضيفت الإطلالة للسلة — ${added} قطعة 🛒`);
    router.back();
  } else {
    toast('ما انضافت القطع — جرب مرة ثانية', false);
  }
};

/* لون مؤشر الجودة — نفس شرط التطبيق (≥80 أخضر / ≥60 كحلي / وإلا أحمر) */
const qColor = (v) => (Number(v) >= 80 ? 'var(--success)' : Number(v) >= 60 ? 'var(--primary)' : 'var(--danger)');
</script>

<template>
  <div class="container-narrow">
    <div v-if="loading" class="loader-block"><div class="loader"></div></div>

    <template v-else-if="data">
      <!-- الرأس + شارة التوافق -->
      <div class="page-head">
        <div class="of-head">
          <h1>نسّق لي ✨</h1>
          <span v-if="fit" class="of-fit">توافق {{ fit }}/100</span>
        </div>
      </div>

      <!-- فلاتر المناسبة والميزانية -->
      <div class="chips-row">
        <button v-for="[v, l] in occasions" :key="v" class="chip" :class="{ active: occasion === v }" @click="pickOccasion(v)">{{ l }}</button>
      </div>
      <div class="chips-row" style="margin-block-start:var(--sp-2)">
        <button v-for="[v, l] in budgets" :key="v" class="chip" :class="{ active: String(budget) === v }" @click="pickBudget(v)">{{ l }}</button>
      </div>

      <!-- البذرة ثم القطع مع البدائل -->
      <div class="of-body">
        <!-- القطعة الأساسية (البذرة) -->
        <div v-if="slots.length" class="slot-card seed">
          <img v-if="imgOf(slots[0])" :src="imgOf(slots[0])" :alt="slots[0].name" loading="lazy" />
          <span v-else class="pk-emoji">{{ emojiOf(slots[0]) }}</span>
          <div class="slot-in">
            <span class="role">{{ roleLabels[slots[0].role] || 'قطعة' }}</span>
            <b class="name ellipsis">{{ slots[0].name }}</b>
            <span class="store ellipsis">{{ slots[0].store_name }}</span>
            <span class="price num">{{ fmt(slots[0].price) }}</span>
          </div>
          <span v-if="slots[0].color" class="color-chip">{{ slots[0].color }}</span>
        </div>

        <!-- ملاحظة القطعة غير القابلة للتنسيق -->
        <div v-if="slots.length === 1" class="note-card">
          هذه القطعة من خارج الأزياء — التنسيق متاح للملابس والأحذية والإكسسوارات حالياً 🌱
        </div>

        <!-- القطع الأخرى + بدائل -->
        <template v-for="(s, i) in slots.slice(1)" :key="s.id">
          <div class="slot-card">
            <img v-if="imgOf(s)" :src="imgOf(s)" :alt="s.name" loading="lazy" />
            <span v-else class="pk-emoji">{{ emojiOf(s) }}</span>
            <div class="slot-in">
              <span class="role">{{ roleLabels[s.role] || 'قطعة' }}</span>
              <b class="name ellipsis">{{ s.name }}</b>
              <span class="store ellipsis">{{ s.store_name }}</span>
              <span class="price num">{{ fmt(s.price) }}</span>
            </div>
            <span v-if="s.color" class="color-chip">{{ s.color }}</span>
            <button v-if="(alternates[s.role] || []).length" class="swap-btn" :class="{ on: openAlt === s.role }" @click="openAlt = openAlt === s.role ? null : s.role">
              <span class="msm">swap_horiz</span> بدّل
            </button>
          </div>

          <!-- لوحة البدائل (منسدلة مثل شيت التطبيق) -->
          <div v-if="openAlt === s.role" class="alts">
            <div v-for="a in alternates[s.role]" :key="a.id" class="alt-item" role="button" @click="replaceSlot(s, a)">
              <img v-if="imgOf(a)" :src="imgOf(a)" :alt="a.name" loading="lazy" />
              <span v-else class="pk-emoji">{{ emojiOf(a) }}</span>
              <div class="alt-in">
                <b class="ellipsis">{{ a.name }}</b>
                <span class="store ellipsis">{{ a.store_name }}</span>
              </div>
              <span class="alt-price num">{{ fmt(a.price) }}</span>
            </div>
          </div>
        </template>

        <!-- تحليل الجودة -->
        <div v-if="data.quality != null && slots.length > 1" class="quality-card">
          <b>تحليل جودة القطعة الأساسية 🔍</b>
          <div class="q-row">
            <div class="q-item"><span :style="{ color: qColor(data.quality.quality) }">{{ Math.round(Number(data.quality.quality) || 0) }}/100</span><small>الجودة</small></div>
            <div class="q-item"><span :style="{ color: qColor(data.quality.value) }">{{ Math.round(Number(data.quality.value) || 0) }}/100</span><small>القيمة مقابل السعر</small></div>
            <div class="q-item"><span :style="{ color: qColor(fit) }">{{ fit }}/100</span><small>التوافق مع اختيارك</small></div>
          </div>
        </div>

        <p class="of-note">الإطلالة من متاجر مختلفة — تنضاف كل قطعة لمتجرها وتوصل بمجموعة وحدة 🛵</p>
      </div>

      <!-- الشريط السفلي: الإجمالي + زر الإضافة -->
      <div class="of-bar">
        <div class="of-total">
          <small>إجمالي الإطلالة</small>
          <strong class="num">{{ fmt(total) }}</strong>
        </div>
        <button class="btn btn-accent btn-lg flex-1" :disabled="adding" @click="addAllToCart">
          أضف الإطلالة للسلة 🛒
        </button>
      </div>
    </template>

    <EmptyState v-else icon="😕" title="تعذر تحميل الإطلالة" sub="جرب مرة ثانية أو اختر قطعة أخرى" action="رجوع" @act="router.back()" />
  </div>
</template>

<style scoped>
.of-head { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3); }
.of-head h1 { font-size: var(--fs-2xl); font-weight: 900; }
.of-fit {
  padding: 5px 11px;
  border-radius: var(--r-pill);
  background: linear-gradient(135deg, #0F9B58, #34D399);
  color: var(--white);
  font-size: 11.5px;
  font-weight: 900;
}
.chips-row { display: flex; gap: var(--sp-2); overflow-x: auto; scrollbar-width: none; padding-block: var(--sp-1); }
.chips-row::-webkit-scrollbar { display: none; }
.chips-row .chip { flex-shrink: 0; height: 42px; border-radius: 13px; font-size: 11.5px; }

.of-body { display: flex; flex-direction: column; gap: 12px; margin-block-start: var(--sp-4); }

.slot-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 18px;
  position: relative;
}
.slot-card.seed { border-color: rgba(139, 58, 98, .5); border-width: 1.5px; }
.slot-card > img { width: 64px; height: 64px; border-radius: 14px; object-fit: cover; background: var(--img-ph); flex-shrink: 0; }
.pk-emoji { width: 64px; height: 64px; border-radius: 14px; background: var(--img-ph); display: grid; place-items: center; font-size: var(--fs-2xl); flex-shrink: 0; }

.slot-in { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.slot-in .role { font-size: 10.5px; color: var(--primary); font-weight: 900; }
.slot-in .name { font-size: 13.5px; font-weight: 900; line-height: 1.3; }
.slot-in .store { font-size: 10.5px; color: var(--muted); font-weight: 700; }
.slot-in .price { font-size: 15px; color: var(--accent); font-weight: 900; margin-block-start: 3px; }

.color-chip {
  align-self: flex-start;
  margin-inline-start: 6px;
  padding: 2px 8px;
  border-radius: 8px;
  background: rgba(212, 91, 138, .1);
  color: var(--primary);
  font-size: 9.5px;
  font-weight: 800;
  white-space: nowrap;
}
.swap-btn {
  align-self: flex-start;
  margin-inline-start: auto;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: 11px;
  background: var(--bg);
  color: var(--primary);
  font-size: 10.5px;
  font-weight: 900;
  cursor: pointer;
  white-space: nowrap;
  transition: background var(--t-fast) var(--ease);
}
.swap-btn .msm { font-size: 15px; }
.swap-btn:hover, .swap-btn.on { background: var(--bg-blue-soft); }

.alts { display: flex; flex-direction: column; gap: 9px; padding-inline-start: 6px; }
.alt-item {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 15px;
  cursor: pointer;
  transition: transform var(--t-fast) var(--ease), border-color var(--t-fast) var(--ease);
}
.alt-item:hover { border-color: var(--primary-light); transform: translateY(-1px); }
.alt-item > img { width: 48px; height: 48px; border-radius: 12px; object-fit: cover; background: var(--img-ph); flex-shrink: 0; }
.alt-item .pk-emoji { width: 48px; height: 48px; font-size: var(--fs-xl); }
.alt-in { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.alt-in b { font-size: 12.5px; font-weight: 900; }
.alt-in .store { font-size: 10px; color: var(--muted); font-weight: 700; }
.alt-price { font-size: 13.5px; color: var(--accent); font-weight: 900; }

.note-card {
  padding: 16px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 18px;
  font-size: 13px;
  color: var(--muted);
  font-weight: 700;
}

.quality-card {
  padding: 14px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 18px;
}
.quality-card > b { font-size: 13px; font-weight: 900; }
.q-row { display: flex; margin-block-start: 10px; }
.q-item { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; }
.q-item span { font-size: 16px; font-weight: 900; }
.q-item small { font-size: 9.5px; color: var(--muted); font-weight: 800; text-align: center; }

.of-note { text-align: center; font-size: 10.5px; color: var(--muted); font-weight: 700; margin-block: 6px 0; }

.of-bar {
  position: sticky;
  inset-block-end: 0;
  z-index: var(--z-base);
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  margin-block-start: var(--sp-5);
  padding: 10px 0 12px;
  background: var(--surface);
  border-block-start: 1px solid var(--line);
}
.of-total { display: flex; flex-direction: column; align-items: flex-start; white-space: nowrap; }
.of-total small { font-size: 10px; color: var(--muted); font-weight: 700; }
.of-total strong { font-size: 18px; font-weight: 900; }
/* يرتفع فوق الشريط السفلي على الجوال */
@media (max-width: 1023.98px) { .of-bar { padding-block-end: calc(var(--bottomnav-h) + var(--sp-4)); } }
</style>