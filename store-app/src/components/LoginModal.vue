<script setup>
/* ═══ نافذة الدخول/التسجيل — موبايل: ورقة · ديسكتوب: مركزية ═══
   التسجيل نموذج واحد بكل التفاصيل ظاهرة: الأدوار + الرقم + الاسم + الباس
   + شريط تحقق تلغرام + الرمز — بدل الخطوات المخفية */
import { ref, onMounted, onUnmounted } from 'vue';
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

/* تفاصيل التاجر — تظهر عند اختيار 🏪 تاجر */
const storeName = ref('');
const storeCat = ref('');
const storeDesc = ref('');
const storeAddr = ref('');
const storeDist = ref('');
const cats = ref([]);
const districts = ref([]);

/* كود الدعوة — للزبون فقط */
const referral = ref('');

/* تحقق التسجيل عبر تلغرام */
const regStarted = ref(false);      /* دزّينا register-start وفتحنا البوت */
const regVerified = ref(false);     /* البوت أكد الرقم */
const regToken = ref('');
const regBot = ref('');
const regCode = ref('');
const pollTimer = ref(null);

const close = () => { closeAll(); resetReg(); };

const resetReg = () => {
  regStarted.value = false; regVerified.value = false; regToken.value = ''; regBot.value = ''; regCode.value = '';
  referral.value = ''; storeName.value = ''; storeCat.value = ''; storeDesc.value = ''; storeAddr.value = ''; storeDist.value = '';
  if (pollTimer.value) { clearInterval(pollTimer.value); pollTimer.value = null; }
  err.value = '';
};

onUnmounted(() => { if (pollTimer.value) clearInterval(pollTimer.value); });

/* قوائم الأقسام والنواحي — تجلب مرة وحدة لملء نموذج التاجر */
onMounted(async () => {
  try {
    const c = await api('/api/categories');
    cats.value = c.categories || [];
    const g = await api('/api/governorates');
    const govs = g.governorates || [];
    districts.value = govs.flatMap((x) => (x.districts || []).map((d) => d));
  } catch (_) {}
});

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
    regStarted.value = true;
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
      regVerified.value = true;
      toast('تم التحقق من رقمك — أكمل البيانات');
      err.value = '';
    } else if (d.status === 'expired' || d.status === 'invalid') {
      if (pollTimer.value) { clearInterval(pollTimer.value); pollTimer.value = null; }
      regStarted.value = false;
      err.value = 'انتهت مهلة التحقق — ابدأ من جديد';
    }
  } catch (_) { /* انقطاع — يكمل */ }
};

const confirmReg = async () => {
  err.value = '';
  if (!regVerified.value) { err.value = 'انتظر حتى يتحقق رقمك عبر تلغرام'; return; }
  if (!regCode.value) { err.value = 'أدخل الرمز من محادثة البوت'; return; }
  if (name.value.trim().length < 3) { err.value = 'الاسم قصير جداً'; return; }
  if (password.value.length < 6) { err.value = 'كلمة المرور 6 أحرف كحد أدنى'; return; }
  if (role.value === 'vendor') {
    if (storeName.value.trim().length < 3) { err.value = 'أدخل اسم متجرك'; return; }
    if (!storeCat.value) { err.value = 'اختر قسم المتجر'; return; }
  }
  busy.value = true;
  try {
    await api('/api/auth/register-code', { method: 'POST', body: JSON.stringify({ token: regToken.value, code: regCode.value }) });
    const d = await api('/api/auth/register-confirm', { method: 'POST', body: JSON.stringify({
      token: regToken.value, name: name.value.trim(), password: password.value,
      ...(role.value === 'customer' ? { referral: referral.value.trim() } : {}),
    }) });
    setToken(d.token);
    await loadMe();
    refreshCartCount();
    if (role.value === 'vendor' && d.user) {
      try {
        await api('/api/vendor/store', { method: 'POST', body: JSON.stringify({
          name: storeName.value.trim(),
          category_id: Number(storeCat.value),
          description: storeDesc.value.trim(),
          address: storeAddr.value.trim(),
          ...(storeDist.value ? { district_id: Number(storeDist.value) } : {}),
          phone: norm(phone.value),
        }) });
        toast('انطلق متجرك — بانتظار توثيق الأدمن ⏳');
      } catch (e) {
        toast('أُنشئ حسابك — بس المتجر ما انفتح: ' + e.message, true);
      }
    } else {
      toast(`أهلاً ${d.user.name} — تم إنشاء حسابك 🎉`);
    }
    close();
    if (role.value === 'vendor' && d.user) router.push('/vendor');
  } catch (e) { err.value = e.message; }
  busy.value = false;
};

/* زر التسجيل الوحيد: قبل التحقق يبدأ، بعده ينشئ الحساب */
const submitReg = () => (regStarted.value ? confirmReg() : startReg());

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

            <!-- ═══ تسجيل — نموذج واحد بكل التفاصيل ظاهرة ═══ -->
            <form v-else class="flex-col gap-4" @submit.prevent="submitReg">
              <div class="field">
                <label>نوع الحساب</label>
                <div class="flex gap-2" style="flex-wrap:wrap">
                  <button type="button" class="chip" :class="{ active: role === 'customer' }" @click="role = 'customer'">👤 زبون</button>
                  <button type="button" class="chip" :class="{ active: role === 'vendor' }" @click="role = 'vendor'">🏪 تاجر</button>
                </div>
              </div>
              <div class="field">
                <label>رقم الهاتف</label>
                <input v-model="phone" class="input" inputmode="tel" placeholder="07XXXXXXXXX" maxlength="15" :disabled="regStarted" />
                <span class="hint">تأكد إن رقمك مربوط بالبوت أول مرة</span>
              </div>
              <div class="field">
                <label>الاسم</label>
                <input v-model="name" class="input" placeholder="اسمك الكامل" maxlength="60" />
              </div>
              <div class="field">
                <label>كلمة المرور</label>
                <input v-model="password" class="input" type="password" placeholder="6 أحرف كحد أدنى" />
              </div>

              <!-- بيانات المتجر — تظهر عند اختيار تاجر -->
              <div v-if="role === 'vendor'" class="panel panel-pad flex-col gap-3" style="background:var(--bg-blue-soft);border-radius:var(--r-md)">
                <b class="text-sm">بيانات متجرك 🏪</b>
                <div class="field"><label>اسم المحل *</label><input v-model="storeName" class="input" maxlength="60" placeholder="مثل: أزياء الكوت" /></div>
                <div class="field"><label>قسم المتجر *</label><select v-model="storeCat" class="select"><option value="">اختر…</option><option v-for="c in cats" :key="c.id" :value="c.id">{{ c.name }}</option></select></div>
                <div class="field"><label>الوصف</label><textarea v-model="storeDesc" class="textarea" rows="2" placeholder="شنو يقدم متجرك؟"></textarea></div>
                <div class="field"><label>العنوان</label><input v-model="storeAddr" class="input" placeholder="منطقة / شارع" /></div>
                <div class="field"><label>الناحية</label><select v-model="storeDist" class="select"><option value="">اختر…</option><option v-for="d in districts" :key="d.id" :value="d.id">{{ d.name }}</option></select></div>
              </div>

              <!-- كود الدعوة — للزبون فقط -->
              <div v-if="role === 'customer'" class="field">
                <label>كود الدعوة (اختياري)</label>
                <input v-model="referral" class="input" placeholder="كود صديقك — تاخذ نقاط ترحيب" maxlength="20" />
              </div>

              <!-- شريط تحقق تلغرام -->
              <div v-if="!regVerified" class="panel panel-pad" style="background:var(--bg-blue-soft);border-radius:var(--r-md)">
                <div class="flex gap-2" style="align-items:center">
                  <span class="msm" style="color:var(--info)">telegram</span>
                  <div>
                    <b class="text-sm">تحقق برقمك عبر تلغرام</b>
                    <p class="text-xs text-muted">افتح البوت وشارك رقمك — وبعدها اكتب الرمز اللي يوصلك</p>
                  </div>
                </div>
                <template v-if="regStarted">
                  <div class="flex gap-2" style="align-items:center;margin-block:var(--sp-3)">
                    <div class="loader"></div>
                    <span class="text-sm text-muted">بنتظر التحقق…</span>
                  </div>
                  <a class="btn btn-soft btn-md" :href="`https://t.me/${regBot}?start=${regToken}`" target="_blank">
                    <span class="msm">send</span> افتح البوت مرة ثانية
                  </a>
                </template>
                <button v-else type="button" class="btn btn-soft btn-md" style="margin-block-start:var(--sp-3)" @click="startReg">ابدأ التحقق عبر تلغرام</button>
              </div>
              <div v-else class="panel panel-pad text-sm" style="background:var(--bg-blue-soft);border-radius:var(--r-md)">
                ✅ تحقق الرقم من البوت — اكتب الرمز اللي دزّه لك وكمّل بياناتك
              </div>

              <div class="field">
                <label>الرمز من تلغرام</label>
                <input v-model="regCode" class="input" placeholder="الرمز من محادثة البوت" inputmode="numeric" :disabled="!regVerified" />
              </div>

              <p v-if="err" class="err text-danger" style="font-weight:700;font-size:var(--fs-sm)">{{ err }}</p>
              <button class="btn btn-accent btn-lg btn-block" type="submit" :disabled="busy || (regStarted && !regVerified)">
                {{ busy ? '…' : (regStarted ? 'إنشاء الحساب' : 'ابدأ التحقق') }}
              </button>
            </form>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>