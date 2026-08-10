/* ═══════════ المحافظات والأحياء والأقسام ═══════════ */
async function renderGeo() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const [g, c] = await Promise.all([API.get('/api/admin/governorates'), API.get('/api/admin/categories')]);

  const govHtml = g.governorates.map(gov => {
    const districtBadges = gov.districts.map(d =>
      `<span style="display:inline-flex;align-items:center;gap:3px;background:var(--glass-l2);padding:2px 7px;border-radius:20px;font-size:11px;margin:2px">
        ${esc(d.name)}
        <span style="cursor:pointer;color:var(--danger);font-weight:900" onclick="delDistrict(${d.id})">✕</span>
      </span>`
    ).join(' ');
    return `
      <div class="list-item glass" style="flex-wrap:wrap;gap:10px">
        <div class="lic">🏙</div>
        <div class="lt" style="flex:1">
          <div class="a">${esc(gov.name)} <span class="muted" style="font-weight:700;font-size:10px">${esc(gov.name_en || '')}</span></div>
          <div class="b" style="margin-top:4px">${districtBadges || '<span class="muted">لا أحياء</span>'}</div>
        </div>
        <div style="display:flex;gap:6px;align-items:center;flex-shrink:0">
          <button class="btn btn-ghost btn-sm" onclick="addDistrictModal(${gov.id}, '${esc(gov.name)}')">+ حي</button>
          <button class="btn btn-danger btn-sm" onclick="delGov(${gov.id}, '${esc(gov.name)}')">حذف</button>
        </div>
      </div>`;
  }).join('');

  const catHtml = c.categories.map(cat => `<tr>
    <td><div class="c-main"><div class="emoji-box">${cat.icon}</div><div class="nm">${esc(cat.name)}</div></div></td>
    <td class="muted">${cat.sort}</td>
    <td><button class="btn btn-danger btn-sm" onclick="delCat(${cat.id})">حذف</button></td>
  </tr>`).join('');

  el.innerHTML = `
    <div class="grid2">
      <div class="card">
        <div class="card-title"><span>🗺 المحافظات</span><button class="btn btn-navy btn-sm" onclick="addGovModal()">+ إضافة</button></div>
        <div style="font-size:11px;color:var(--muted);font-weight:700;background:var(--glass-l1);border-radius:12px;padding:10px 12px;margin-bottom:12px">
          💡 كل محافظة تضيفها يظهر التطبيق متاجرها وأحياءها تلقائياً
        </div>
        ${govHtml || '<div class="empty"><span class="ic">🗺</span>لا محافظات</div>'}
      </div>

      <div class="card">
        <div class="card-title"><span>🏷 الأقسام</span><button class="btn btn-navy btn-sm" onclick="addCatModal()">+ إضافة</button></div>
        <div class="table-wrap"><table class="tbl" style="min-width:0">
          <tr><th>القسم</th><th>الترتيب</th><th></th></tr>
          ${catHtml || '<tr><td colspan="3" style="text-align:center;color:var(--muted)">لا أقسام</td></tr>'}
        </table></div>
      </div>
    </div>`;
}

/* ── إضافة محافظة ── */
function addGovModal() {
  openModal(`
    <div class="mt"><span>إضافة محافظة 🏙</span><span class="x" onclick="closeModal()">✕</span></div>
    <label class="f-label">الاسم بالعربي</label><input class="f-input" id="gName" placeholder="مثال: بغداد">
    <label class="f-label">الاسم بالإنجليزي</label><input class="f-input" id="gEn" dir="ltr" placeholder="Baghdad">
    <button class="btn btn-navy" style="width:100%;margin-top:14px" onclick="addGovSave()">إضافة</button>
  `);
}
async function addGovSave() {
  const name = document.getElementById('gName').value;
  if (!name) return toast('الاسم مطلوب', true);
  await guard(async () => {
    await API.post('/api/admin/governorates', { name, name_en: document.getElementById('gEn').value });
    toast('انضافت المحافظة ✓');
    closeModal(); renderGeo();
  });
}

/* ── إضافة حي ── */
function addDistrictModal(gid, gname) {
  openModal(`
    <div class="mt"><span>إضافة حي — ${gname}</span><span class="x" onclick="closeModal()">✕</span></div>
    <label class="f-label">اسم الحي</label><input class="f-input" id="dName" placeholder="مثال: حي الجهاد">
    <button class="btn btn-navy" style="width:100%;margin-top:14px" onclick="addDistrictSave(${gid})">إضافة</button>
  `);
}
async function addDistrictSave(gid) {
  const name = document.getElementById('dName').value;
  if (!name) return toast('الاسم مطلوب', true);
  await guard(async () => {
    await API.post('/api/admin/districts', { governorate_id: gid, name });
    toast('انضاف الحي ✓');
    closeModal(); renderGeo();
  });
}

/* ── حذف محافظة ── */
async function delGov(id, name) {
  if (!confirm('متأكد تحذف محافظة "' + name + '"؟ سيتم حذف كل أحيائها أيضاً!')) return;
  await guard(async () => {
    await API.del('/api/admin/governorates/' + id);
    toast('انحذفت المحافظة ✓');
    renderGeo();
  });
}

/* ── حذف حي ── */
async function delDistrict(id) {
  if (!confirm('حذف هذا الحي؟')) return;
  await guard(async () => {
    await API.del('/api/admin/districts/' + id);
    toast('انحذف الحي ✓');
    renderGeo();
  });
}

/* ── إضافة قسم ── */
function addCatModal() {
  openModal(`
    <div class="mt"><span>إضافة قسم 🏷</span><span class="x" onclick="closeModal()">✕</span></div>
    <label class="f-label">اسم القسم</label><input class="f-input" id="cName" placeholder="مثال: مطاعم وأكل">
    <label class="f-label">الأيقونة (إيموجي)</label><input class="f-input" id="cIcon" value="🍔">
    <button class="btn btn-navy" style="width:100%;margin-top:14px" onclick="addCatSave()">إضافة</button>
  `);
}
async function addCatSave() {
  const name = document.getElementById('cName').value;
  if (!name) return toast('الاسم مطلوب', true);
  await guard(async () => {
    await API.post('/api/admin/categories', { name, icon: document.getElementById('cIcon').value });
    toast('انضاف القسم ✓');
    closeModal(); renderGeo();
  });
}

/* ── حذف قسم ── */
async function delCat(id) {
  if (!confirm('متأكد تحذف هذا القسم؟')) return;
  await guard(async () => {
    await API.del('/api/admin/categories/' + id);
    toast('انحذف القسم');
    renderGeo();
  });
}
