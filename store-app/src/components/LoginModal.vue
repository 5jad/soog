<script setup>
/* ═══ نافذة الدخول/التسجيل — موبايل: ورقة · ديسكتوب: مركزية ═══
   التسجيل: رقم → مشاركة تلغرام → رمز من البوت → الاسم + كلمة المرور */
import { ref, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, norm } from '../api';

const { state, toast, setToken, loadMe, refreshCartCount, closeAll } = useApp();
const router = useRouter();

const tab = ref('login');           /* login | register */
const phone = ref('');
const password = ref('');
const name = ref('');
const role = ref('customer');
const busy = ref(false);
const err = ref('');

/* خطوات التسجيل عبر تلغرام */
const regStep = ref(0);             /* 0=نموذج 1=شارك مع البوت 2=كود+اسم+باس */
const regToken = ref('');
const regBot = ref('');
const regCode = ref('');
const regPwd = ref('');
const regName = ref('');
const pollTimer = ref(null);

const close = () => { closeAll(); resetReg(); };

const resetReg = () => {
  regStep.value = 0; regToken.value = ''; regBot.value = ''; regCode.value = ''; regPwd.value = ''; regName.value = '';
  if (pollTimer.value) { clearInterval(pollTimer.value); pollTimer.value = null; }
  err.value = '';
};

const doLogin = async () => {
  err.value = '';
  if (!norm(phone.value) || !password.value) { err.value = 'أدخل الرقم وكلمة المرور'; return; }
  busy.value = true;
  try {
    const d = await api('/api/auth/login', { method: 'POST', body: JSON.stringify({ phone: norm(phone.value), password: password.value }) });
    setToken(d.token);
    await loadMe();
    refreshCartCount();
    toast(`أهلاً ${d.user.name || 'بك'} 👋`);
    close();
  } catch (e) { err.value = e.message; }
  busy.value = false;
};

const startReg = async () => {
  err.value = '';
  if (!/^0[0-9]{9,14}$/.test(norm(phone.value))) { err.value = 'رقم الهاتف غير صحيح — يبدأ بـ 0'; return; }
  busy.value = true;
  try {
    const d = await api('/api/auth/register-start', { method: 'POST', body: JSON.stringify({ phone: norm(phone.value), role: role.value }) });
    regToken.value = d.token; regBot.value = d.bot_username;
    regStep.value = 1;
    window.open(`https://t.me/${d.bot_username}?start=${d.token}`, '_blank');
    pollTimer.value = setInterval(pollReg, 2500);
  } catch (e) { err.value = e.message; }
  busy.value = false;
};

const pollReg = async () => {
  try {
    const d = await api(`/api/telegram/register-status?token=${regToken.value}`);
    if (d.status === 'verified') {
      if (pollTimer.value) { clearInterval(pollTimer.value); pollTimer.value = null; }
      regStep.value = 2;
      toast('تم التحقق من رقمك — أكمل البيانات');
    } else if (d.status === 'expired' || d.status === 'invalid') {
      if (pollTimer.value) { clearInterval(pollTimer.value); pollTimer.value = null; }
      regStep.value = 0;
      err.value = 'انتهت مهلة التحقق — أعد المحاولة';
    }
  } catch (_) { /* انقطاع — يكمل */ }
};

const confirmReg = async () => {
  err.value = '';
  if (!regCode.value) { err.value = 'أدخل الرمز من محادثة البوت'; return; }
  if (regName.value.trim().length < 3) { err.value = 'الاسم قصير جداً'; return; }
  if (regPwd.value.length < 6) { err.value = 'كلمة المرور 6 أحرف كحد أدنى'; return; }
  busy.value = true;
  try {
    await api('/api/auth/register-code', { method: 'POST', body: JSON.stringify({ token: regToken.value, code: regCode.value }) });
    const d = await api('/api/auth/register-confirm', { method: 'POST', body: JSON.stringify({ token: regToken.value, name: regName.value.trim(), password: regPwd.value }) });
    setToken(d.token);
    await loadMe();
    refreshCartCount();
    toast(`أهلاً ${d.user.name} — تم إنشاء حسابك 🎉`);
    close();
    if (role.value === 'vendor' && d.user) router.push('/vendor');
  } catch (e) { err.value = e.message; }
  busy.value = false;
};

const switchTab = (t) => { tab.value = t; err.value = ''; };
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="state.loginOpen" class="modal-mask" @click.self="close">
        <div class="modal-panel">
          <div class="modal-head">
            <h3>{{ tab === 'login' ? 'تسجيل الدخول' : 'حساب جديد' }}</h3>
            <button class="modal-close" aria-label="إغلاق" @click="close"><span class="msm">close</span></button>
          </div>
          <div class="modal-body">
            <!-- التبويبات -->
            <div class="tabs" style="border-block-end:none">
              <button class="tab" :class="{ active: tab === 'login' }" @click="switchTab('login')">دخول</button>
              <button class="tab" :class="{ active: tab === 'register' }" @click="switchTab('register')">إنشاء حساب</button>
            </div>

            <!-- ═══ دخول ═══ -->
            <form v-if="tab === 'login'" class="flex-col gap-4" @submit.prevent="doLogin">
              <div class="field">
                <label>رقم الهاتف</label>
                <input v-model="phone" class="input" inputmode="tel" placeholder="07XXXXXXXXX" maxlength="15" />
              </div>
              <div class="field">
                <label>كلمة المرور</label>
                <input v-model="password" class="input" type="password" placeholder="••••••••" />
              </div>
              <p v-if="err" class="err text-danger" style="font-weight:700;font-size:var(--fs-sm)">{{ err }}</p>
              <button class="btn btn-primary btn-lg btn-block" type="submit" :disabled="busy">
                {{ busy ? '…' : 'دخول' }}
              </button>
              <p class="text-xs text-muted" style="text-align:center">
                مو مشترك؟ اضغط «إنشاء حساب» وخلّي الرقم يوصل للبوت — سريع وبدون كلمة سر مرحلة
              </p>
            </form>

            <!-- ═══ تسجيل ═══ -->
            <form v-else class="flex-col gap-4" @submit.prevent="regStep === 0 ? startReg() : confirmReg()">
              <template v-if="regStep === 0">
                <div class="field">
                  <label>نوع الحساب</label>
                  <div class="flex gap-2" style="flex-wrap:wrap">
                    <button type="button" class="chip" :class="{ active: role === 'customer' }" @click="role = 'customer'">👤 زبون</button>
                    <button type="button" class="chip" :class="{ active: role === 'vendor' }" @click="role = 'vendor'">🏪 تاجر</button>
                  </div>
                </div>
                <div class="field">
                  <label>رقم الهاتف</label>
                  <input v-model="phone" class="input" inputmode="tel" placeholder="07XXXXXXXXX" maxlength="15" />
                  <span class="hint">أرسلنا رمز تحقق برسالة تلغرام — تأكد إن رقمك مربوط بالبوت أول مرة</span>
                </div>
                <p v-if="err" class="err text-danger" style="font-weight:700;font-size:var(--fs-sm)">{{ err }}</p>
                <button class="btn btn-primary btn-lg btn-block" type="submit" :disabled="busy">{{ busy ? '…' : 'بدء التحقق' }}</button>
              </template>

              <template v-else-if="regStep === 1">
                <div class="empty">
                  <span class="msm" style="color:var(--info)">telegram</span>
                  <h3>افتح تلغرام وشارك رقمك</h3>
                  <p>ضغطنا فتحنا البوت لك — اضغط Start وارسل رقمك حتى يتحقق منه</p>
                  <a class="btn btn-soft btn-md" :href="`https://t.me/${regBot}?start=${regToken}`" target="_blank">
                    <span class="msm">send</span> افتح البوت مرة ثانية
                  </a>
                  <div class="flex gap-2">
                    <div class="loader"></div>
                    <span class="text-sm text-muted">بانتظار التحقق…</span>
                  </div>
                  <button type="button" class="btn btn-ghost btn-sm" @click="resetReg; regStep = 0">إلغاء والعودة</button>
                </div>
              </template>

              <template v-else>
                <p class="text-sm" style="background:var(--bg-blue-soft);padding:var(--sp-3);border-radius:var(--r-md)">
                  ✅ تحقّق الرقم. الرومة كتبه البوت لك بمحادثة تلغرام — انسخه هنا وكمّل بياناتك
                </p>
                <div class="field">
                  <label>الرمز من تلغرام</label>
                  <input v-model="regCode" class="input" placeholder="الرمز من محادثة البوت" inputmode="numeric" />
                </div>
                <div class="field">
                  <label>الاسم</label>
                  <input v-model="regName" class="input" placeholder="اسمك الكامل" maxlength="60" />
                </div>
                <div class="field">
                  <label>كلمة المرور</label>
                  <input v-model="regPwd" class="input" type="password" placeholder="6 أحرف كحد أدنى" />
                </div>
                <p v-if="err" class="err text-danger" style="font-weight:700;font-size:var(--fs-sm)">{{ err }}</p>
                <button class="btn btn-accent btn-lg btn-block" type="submit" :disabled="busy">{{ busy ? '…' : 'إنشاء الحساب' }}</button>
              </template>
            </form>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>