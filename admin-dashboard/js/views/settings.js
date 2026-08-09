/* ═══════════ الإعدادات ═══════════ */
const SETTING_FIELDS = [
  ['platform_name', 'اسم المنصة', 'text'],
  ['platform_slogan', 'الشعار النصي', 'text'],
  ['governorate_name', 'المحافظة الافتراضية', 'text'],
  ['commission_rate', 'عمولة المنصة %', 'number'],
  ['courier_rate', 'أجر المندوب %', 'number'],
  ['ad_price_3d', 'سعر الإعلان 3 أيام (د.ع)', 'number'],
  ['ad_price_7d', 'سعر الإعلان 7 أيام (د.ع)', 'number'],
  ['ad_price_14d', 'سعر الإعلان 14 يوم (د.ع)', 'number'],
  ['refund_days', 'مهلة الإرجاع (أيام)', 'number'],
  ['free_delivery_min', 'التوصيل المجاني فوق (د.ع)', 'number'],
  ['daily_goal', 'هدف المبيعات اليومي (د.ع)', 'number'],
];

async function renderSettings() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/settings');
  const s = d.settings;
  const dm = await API.get('/api/admin/dummy').catch(() => null);
  const mode = dm?.mode || 'shown';
  const st = dm?.stats || {};
  el.innerHTML = `
    <div class="card" style="max-width:620px">
      <div class="card-title"><span>⚙️ إعدادات المنصة</span></div>
      ${SETTING_FIELDS.map(([k, label, type]) => `
        <label class="f-label">${label}</label>
        <input class="f-input" id="set_${k}" type="${type}" value="${esc(s[k] ?? '')}" onchange="saveSetting('${k}')">
      `).join('')}
      <div style="font-size:11px;color:var(--muted);font-weight:700;margin-top:10px">💡 كل تعديل يُحفظ فوراً وينعكس على التطبيق والباك اند.</div>
    </div>
    
    <div class="card" style="max-width:620px;border:2px solid var(--accent)">
      <div class="card-title"><span>👁️‍🗨️ وضع العرض التجريبي (Demo Mode)</span>
        <span class="chip ${mode === 'shown' ? 'active' : ''}" style="font-size:10px">${mode === 'shown' ? 'ظاهر الآن ✓' : 'مخفي الآن'}</span>
      </div>
      <div class="note" style="background:var(--glass-l1);padding:10px;border-radius:12px;font-size:11px;color:var(--muted);font-weight:800;margin-bottom:14px">
        زر "إظهار" يعرض البيانات التجريبية الموجودة (ولو ماكو يولدها)، وزر "إخفاء" يخفيها من الداشبورد والتطبيق <b>بدون مسح</b> — تبقى محفوظة وجاهزة للعرض مجدداً.
      </div>
      <div class="mrow"><span>المتاجر الوهمية</span><span>${st.stores ?? 0}</span></div>
      <div class="mrow"><span>المنتجات الوهمية</span><span>${st.products ?? 0}</span></div>
      <div class="mrow"><span>المستخدمون الوهميون</span><span>${st.users ?? 0}</span></div>
      <div class="mrow"><span>الطلبات الوهمية</span><span>${st.orders ?? 0}</span></div>
      <div style="display:flex;gap:10px;margin-top:12px">
        <button class="btn btn-navy" style="flex:1" onclick="demoShow()">إظهار البيانات التجريبية 👁️</button>
        <button class="btn btn-danger" style="flex:1" onclick="demoHide()">إخفاء البيانات التجريبية 🙈</button>
      </div>
      <button class="btn btn-ghost" style="width:100%;margin-top:10px;font-size:11px" onclick="demoRegenerate()">🔄 إعادة توليد من الصفر (يمسح الحالي أولاً)</button>
    </div>`;
}

async function demoShow() {
  await guard(async () => {
    const r = await API.post('/api/admin/dummy');
    toast(r.stats ? `ظهرت البيانات التجريبية ✓ (${r.stats.stores} متجر، ${r.stats.products} منتج)` : 'تم الإظهار ✓');
    renderSettings();
  });
}

async function demoHide() {
  await guard(async () => {
    const r = await API.post('/api/admin/dummy/hide');
    toast('أخفيت البيانات التجريبية 🙈 — تبقى محفوظة بدون مسح');
    renderSettings();
  });
}

async function demoRegenerate() {
  if (!confirm('رح تُمسح البيانات الوهمية الحالية وتتولد من جديد — متأكد؟')) return;
  await guard(async () => {
    await API.del('/api/admin/dummy');
    await API.post('/api/admin/dummy');
    toast('أعيد توليد البيانات التجريبية من الصفر ✓');
    renderSettings();
  });
}

async function saveSetting(key) {
  const value = document.getElementById('set_' + key).value;
  await guard(async () => {
    await API.patch('/api/admin/settings', { key, value });
    toast('انحفظت ✓ ' + key);
  });
}
