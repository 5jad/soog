/* ═══════════ المستخدمون ═══════════ */
let usersState = { role: 'all' };

async function renderUsers() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/users?role=' + usersState.role);
  el.innerHTML = `
    <div class="filter-bar">
      ${['all', 'customer', 'vendor', 'delivery', 'admin'].map(ro => `<span class="chip${usersState.role === ro ? ' active' : ''}" onclick="usersState.role='${ro}';renderUsers()">${({ all: 'الكل', customer: '🛍 زبائن', vendor: '🏪 تجار', delivery: '🛵 مناديب', admin: '👑 أدمن' })[ro]}</span>`).join('')}
      <button class="btn btn-navy btn-sm" style="margin-inline-start:auto" onclick="addUserModal()">+ إضافة مندوب/تاجر</button>
    </div>
    <div class="card">
      <div class="card-title"><span>المستخدمون (${d.users.length})</span></div>
      ${d.users.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>المستخدم</th><th>الدور</th><th>الرقم</th><th>التاريخ</th><th>الحالة</th><th>إجراءات</th></tr>
        ${d.users.map(u => `<tr>
          <td><div class="c-main"><div class="emoji-box">${u.avatar}</div><div class="nm">${esc(u.name) || 'بدون اسم'}</div></div></td>
          <td>${({ customer: '🛍 زبون', vendor: '🏪 تاجر', delivery: '🛵 مندوب', admin: '👑 أدمن' })[u.role]}</td>
          <td class="muted" dir="ltr">${esc(u.phone)}</td>
          <td class="muted">${new Date(u.created_at).toLocaleDateString('ar-IQ')}</td>
          <td>${u.blocked ? '<span class="rej-chip">محظور</span>' : '<span class="live-chip">نشط ✓</span>'}</td>
          <td><div class="c-actions">
            ${u.role !== 'admin' ? `<button class="btn ${u.blocked ? 'btn-success' : 'btn-danger'} btn-sm" onclick="toggleBlock(${u.id},${!u.blocked})">${u.blocked ? 'فك الحظر' : 'حظر'}</button>` : ''}
          </div></td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">👥</span>لا مستخدمين بهذا الدور</div>'}
    </div>`;
}

async function toggleBlock(id, blocked) {
  await guard(async () => {
    await API.patch(`/api/admin/users/${id}`, { blocked });
    toast(blocked ? 'انحظر المستخدم' : 'انفك الحظر');
    renderUsers();
  });
}

function addUserModal() {
  openModal(`
    <div class="mt"><span>إضافة مستخدم ➕</span><span class="x" onclick="closeModal()">✕</span></div>
    <label class="f-label">الاسم</label><input class="f-input" id="auName">
    <label class="f-label">رقم الهاتف</label><input class="f-input" id="auPhone" dir="ltr" placeholder="07XXXXXXXXX">
    <label class="f-label">كلمة المرور (مهمة لتسجيل الدخول)</label><input class="f-input" type="password" id="auPass" placeholder="••••••••">
    <label class="f-label">الدور</label>
    <select class="f-select" id="auRole">
      <option value="delivery">🛵 مندوب</option>
      <option value="vendor">🏪 تاجر</option>
      <option value="customer">🛍 زبون</option>
    </select>
    <button class="btn btn-navy" style="width:100%;margin-top:14px" onclick="addUserSave()">إضافة</button>
  `);
}

async function addUserSave() {
  const name = document.getElementById('auName').value;
  const phone = document.getElementById('auPhone').value.replace(/\D/g, '');
  const password = document.getElementById('auPass').value;
  const role = document.getElementById('auRole').value;
  if (!name || phone.length < 10) return toast('الاسم والرقم مطلوبين', true);
  if (!password) return toast('كلمة المرور مطلوبة', true);
  await guard(async () => {
    await API.post('/api/admin/users', { name, phone, password, role });
    toast('انضاف المستخدم ✓');
    closeModal(); renderUsers();
  });
}
