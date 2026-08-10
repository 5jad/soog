/* ═══════════ الطلبات ═══════════ */
let ordersState = { status: 'all' };

async function renderOrders() {
  const el = document.getElementById('content');
  const statuses = ['all', 'new', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled'];
  el.innerHTML = `<div class="filter-bar">
      ${statuses.map(st => `<span class="chip${ordersState.status === st ? ' active' : ''}" onclick="ordersState.status='${st}';renderOrders()">${({ all: 'الكل', new: 'جديد 🔔', preparing: 'قيد التجهيز', ready: 'جاهز', delivering: 'مع المندوب', delivered: 'تم التسليم', cancelled: 'ملغي' })[st]}</span>`).join('')}
    </div><div class="skel"></div>`;
  const d = await API.get('/api/admin/orders?status=' + ordersState.status);
  el.innerHTML = `
    <div class="card">
      <div class="card-title"><span>الطلبات (${d.orders.length})</span><span class="more">عرض لحظي — كل الأدوار</span></div>
      ${d.orders.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>الطلب</th><th>المحل</th><th>الزبون</th><th>المندوب</th><th>المبلغ</th><th>الحالة</th><th>الوقت</th><th>إجراءات</th></tr>
        ${d.orders.map(o => `<tr>
          <td><span class="nm" style="direction:ltr;display:inline-block">${esc(o.code)}</span><div class="sb">#${o.id}</div></td>
          <td>${esc(o.store_name)}</td>
          <td>${esc(o.user_name || '-')}<div class="sb" dir="ltr">${esc(o.user_phone || '')}</div></td>
          <td>${esc(o.courier_name || '—')}</td>
          <td>${moneySpan(o.total)}</td>
          <td>${statusChip(o.status)}</td>
          <td class="muted">${timeAgo(o.created_at)}</td>
          <td><div class="c-actions">
            <button class="btn btn-ghost btn-sm" onclick="orderModal(${o.id})">تفاصيل</button>
            ${['new', 'preparing', 'ready', 'delivering'].includes(o.status) ? `<button class="btn btn-danger btn-sm" onclick="cancelOrder(${o.id})">إلغاء</button>` : ''}
          </div></td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">🧾</span>لا طلبات بهذه الحالة</div>'}
    </div>`;
}

async function orderModal(id) {
  await guard(async () => {
    const d = await API.get('/api/admin/orders/' + id);
    const o = d.order;
    openModal(`
      <div class="mt"><span>${esc(o.code)} — ${esc(o.store_name)}</span><span class="x" onclick="closeModal()">✕</span></div>
      ${statusChip(o.status)}
      <div class="mrow"><span>الزبون</span><span>${esc(o.user_name)} ${esc(o.user_phone || '')}</span></div>
      <div class="mrow"><span>العنوان</span><span class="muted">${esc(o.address_text || '-')}</span></div>
      ${(o.items || []).map(it => `<div class="mrow"><span>${esc(it.name)} ${it.variant ? '(' + esc(it.variant) + ')' : ''} ×${it.qty}</span><span>${moneySpan(it.price * it.qty)}</span></div>`).join('')}
      <div class="mrow"><span>التوصيل</span><span>${moneySpan(o.delivery_fee)}</span></div>
      ${o.discount ? `<div class="mrow"><span style="color:var(--danger)">الخصم</span><span style="color:var(--danger)">−${moneySpan(o.discount)}</span></div>` : ''}
      <div class="mtotal"><span>الكاش</span><span>${moneySpan(o.total)}</span></div>
      <label class="f-label">تغيير الحالة</label>
      <select class="f-select" id="oStatus">
        ${['new', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled', 'returned'].map(s => `<option value="${s}" ${s === o.status ? 'selected' : ''}>${({ new: 'جديد', preparing: 'قيد التجهيز', ready: 'جاهز', delivering: 'مع المندوب', delivered: 'تم التسليم', cancelled: 'ملغي', returned: 'مرتجع' })[s]}</option>`).join('')}
      </select>
      <button class="btn btn-navy" style="width:100%;margin-top:12px" onclick="changeOrderStatus(${o.id})">حفظ</button>
    `);
  });
}

async function changeOrderStatus(id) {
  const status = document.getElementById('oStatus').value;
  await guard(async () => {
    await API.patch(`/api/admin/orders/${id}`, { status, note: 'تدخل إداري' });
    toast('تغيّرت الحالة ✓');
    closeModal(); renderOrders();
  });
}

async function cancelOrder(id) {
  const note = prompt('سبب الإلغاء (يوصله الزبون):') || 'إلغاء من الإدارة';
  await guard(async () => {
    await API.patch(`/api/admin/orders/${id}`, { status: 'cancelled', note });
    toast('الطلب ملغي');
    renderOrders();
  });
}
