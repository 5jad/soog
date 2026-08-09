/* ═══════════ الإشعارات الجماعية ═══════════ */
async function renderNotify() {
  const el = document.getElementById('content');
  el.innerHTML = `
    <div class="card" style="max-width:560px">
      <div class="card-title"><span>🔔 إرسال إشعار جماعي</span></div>
      <label class="f-label">إلى من؟</label>
      <select class="f-select" id="nRole">
        <option value="all">📢 كل المستخدمين</option>
        <option value="customer">🛍 الزبائن</option>
        <option value="vendor">🏪 التجار</option>
        <option value="delivery">🛵 المندوبين</option>
      </select>
      <label class="f-label">العنوان</label>
      <input class="f-input" id="nTitle" placeholder="مثال: عروض الموسم 🔥">
      <label class="f-label">الرسالة</label>
      <textarea class="f-input" id="nBody" placeholder="تفاصيل الإشعار..."></textarea>
      <button class="btn btn-cta" style="width:100%;margin-top:14px" onclick="sendBroadcast()">إرسال 📤</button>
      <div style="font-size:11px;color:var(--muted);font-weight:700;margin-top:10px">💡 الإشعارات تظهر فوراً داخل التطبيق لجميع المستخدمين بهذا الدور.</div>
    </div>`;
}

async function sendBroadcast() {
  const role = document.getElementById('nRole').value;
  const title = document.getElementById('nTitle').value;
  const body = document.getElementById('nBody').value;
  if (!title) return toast('العنوان مطلوب', true);
  await guard(async () => {
    await API.post('/api/admin/notify', { role, title, body });
    toast('انرسل الإشعار للجميع ✓');
    document.getElementById('nTitle').value = '';
    document.getElementById('nBody').value = '';
  });
}
