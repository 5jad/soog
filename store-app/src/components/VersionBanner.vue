<script setup>
/* ═══ شريط النسخة الجديدة — مثل UpdateBanner بالتطبيق:
   يجيب آخر نسخة من /api/app/version ويعرض الشريط مرة واحدة لكل نسخة (إغلاق = خزن) */
import { ref, onMounted } from 'vue';
import { api } from '../api';

const SEEN_KEY = 'web_last_seen_v';
const latest = ref('');
const show = ref(false);

onMounted(async () => {
  try {
    const d = await api('/api/app/version');
    const v = (d.version || '').toString();
    if (!v) return;
    const seen = localStorage.getItem(SEEN_KEY);
    if (seen === v) return;
    latest.value = v;
    show.value = true;
  } catch (_) {}
});

const dismiss = () => {
  localStorage.setItem(SEEN_KEY, latest.value);
  show.value = false;
};
</script>

<template>
  <Transition name="slide-dn">
    <div v-if="show" class="version-banner">
      <span style="font-size:20px">📦</span>
      <div class="vb-txt">
        <b>نسخة جديدة متوفرة ({{ latest }})</b>
        <small>حمّلها من موقعنا — أحدث إصدار دائماً</small>
      </div>
      <a class="vb-btn" href="/download" target="_blank" rel="noopener">حمّل</a>
      <button class="vb-x" aria-label="إغلاق" @click="dismiss"><span class="msm">close</span></button>
    </div>
  </Transition>
</template>

<style scoped>
.version-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 8px 16px 0;
  padding: 12px 14px;
  border-radius: 16px;
  background: linear-gradient(135deg, #23273E, #3A3153);
  color: var(--white);
  box-shadow: 0 5px 14px rgba(212, 115, 118, 0.35);
}
.vb-txt { flex: 1; min-width: 0; }
.vb-txt b { display: block; font-size: 13px; }
.vb-txt small { display: block; font-size: 10.5px; opacity: 0.9; }
.vb-btn {
  background: var(--white);
  color: var(--primary-deep);
  font-weight: 900;
  font-size: 12.5px;
  padding: 8px 14px;
  border-radius: 12px;
  text-decoration: none;
  white-space: nowrap;
}
.vb-x {
  background: none;
  border: none;
  color: var(--white);
  opacity: 0.7;
  cursor: pointer;
  display: grid;
  place-items: center;
  padding: 4px;
}
.slide-dn-enter-active, .slide-dn-leave-active { transition: all var(--t-slow) var(--ease-spring); }
.slide-dn-enter-from, .slide-dn-leave-to { opacity: 0; transform: translateY(-14px); }
</style>