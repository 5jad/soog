<script setup>
/* ═══ نقاطي — الرصيد + سجل النقاط + دعوة الأصدقاء ═══ */
import { ref, onMounted } from 'vue';
import { useApp } from '../state';
import { api, fmt, timeAgo, copy } from '../api';
import EmptyState from '../components/EmptyState.vue';

const { state, toast } = useApp();

const balance = ref(0);
const transactions = ref([]);
const referral = ref(null);

onMounted(async () => {
  if (!state.user) return;
  try {
    const [pt, rf] = await Promise.all([api('/api/customer/points'), api('/api/customer/referral')]);
    balance.value = pt.balance || 0;
    transactions.value = pt.transactions || [];
    referral.value = rf;
  } catch (_) {}
});

const copyCode = async () => {
  if (!referral.value) return;
  await copy(referral.value.code);
  toast('نُسخ كود الدعوة — شاركه مع أصدقائك');
};
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>نقاطي</h1><p class="sub">اجمع النقاط مع كل طلب وبدّلها خصم</p></div>

    <div v-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <div v-else class="flex-col gap-4" style="max-width:760px">
      <div class="points-hero">
        <div>
          <div class="flex gap-2" style="align-items:center">
            <span class="ball"><span class="msm" style="font-size:32px">stars</span></span>
            <div>
              <div style="font-size:var(--fs-2xl);font-weight:800" class="num">{{ Number(balance).toLocaleString('ar-IQ') }}</div>
              <div style="opacity:.8;font-size:var(--fs-xs)">نقطة متاحة — كل 100 نقطة = 1,000 د.ع خصم بالدفع</div>
            </div>
          </div>
        </div>
        <RouterLink class="btn btn-accent btn-md" to="/prods">استبدلها الآن</RouterLink>
      </div>

      <!-- دعوة -->
      <section v-if="referral" class="panel panel-pad flex between gap-3" style="flex-wrap:wrap">
        <div>
          <h2 class="h3">🤝 ادعي أصدقائك</h2>
          <p class="text-sm text-muted" style="margin-block-start:var(--sp-1)">
            كل صديق يسجل بكودك ياخذ 50 نقطة وأنت 100 — الكل يربح
          </p>
        </div>
        <button class="btn btn-soft btn-md" @click="copyCode">
          <span class="msm">content_copy</span> {{ referral.code }}
        </button>
      </section>

      <!-- السجل -->
      <section class="panel panel-pad">
        <h2 class="h3" style="margin-block-end:var(--sp-3)">سجل النقاط</h2>
        <EmptyState v-if="!transactions.length" icon="🌟" title="سجل النقاط فاضي" sub="أول طلب يعني أول نقاط — سجل دخول وتسوق" />
        <div v-else class="flex-col gap-2">
          <div v-for="tr in transactions" :key="tr.id" class="info-row">
            <span class="k"><span class="msm">{{ tr.points > 0 ? 'add_circle' : 'remove_circle' }}</span> {{ tr.note || 'نقاط' }} <small style="color:var(--line-strong)">· {{ timeAgo(tr.created_at) }}</small></span>
            <span class="v num" :style="tr.points > 0 ? 'color:var(--success)' : 'color:var(--danger)'">
              {{ tr.points > 0 ? '+' : '' }}{{ Number(tr.points).toLocaleString('ar-IQ') }}
            </span>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>