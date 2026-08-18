<script setup>
/* ═══ الدردشة — محادثات (مع المندوب فقط أثناء التوصيل) + مسار محادثة ═══ */
import { ref, computed, onMounted } from 'vue';
import { useApp } from '../state';
import { api, fmtDate } from '../api';

const { state, toast } = useApp();

const conversations = ref([]);
const current = ref(null);
const messages = ref([]);
const msgText = ref('');
const loading = ref(true);
let poll = null;

const loadList = async () => {
  try {
    const d = await api('/api/customer/conversations');
    conversations.value = d.conversations || d || [];
  } catch (e) { conversations.value = []; }
};

const open = async (cv) => {
  current.value = cv;
  messages.value = [];
  try {
    const d = await api(`/api/customer/conversations/${cv.id}/messages`);
    messages.value = d.messages || [];
  } catch (e) { toast(e.message, false); current.value = null; }
};

const send = async () => {
  const t = msgText.value.trim();
  if (!t || !current.value) return;
  messages.value.push({ id: 'tmp' + Date.now(), message: t, from_me: true, created_at: new Date().toISOString() });
  msgText.value = '';
  try {
    await api(`/api/customer/conversations/${current.value.id}/messages`, { method: 'POST', body: JSON.stringify({ message: t }) });
  } catch (e) { toast(e.message, false); }
};

onMounted(async () => {
  await loadList();
  loading.value = false;
  poll = setInterval(async () => {
    if (current.value) {
      try {
        const d = await api(`/api/customer/conversations/${current.value.id}/messages`);
        messages.value = d.messages || [];
      } catch (_) {}
    }
    loadList();
  }, 6000);
});
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>الدردشة</h1><p class="sub">التواصل مع المندوب أثناء التوصيل فقط</p></div>

    <div v-if="loading" class="loader-block"><div class="loader"></div></div>
    <div v-else-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>
    <div v-else-if="!conversations.length && !current" class="empty">
      <span class="msm">forum</span>
      <h3>ماكو محادثات نشطة</h3>
      <p>تنفتح المحادثة تلقائياً لما يبدأ المندوب توصيل طلبك</p>
    </div>

    <div v-else class="chat-layout">
      <!-- القائمة -->
      <aside class="chat-list">
        <div v-for="cv in conversations" :key="cv.id" class="chat-item" :class="{ active: current?.id === cv.id }" @click="open(cv)">
          <div class="th"><span class="msm">person</span></div>
          <div class="in">
            <b>{{ cv.courier_name || 'المندوب' }}</b>
            <small>{{ cv.last_message || 'بدون رسائل بعد' }}</small>
          </div>
        </div>
      </aside>

      <!-- المحادثة -->
      <section class="msg-thread">
        <div v-if="current" class="pos-rel" style="display:flex;flex-direction:column;height:100%;min-height:0">
          <div class="msg-scroll">
            <div v-for="m in messages" :key="m.id" class="msg" :class="m.from_me ? 'me' : 'other'">
              {{ m.message }}
              <span class="t">{{ fmtDate(m.created_at) }}</span>
            </div>
            <div v-if="!messages.length" class="empty" style="padding:var(--sp-6)">
              <span class="msm">chat_bubble</span>
              <p>ابدأ المحادثة مع {{ current.courier_name || 'المندوب' }}</p>
            </div>
          </div>
          <form class="msg-input" @submit.prevent="send">
            <input v-model="msgText" class="input" placeholder="اكتب رسالة…" style="flex:1" />
            <button class="btn btn-primary btn-md" type="submit" :disabled="!msgText.trim()"><span class="msm">send</span></button>
          </form>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.chat-item.active { background: var(--bg-blue-soft); }
</style>