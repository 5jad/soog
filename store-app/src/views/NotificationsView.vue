<script setup>
/* ═══ الإشعارات — قائمة + كل مقروءة + حذف ═══ */
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, timeAgo } from '../api';

const { state, toast } = useApp();
const router = useRouter();

const notifications = ref([]);

const load = async () => {
  if (!state.user) return;
  try {
    const d = await api('/api/customer/notifications');
    notifications.value = d.notifications || [];
  } catch (_) {}
};
onMounted(load);

const readAll = async () => {
  try { await api('/api/customer/notifications/read', { method: 'POST' }); notifications.value.forEach((n) => (n.read = true)); }
  catch (_) {}
};
const remove = async (n) => {
  notifications.value = notifications.value.filter((x) => x.id !== n.id);
  try { await api(`/api/customer/notifications/${n.id}`, { method: 'DELETE' }); } catch (_) {}
};
const open = (n) => {
  const d = n.data || {};
  if (d.order_id) router.push(`/orders/${d.order_id}`);
};
const ic = (t) => t === 'order' ? 'ic-info' : t === 'points' ? 'ic-gold' : t === 'refund' ? 'ic-warn' : 'ic-info';
const icn = (t) => t === 'order' ? 'receipt_long' : t === 'points' ? 'stars' : t === 'refund' ? 'swap_horiz' : 'notifications';
</script>

<template>
  <div class="container-narrow">
    <div class="page-head flex between gap-3" style="align-items:center">
      <div><h1>الإشعارات</h1><p class="sub">تحديثات طلباتك ونقاطك</p></div>
      <button class="btn btn-ghost btn-sm" @click="readAll">قراءة الكل</button>
    </div>

    <div v-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>
    <div v-else-if="!notifications.length" class="empty">
      <span class="msm">notifications_off</span>
      <h3>ماكو إشعارات</h3>
      <p>ولّي إشعارات الطلبات والنقاط كلها تجي هنا</p>
    </div>
    <div v-else class="flex-col gap-3" style="max-width:760px">
      <div v-for="n in notifications" :key="n.id" class="row-item" :class="{ unread: !n.read }" @click="open(n)">
        <div class="ic" :class="ic(n.type)"><span class="msm">{{ icn(n.type) }}</span></div>
        <div class="in">
          <b>{{ n.title }}</b>
          <p>{{ n.body }}</p>
          <span class="ago">{{ timeAgo(n.created_at) }}</span>
        </div>
        <button class="x" aria-label="حذف" @click.stop="remove(n)"><span class="msm" style="font-size:18px">close</span></button>
      </div>
    </div>
  </div>
</template>