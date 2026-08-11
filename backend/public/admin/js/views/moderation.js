/* ═══════════ الكوبونات ═══════════ */
async function renderCoupons() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/coupons');
  const coupons = d.coupons || [];
  const usages = d.usages || [];
  el.innerHTML = `
    <div class="kpi-grid">
      <div class="kpi glass"><div class="kic">🏷</div><div class="kn">${coupons.length}</div><div class="kl">كوبون</div></div>
      <div class="kpi glass"><div class="kic">🎫</div><div class="kn">${usages.length}</div><div class="kl">أحدث الاستخدامات</div></div>
      <div class="kpi glass"><div class="kic">🛍</div><div class="kn">${coupons.filter(c => c.store_id).length}</div><div class="kl">كوبونات المحلات</div></div>
    </div>
    <div class="card">
      <div class="card-title"><span>كل الكوبونات</span><span class="more">أنشأها التجار تلقائياً</span></div>
      <div class="table-wrap"><table class="tbl">
        <tr><th>الكود</th><th>المحل</th><th>الخصم</th><th>الحد الأدنى</th><th>سقف الخصم</th><th>متبقي</th><th>الحالة</th><th>الانتهاء</th></tr>
        ${coupons.length ? coupons.map(c => `<tr>
          <td><span class="code-pill">${esc(c.code)}</span></td>
          <td>${esc(c.store_name || 'منصة (عام)')}</td>
          <td><b>${c.percent ? c.percent + '%' : moneySpan(c.flat)}</b></td>
          <td>${moneySpan(c.min_total)}</td>
          <td>${c.max_discount ? moneySpan(c.max_discount) : '—'}</td>
          <td>${c.uses_limit ? c.uses_left + ' / ' + c.uses_limit : '∞'}</td>
          <td>${c.active ? statusChip('active') : statusChip('rejected')}</td>
          <td class="muted">${c.expires_at ? new Date(c.expires_at).toLocaleDateString('ar-IQ') : '—'}</td>
        </tr>`).join('') : '<tr><td colspan="8"><div class="empty"><span class="ic">🏷</span>لا كوبونات بعد</div></td></tr>'}
      </table></div>
    </div>
    <div class="card">
      <div class="card-title"><span>آخر استخدامات الكوبونات</span></div>
      ${usages.length ? usages.map(u => `
        <div class="list-item glass">
          <div class="lic">🎫</div>
          <div class="lt"><div class="a">${esc(u.user_name)} استخدم <span class="code-pill">${esc(u.code)}</span></div>
          <div class="b">خصم ${moneySpan(u.discount)} • طلب #${u.order_id} • ${timeAgo(u.created_at)}</div></div>
        </div>`).join('') : '<div class="empty"><span class="ic">🎫</span>لا استخدامات بعد</div>'}
    </div>`;
}

/* ═══════════ مراجعة التقييمات ═══════════ */
async function renderReviews() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/reviews');
  const reviews = d.reviews || [];
  const avgs = {};
  reviews.forEach(r => { avgs[r.store_name] = avgs[r.store_name] || { s: 0, n: 0 }; avgs[r.store_name].s += r.rating; avgs[r.store_name].n++; });
  el.innerHTML = `
    <div class="kpi-grid">
      <div class="kpi glass"><div class="kic">⭐</div><div class="kn">${reviews.length}</div><div class="kl">التقييمات</div></div>
      <div class="kpi glass"><div class="kic">😡</div><div class="kn">${reviews.filter(r => r.rating <= 2).length}</div><div class="kl">تقييمات منخفضة</div></div>
    </div>
    <div class="card">
      <div class="card-title"><span>كل التقييمات</span><span class="more">الأخيرة أولاً</span></div>
      ${reviews.length ? reviews.map(r => `
        <div class="list-item glass">
          <div class="lic">${'⭐'.repeat(Math.max(1, Math.min(5, r.rating)))}</div>
          <div class="lt">
            <div class="a">${esc(r.user_name || 'زائر')} — <b>${esc(r.store_name)}</b>${r.product_name ? ` · ${esc(r.product_name)}` : ''}</div>
            <div class="b">${esc(r.comment || 'بدون تعليق')}</div>
            <div class="b muted">طلب #${esc(r.order_code || '—')} • ${timeAgo(r.created_at)}${r.reply ? ` • رد: ${esc(r.reply)}` : ''}</div>
          </div>
          <div class="actions">
            <span class="nm">${r.rating}/5</span>
            <button class="btn btn-danger btn-sm" onclick="reviewDelete(${r.id})">حذف 🗑</button>
          </div>
        </div>`).join('') : '<div class="empty"><span class="ic">⭐</span>ماكو تقييمات بعد</div>'}
    </div>`;
}

async function reviewDelete(id) {
  if (!confirm('تحذف التقييم نهائياً؟')) return;
  await guard(async () => {
    await API.del(`/api/admin/reviews/${id}`);
    toast('انحذف التقييم ✓');
    renderReviews();
  });
}

/* ═══════════ طلبات الإرجاع ═══════════ */
async function renderRefunds() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/refunds');
  const refunds = d.refunds || [];
  const pending = refunds.filter(r => r.status === 'pending');
  el.innerHTML = `
    <div class="card" style="border:2px solid var(--accent)">
      <div class="card-title"><span>🔄 قيد الانتظار</span><span class="more">${pending.length}</span></div>
      ${pending.length ? pending.map(r => `
        <div class="list-item glass">
          <div class="lic">${r.type === 'exchange' ? '🔁' : '↩️'}</div>
          <div class="lt">
            <div class="a">طلب #${esc(r.order_code)} — ${esc(r.store_name)}</div>
            <div class="b">${esc(r.user_name)} (${esc(r.user_phone || '')}) • ${moneySpan(r.total)} • ${r.type === 'exchange' ? 'استبدال' : 'إرجاع'}${r.desired ? ` ← ${esc(r.desired)}` : ''}</div>
            <div class="b muted">السبب: ${esc(r.reason || '—')} • ${timeAgo(r.created_at)}</div>
          </div>
          <div class="actions">
            ${r.decision_by ? '' : `<button class="btn btn-success btn-sm" onclick="refundDecision(${r.id},'accepted')">قبول ✓</button>
            <button class="btn btn-danger btn-sm" onclick="refundDecision(${r.id},'rejected')">رفض ✗</button>`}
          </div>
        </div>`).join('') : '<div class="empty"><span class="ic">✅</span>ماكو طلبات معلقة</div>'}
    </div>
    <div class="card">
      <div class="card-title"><span>السجل</span></div>
      ${refunds.filter(r => r.status !== 'pending').length ? refunds.filter(r => r.status !== 'pending').map(r => `
        <div class="list-item glass" style="opacity:.8">
          <div class="lic">${r.type === 'exchange' ? '🔁' : '↩️'}</div>
          <div class="lt"><div class="a">طلب #${esc(r.order_code)} — ${esc(r.store_name)}</div>
          <div class="b muted">${esc(r.user_name)} • ${r.status === 'accepted' ? 'مقبول ✓' : 'مرفوض ✗'}</div></div>
          ${statusChip(r.status === 'accepted' ? 'active' : 'rejected')}
        </div>`).join('') : '<div class="empty"><span class="ic">📭</span>لا سجل</div>'}
    </div>`;
}

async function refundDecision(id, status) {
  const reason = status === 'rejected' ? (prompt('سبب الرفض (يوصله للزبون)') || '') : '';
  if (status === 'rejected' && !reason) { toast('اكتب سبب الرفض', true); return; }
  await guard(async () => {
    await API.patch(`/api/admin/refunds/${id}`, { status, reason });
    toast(status === 'accepted' ? 'قبلت الإرجاع ✓' : 'رفضت الطلب');
    renderRefunds();
  });
}