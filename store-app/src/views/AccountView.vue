<script setup>
/* ═══ حسابي — الملف + الروابط + تعديل الاسم ═══ */
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, S, isRaw } from '../api';

const { state, toast, loadMe, refreshCartCount } = useApp();
const router = useRouter();

const editOpen = ref(false);
const nameEdit = ref('');
const saving = ref(false);

const avatar = () => state.user && S(state.user.avatar);
const avatarEmoji = () => (!avatar() || isRaw(state.user?.avatar)) ? (state.user?.avatar?.slice(0, 1) || '👤') : '';
const roleLabel = { customer: 'زبون', vendor: 'تاجر', delivery: 'مندوب', admin: 'أدمن' };
const initial = () => (state.user?.name || '؟').slice(0, 1);

const saveName = async () => {
  if (nameEdit.value.trim().length < 3) { toast('الاسم قصير جداً', false); return; }
  saving.value = true;
  try {
    await api('/api/auth/profile', { method: 'PATCH', body: JSON.stringify({ name: nameEdit.value.trim() }) });
    await loadMe();
    editOpen.value = false;
    toast('تم تحديث الاسم ✓');
  } catch (e) { toast(e.message, false); }
  saving.value = false;
};
</script>

<template>
  <div class="container-narrow">
    <div class="page-head"><h1>حسابي</h1></div>

    <div v-if="!state.user" class="empty">
      <span class="msm">lock</span>
      <h3>سجّل دخول أولاً</h3>
      <button class="btn btn-primary btn-md" @click="state.loginOpen = true">دخول / إنشاء حساب</button>
    </div>

    <template v-else>
      <div class="flex-col gap-4" style="max-width:760px">
        <!-- الملف -->
        <section class="account-head">
          <div class="avatar">
            <img v-if="avatar() && !isRaw(state.user.avatar)" :src="avatar()" alt="" />
            <span v-else>{{ initial() }}</span>
          </div>
          <div class="in flex-1">
            <b>{{ state.user.name }}</b>
            <small class="num">{{ state.user.phone }} · {{ roleLabel[state.user.role] || state.user.role }}</small>
            <router-link v-if="state.user.referral_code" to="/points" class="badge" style="background:rgba(255,255,255,.15);color:var(--white);margin-block-start:var(--sp-2)">
              🎁 كود دعوتك: {{ state.user.referral_code }}
            </router-link>
          </div>
          <button class="btn btn-soft btn-sm mobile-hidden" @click="editOpen = !editOpen">تعديل</button>
        </section>

        <!-- تعديل الاسم -->
        <section v-if="editOpen" class="panel panel-pad flex gap-2">
          <input v-model="nameEdit" class="input" :placeholder="state.user.name" maxlength="60" style="flex:1" />
          <button class="btn btn-primary btn-md" :disabled="saving" @click="saveName">{{ saving ? '…' : 'حفظ' }}</button>
        </section>

        <!-- الروابط -->
        <div class="link-stack">
          <RouterLink class="link-row" to="/orders"><span class="r"><span class="msm">receipt_long</span> طلباتي</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink class="link-row" to="/fav"><span class="r"><span class="msm">favorite</span> المفضلة</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink class="link-row" to="/points"><span class="r"><span class="msm">stars</span> نقاطي</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink class="link-row" to="/notifications"><span class="r"><span class="msm">notifications</span> الإشعارات</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink class="link-row" to="/chat"><span class="r"><span class="msm">forum</span> الدردشة</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink v-if="state.user.role === 'vendor'" class="link-row" to="/vendor"><span class="r"><span class="msm">storefront</span> لوحة التاجر</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink v-if="state.user.role === 'delivery'" class="link-row" to="/delivery"><span class="r"><span class="msm">directions_bike</span> لوحة المندوب</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink v-if="state.user.role === 'admin'" class="link-row" :to="{ path: '/admin' }" target="_blank"><span class="r"><span class="msm">admin_panel_settings</span> لوحة الأدمن</span><span class="go msm">chevron_left</span></RouterLink>
          <RouterLink class="link-row" to="/logout"><span class="r" style="color:var(--danger)"><span class="msm">logout</span> تسجيل الخروج</span><span class="go msm">chevron_left</span></RouterLink>
        </div>
      </div>
    </template>
  </div>
</template>