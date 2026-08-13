/* ═══════════ الإعلانات ═══════════ */
async function renderAds() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/ads');
  const pending = d.ads.filter(a => a.status === 'pending');
  const active = d.ads.filter(a => a.status === 'active');
  const rest = d.ads.filter(a => a.status !== 'pending' && a.status !== 'active');
  el.innerHTML = `

    <div class="card" style="border:2px solid var(--accent)">
      <div class="card-title"><span>🖼 طلبات بانتظار موافقتك</span><span class="more">${pending.length}</span></div>
      ${pending.length ? pending.map(a => `
        <div class="list-item glass">
          <div class="lic">${esc(a.art)}</div>
          <div class="lt">
            <div class="a">${esc(a.store_name)} — ${esc(a.title)}</div>
            <div class="b">المدة: ${a.duration_days} يوم • السعر: ${moneySpan(a.price)} • انرسل ${timeAgo(a.created_at)}</div>
            ${a.product_name ? `<div class="b">📦 المنتج: ${esc(a.product_name)}</div>` : ''}
            ${a.note ? `<div class="b muted">📝 ملاحظة التاجر: ${esc(a.note)}</div>` : ''}
          </div>
          <div class="actions">
            <button class="btn btn-success btn-sm" onclick="adDecision(${a.id},'active')">موافقة ✓</button>
            <button class="btn btn-danger btn-sm" onclick="adDecision(${a.id},'rejected')">رفض ✗</button>
          </div>
        </div>`).join('') : '<div class="empty" style="padding:14px"><span class="ic">✅</span>ماكو طلبات معلقة</div>'}
    </div>

    <div class="card">
      <div class="card-title"><span>الإعلانات النشطة (تظهر بالرئيسية)</span><span class="more">تدور كل 4 ثواني</span></div>
      ${active.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>الترتيب</th><th>المحل</th><th>العنوان</th><th>المدة</th><th>المبلغ</th><th>انتهاء</th><th>إجراءات</th></tr>
        ${active.map((a, i) => `<tr>
          <td><span class="nm">#${i + 1}</span></td>
          <td><div class="c-main"><div class="emoji-box">${esc(a.art)}</div><div class="nm">${esc(a.store_name)}</div></div></td>
          <td>${esc(a.title)}</td>
          <td>${a.duration_days} يوم</td>
          <td>${moneySpan(a.price)}</td>
          <td class="muted">${a.ends_at ? new Date(a.ends_at).toLocaleDateString('ar-IQ') : '—'}</td>
          <td><div class="c-actions">
            ${i > 0 ? `<button class="btn btn-ghost btn-sm" onclick="adMove(${a.id},${i - 1})">▲ لأعلى</button>` : ''}
            <button class="btn btn-ghost btn-sm" onclick="adDecision(${a.id},'expired')">إيقاف</button>
          </div></td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">🖼</span>لا إعلانات نشطة — وافق على طلب أولاً</div>'}
    </div>

    <div class="card">
      <div class="card-title"><span>السجل</span></div>
      ${rest.length ? rest.map(a => `
        <div class="list-item glass" style="opacity:.75">
          <div class="lic">${esc(a.art)}</div>
          <div class="lt">
            <div class="a">${esc(a.store_name)} — ${esc(a.title)}</div>
            <div class="b">${moneySpan(a.price)} • ${a.duration_days} يوم</div>
            ${a.status === 'rejected' ? `<div class="b">↩️ الرصيد استرجع للتاجر${a.reject_reason ? ` — السبب: ${esc(a.reject_reason)}` : ''}</div>` : ''}
          </div>
          ${statusChip(a.status)}
        </div>`).join('') : '<div class="empty" style="padding:14px">لا سجل</div>'}
    </div>`;
}

async function adDecision(id, status) {
  await guard(async () => {
    const body = { status };
    if (status === 'rejected') {
      const reason = prompt('سبب الرفض (يوصله التاجر مع استرجاع الرصيد):') || '';
      body.reason = reason;
    }
    await API.patch(`/api/admin/ads/${id}`, body);
    toast(status === 'active' ? 'موافقة ✓ — صار يعرض بالرئيسية' : 'مرفوض — رجع الرصيد للتاجر');
    renderAds();
  });
}

async function adMove(id, newSort) {
  await guard(async () => {
    await API.patch(`/api/admin/ads/${id}`, { sort: newSort });
    toast('تغيّر الترتيب ✓');
    renderAds();
  });
}

