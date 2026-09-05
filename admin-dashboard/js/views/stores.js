/* ═══════════ المحلات ═══════════ */
let storesState = { status: 'all', data: null, docs: [] };

async function renderStores() {
  const el = document.getElementById('content');
  el.innerHTML = `<div class="filter-bar">
      ${['all', 'pending', 'approved', 'suspended'].map(st => `<span class="chip${storesState.status === st ? ' active' : ''}" onclick="storesState.status='${st}';renderStores()">${({ all: 'الكل', pending: 'قيد المراجعة ⏳', approved: 'نشط ✓', suspended: 'موقوف' })[st]}</span>`).join('')}
    </div><div class="skel"></div>`;
  const d = await API.get('/api/admin/stores?status=' + storesState.status);
  storesState.data = d.stores;
  storesState.docs = d.pending_documents;

  const pendingCount = d.pending_documents.length;
  el.innerHTML = `
    <div class="card" style="border:2px solid var(--accent);${pendingCount ? '' : 'display:none'}">
      <div class="card-title"><span>📄 مستندات بانتظار مراجعتك</span><span class="more">${pendingCount}</span></div>
      ${d.pending_documents.map(doc => `
        <div class="list-item glass">
          <div class="lic">📄</div>
          <div class="lt"><div class="a">${esc(doc.store_name)} — ${esc(doc.title)}</div><div class="b">${esc(doc.type)} • انرسل ${timeAgo(doc.created_at)}</div></div>
          <div class="actions">
            <button class="btn btn-success btn-sm" onclick="reviewDoc(${doc.id},'approved')">اعتماد ✓</button>
            <button class="btn btn-danger btn-sm" onclick="reviewDoc(${doc.id},'rejected')">رفض ✗</button>
          </div>
        </div>`).join('') || '<div class="empty" style="padding:14px"><span class="ic">✅</span>كلشي مصفى</div>'}
    </div>

    <div class="card">
      <div class="card-title"><span>المحلات (${d.stores.length})</span></div>
      ${d.stores.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>المحل</th><th>المالك</th><th>القسم</th><th>التقييم</th><th>عمولة</th><th>توصيل</th><th>الحالة</th><th>إجراءات</th></tr>
        ${d.stores.map(s => `<tr>
          <td><div class="c-main"><div class="emoji-box">${esc(s.logo)}</div><div><div class="nm">${esc(s.name)}</div><div class="sb">${esc(s.district_name || '')}</div></div></div></td>
          <td><div class="nm" style="font-size:11.5px">${esc(s.owner_name || 'بدون مالك')}</div><div class="sb" dir="ltr">${esc(s.owner_phone || '')}</div></td>
          <td class="muted">${esc(s.category_name || '-')}</td>
          <td>⭐ ${s.rating_avg} <span class="muted" style="font-size:10px">(${s.rating_count})</span></td>
          <td>${moneySpan(s.commission_rate * 1000 / 1000)}<div class="sb">${s.commission_rate}%</div></td>
          <td>${moneySpan(s.delivery_fee)}</td>
          <td>${statusChip(s.status)}</td>
          <td><div class="c-actions">
            <button class="btn btn-ghost btn-sm" onclick="storeModal(${s.id})">تفاصيل</button>
            ${s.status !== 'approved' ? `<button class="btn btn-success btn-sm" onclick="setStoreStatus(${s.id},'approved')">اعتماد ✓</button>` : ''}
            ${s.status === 'approved' ? `<button class="btn btn-danger btn-sm" onclick="setStoreStatus(${s.id},'suspended')">إيقاف</button>` : ''}
          </div></td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">🏪</span>ماكو محلات بهذه الحالة</div>'}
    </div>`;
}

async function setStoreStatus(id, status) {
  await guard(async () => {
    await API.patch(`/api/admin/stores/${id}`, { status });
    toast(status === 'approved' ? 'تم الاعتماد ✓' : 'تم الإيقاف');
    renderStores();
  });
}

async function reviewDoc(id, status) {
  const reason = status === 'rejected' ? (prompt('سبب الرفض (يوصله التاجر):') || '') : '';
  await guard(async () => {
    await API.patch(`/api/admin/documents/${id}`, { status, reason });
    toast(status === 'approved' ? 'اعتمدت المستند ✓' : 'رفضت المستند');
    renderStores();
  });
}

async function storeModal(id) {
  const s = storesState.data.find(x => x.id === id);
  if (!s) return;
  const d = await API.get('/api/stores/' + id);
  openModal(`
    <div class="mt"><span>${esc(s.logo)} ${esc(s.name)}</span><span class="x" onclick="closeModal()">✕</span></div>
    <div class="mrow"><span>الحالة</span>${statusChip(s.status)}</div>
    <div class="mrow"><span>التوثيق</span><span>--</span></div>
    <div class="mrow"><span>العمولة</span><span>${s.commission_rate}%</span></div>
    <div class="mrow"><span>التوصيل</span><span>${moneySpan(s.delivery_fee)} (مجاني فوق ${moneySpan(s.free_delivery_min)})</span></div>
    <div class="mrow"><span>العنوان</span><span class="muted">${esc(s.address || '-')}</span></div>
    <div class="mrow"><span>ساعات العمل</span><span>${esc(s.open_time)} – ${esc(s.close_time)}</span></div>
    <div style="display:flex;gap:8px;margin-top:12px">
      <label class="f-label" style="margin:0;flex:1">العمولة % <input class="f-input" id="mComm" type="number" value="${s.commission_rate}"></label>
      <label class="f-label" style="margin:0;flex:1">التوصيل د.ع <input class="f-input" id="mFee" type="number" value="${s.delivery_fee}"></label>
    </div>
    <div class="mt" style="margin-top:14px">موقع المحل 📍</div>
    <div style="display:flex;gap:8px">
      <label class="f-label" style="margin:0;flex:1">خط العرض Lat <input class="f-input" id="mLat" dir="ltr" value="${s.lat ?? ''}"></label>
      <label class="f-label" style="margin:0;flex:1">خط الطول Lng <input class="f-input" id="mLng" dir="ltr" value="${s.lng ?? ''}"></label>
    </div>
    <label class="f-label">رابط الموقع (خرائط قوقل) <input class="f-input" id="mLocUrl" dir="ltr" placeholder="https://www.google.com/maps/..." value="${esc(s.location_url || '')}"></label>
    <div style="display:flex;gap:8px;margin-top:10px">
      <button class="btn btn-ghost" style="flex:1" onclick="gpsFill('mLat','mLng','mLocUrl')">📍 موقعي الحالي</button>
      <button class="btn btn-ghost" style="flex:1" onclick="openStoreMap('mLat','mLng','mLocUrl')">🗺 فتح على الخريطة</button>
    </div>
    <button class="btn btn-navy" style="width:100%;margin-top:12px" onclick="saveStoreMeta(${s.id})">حفظ التعديلات</button>
    <div class="card-title" style="margin-top:14px">المنتجات (${d.products.length})</div>
    ${d.products.slice(0, 6).map(p => `<div class="mrow"><span>${p.image} ${esc(p.name)}</span><span>${moneySpan(p.price)}</span></div>`).join('') || '<div class="empty" style="padding:10px">لا منتجات</div>'}
  `);
}

async function saveStoreMeta(id) {
  const comm = document.getElementById('mComm').value;
  const fee = document.getElementById('mFee').value;
  const lat = document.getElementById('mLat').value.trim();
  const lng = document.getElementById('mLng').value.trim();
  const locUrl = document.getElementById('mLocUrl').value.trim();
  await guard(async () => {
    await API.patch(`/api/admin/stores/${id}`, {
      commission_rate: comm, delivery_fee: fee,
      lat: lat || null, lng: lng || null, location_url: locUrl,
    });
    toast('انحفظت التعديلات ✓');
    closeModal(); renderStores();
  });
}

function mapLinkFor(lat, lng, url) {
  if (url && url.trim()) return url.trim();
  if (lat && lng) return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
  return null;
}

function gpsFill(latId, lngId, urlId) {
  if (!navigator.geolocation) return toast('المتصفح مايدعم تحديد الموقع', true);
  navigator.geolocation.getCurrentPosition(pos => {
    const lat = pos.coords.latitude, lng = pos.coords.longitude;
    const l = document.getElementById(latId), g = document.getElementById(lngId);
    if (l) l.value = lat.toFixed(6);
    if (g) g.value = lng.toFixed(6);
    const u = document.getElementById(urlId);
    if (u && !u.value.trim()) u.value = `https://www.google.com/maps/search/?api=1&query=${lat.toFixed(6)},${lng.toFixed(6)}`;
    toast('تم تحديد الموقع ✓');
  }, () => toast('ما أمكن الحصول على الموقع', true), { enableHighAccuracy: true });
}

function openStoreMap(latId, lngId, urlId) {
  const link = mapLinkFor(document.getElementById(latId).value, document.getElementById(lngId).value, document.getElementById(urlId).value);
  if (!link) return toast('ماكو موقع للمحل بعد', true);
  window.open(link, '_blank');
}

async function newStoreModal() {
  const govs = await API.get('/api/admin/governorates');
  openModal(`
    <div class="mt"><span>إضافة محل يدوي 🏠</span><span class="x" onclick="closeModal()">✕</span></div>
    <label class="f-label">اسم المحل</label><input class="f-input" id="nName" placeholder="مثال: الأصيل — ملابس">
    <label class="f-label">اسم صاحب المحل</label><input class="f-input" id="nOwnerName" placeholder="مثال: أبو علي">
    <label class="f-label">رقم هاتف صاحب المحل</label><input class="f-input" id="nOwnerPhone" placeholder="07xxxxxxxxx" dir="ltr">
    <label class="f-label">المحافظة</label>
    <select class="f-select" id="nGov">${govs.governorates.map(g => `<option value="${g.id}">${esc(g.name)}</option>`).join('')}</select>
    <label class="f-label">شعار المحل (صورة)</label>
    <div style="display:flex;gap:10px;align-items:center">
      <div id="nLogoPreview" style="width:56px;height:56px;border-radius:14px;background:var(--glass-l2);border:2px dashed var(--glass-border);display:flex;align-items:center;justify-content:center;font-size:28px;flex:none">🏠</div>
      <div style="flex:1">
        <input type="file" id="nLogoFile" accept="image/*" style="display:none" onchange="previewLogo(this)">
        <button class="btn btn-ghost" style="width:100%;margin-bottom:6px" onclick="document.getElementById('nLogoFile').click()">📷 اختر صورة</button>
        <input class="f-input" id="nLogoEmoji" placeholder="أو أدخل إيموجي: 🛒" oninput="document.getElementById('nLogoPreview').textContent=this.value||'🏠'" style="text-align:center;font-size:20px">
      </div>
    </div>
    <label class="f-label">موقع المحل 📍 (اختياري)</label>
    <div style="display:flex;gap:8px">
      <label class="f-label" style="margin:0;flex:1">خط العرض Lat <input class="f-input" id="nLat" dir="ltr"></label>
      <label class="f-label" style="margin:0;flex:1">خط الطول Lng <input class="f-input" id="nLng" dir="ltr"></label>
    </div>
    <input class="f-input" id="nLocUrl" placeholder="رابط الخرائط (اختياري) — أو من موقعي الحالي" dir="ltr">
    <button class="btn btn-ghost" style="width:100%;margin-bottom:10px" onclick="gpsFill('nLat','nLng','nLocUrl')">📍 استخدام موقعي الحالي (GPS)</button>
    <button class="btn btn-navy" style="width:100%;margin-top:14px" onclick="saveNewStore()">إضافة المحل</button>
  `);
}

function previewLogo(input) {
  if (!input.files[0]) return;
  const reader = new FileReader();
  reader.onload = e => {
    const preview = document.getElementById('nLogoPreview');
    preview.innerHTML = `<img src="${e.target.result}" style="width:100%;height:100%;object-fit:cover;border-radius:12px">`;
    preview.dataset.img = e.target.result;
  };
  reader.readAsDataURL(input.files[0]);
}

async function saveNewStore() {
  const name = document.getElementById('nName').value.trim();
  const ownerName = document.getElementById('nOwnerName').value.trim();
  const ownerPhone = document.getElementById('nOwnerPhone').value.trim();
  if (!name || !ownerName || !ownerPhone) return toast('الاسم وصاحب المحل ورقمه مطلوبين', true);
  const preview = document.getElementById('nLogoPreview');
  const logoImg = preview.dataset.img || null;
  const logoEmoji = document.getElementById('nLogoEmoji').value || '🏠';
  await guard(async () => {
    // إنشاء حساب تاجر تلقائياً إذا ما موجود
    let ownerId;
    try {
      const existing = await API.get('/api/admin/users?role=all');
      const found = existing.users.find(u => u.phone === ownerPhone.replace(/\D/g, ''));
      if (found) {
        ownerId = found.id;
      } else {
        await API.post('/api/admin/users', { phone: ownerPhone, name: ownerName, role: 'vendor', password: '12345678' });
        const fresh = await API.get('/api/admin/users?role=vendor');
        ownerId = fresh.users.find(u => u.phone === ownerPhone.replace(/\D/g, ''))?.id;
      }
    } catch(e) {
      return toast('فشل إنشاء حساب التاجر: ' + e.message, true);
    }
    if (!ownerId) return toast('تعذر تحديد التاجر', true);
    await API.post('/api/admin/stores', {
      owner_id: ownerId,
      name,
      governorate_id: document.getElementById('nGov').value,
      logo: logoImg || logoEmoji,
      lat: document.getElementById('nLat').value.trim() || null,
      lng: document.getElementById('nLng').value.trim() || null,
      location_url: document.getElementById('nLocUrl').value.trim(),
    });
    toast('انضاف المحل ✓');
    closeModal(); renderStores();
  });
}

async function generateDummy() {
  await guard(async () => {
    await API.post('/api/admin/dummy');
    toast('أظهرت البيانات التجريبية ✓');
    renderStores();
  });
}

async function clearDummy() {
  if (!confirm('متأكد تريد تخفي البيانات الوهمية؟ (تبقى محفوظة بدون مسح)')) return;
  await guard(async () => {
    await API.post('/api/admin/dummy/hide');
    toast('أخفيت البيانات الوهمية 🙈');
    renderStores();
  });
}
