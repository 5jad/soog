/* ═══════════ الكاش والتحصيل ═══════════ */
async function renderCash() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const [d, weekData] = await Promise.all([
    API.get('/api/admin/cash'),
    API.get('/api/admin/stores-week'),
  ]);
  const pending = d.reports.filter(r => r.status === 'pending');
  const rest = d.reports.filter(r => r.status !== 'pending');
  const todayCollected = d.today_orders.filter(o => o.status === 'delivered').reduce((a, b) => a + b.total, 0);
  const todayPending   = d.today_orders.filter(o => o.status === 'delivering').reduce((a, b) => a + b.total, 0);

  el.innerHTML = `
    <div class="kpi-grid">
      <div class="kpi glass"><div class="kic">💵</div><div class="kn">${fmt(todayCollected)}</div><div class="kl">كاش محصّل اليوم</div><div class="kd up">+ من الطلبات المسلّمة</div></div>
      <div class="kpi glass"><div class="kic">🛵</div><div class="kn">${fmt(todayPending)}</div><div class="kl">كاش قيد التوصيل</div><div class="kd flat">— مع المندوبين</div></div>
      <div class="kpi glass"><div class="kic">🏦</div><div class="kn">${fmt(weekData.reduce((a,s) => a + s.commission_due, 0))}</div><div class="kl">عمولة المنصة هذا الأسبوع</div><div class="kd flat">من كل المحلات</div></div>
    </div>

    <!-- ═══ مستحقات المحلات هذا الأسبوع ═══ -->
    <div class="card">
      <div class="card-title"><span>📊 مستحقات المحلات — هذا الأسبوع</span><span class="more">آخر 7 أيام</span></div>
      ${weekData.length ? `<div class="table-wrap"><table class="tbl">
        <tr>
          <th>المحل</th>
          <th>إجمالي الطلبات</th>
          <th>المبلغ الكامل <span class="muted">(قبل العمولة)</span></th>
          <th>نسبة العمولة</th>
          <th>العمولة</th>
          <th style="color:var(--success)">مستحق التاجر <span class="muted">(بعد العمولة)</span></th>
          <th>إجراء</th>
        </tr>
        ${weekData.map(s => `<tr>
          <td><div class="c-main"><div class="emoji-box">${esc(s.logo)}</div><div class="nm">${esc(s.name)}</div></div></td>
          <td class="muted">${s.order_count} طلب</td>
          <td>${moneySpan(s.gross)}</td>
          <td><span style="background:var(--glass-l2);padding:3px 8px;border-radius:8px;font-weight:800">${s.commission_rate}%</span></td>
          <td style="color:var(--danger)">${moneySpan(s.commission_due)}</td>
          <td><b style="color:var(--success)">${moneySpan(s.net_due)}</b></td>
          <td>
            ${s.net_due > 0 
              ? `<button class="btn btn-danger btn-sm" onclick="payStore(${s.id}, '${esc(s.name)}', ${s.net_due})">مستحق</button>`
              : `<button class="btn btn-success btn-sm" style="opacity:0.6" disabled>تم التسليم ✓</button>`
            }
          </td>
        </tr>`).join('')}
        <tr style="background:var(--glass-l1);font-weight:900">
          <td colspan="2">المجموع</td>
          <td>${moneySpan(weekData.reduce((a,s) => a + s.gross, 0))}</td>
          <td>—</td>
          <td style="color:var(--danger)">${moneySpan(weekData.reduce((a,s) => a + s.commission_due, 0))}</td>
          <td style="color:var(--success)">${moneySpan(weekData.reduce((a,s) => a + s.net_due, 0))}</td>
          <td></td>
        </tr>
      </table></div>` : '<div class="empty"><span class="ic">📊</span>لا طلبات هذا الأسبوع</div>'}
    </div>

    <div class="card" style="border:2px solid var(--accent)">
      <div class="card-title"><span>⏳ تسليمات بانتظار تأكيدك</span><span class="more">${pending.length}</span></div>
      ${pending.length ? pending.map(r => `
        <div class="list-item glass">
          <div class="lic">💵</div>
          <div class="lt"><div class="a">المندوب ${esc(r.courier_name)}</div>
            <div class="b">محصّل: ${moneySpan(r.total_collected)} • أجر المندوب 5%: ${moneySpan(r.commission_amount)} • صافي المنصة: <b>${moneySpan(r.net)}</b></div>
          </div>
          <div class="actions">
            <button class="btn btn-success btn-sm" onclick="cashDecision(${r.id},'approved')">تأكيد ✓</button>
            <button class="btn btn-danger btn-sm" onclick="cashDecision(${r.id},'shortage')">نقصان</button>
          </div>
        </div>`).join('') : '<div class="empty" style="padding:14px"><span class="ic">✅</span>كلشي تأكد — لا تسليمات معلقة</div>'}
    </div>

    <div class="card">
      <div class="card-title"><span>طلبات اليوم — الجرد</span></div>
      ${d.today_orders.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>الطلب</th><th>المندوب</th><th>المبلغ</th><th>الحالة</th></tr>
        ${d.today_orders.map(o => `<tr>
          <td><span class="nm" style="direction:ltr">${esc(o.code)}</span></td>
          <td>${esc(o.courier_name || '—')}</td>
          <td>${moneySpan(o.total)}</td>
          <td>${statusChip(o.status)}</td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">💵</span>لا طلبات اليوم</div>'}
    </div>

    <div class="card">
      <div class="card-title"><span>تسليمات سابقة</span></div>
      ${rest.length ? rest.map(r => `
        <div class="list-item glass" style="opacity:.8">
          <div class="lic">🧾</div>
          <div class="lt"><div class="a">${esc(r.courier_name)} — ${r.receipt_no || 'إيصال'}</div><div class="b">${new Date(r.report_date).toLocaleDateString('ar-IQ')} • ${moneySpan(r.total_collected)}</div></div>
          ${statusChip(r.status)}
        </div>`).join('') : '<div class="empty" style="padding:14px">لا سجل سابق</div>'}
    </div>`;
}

async function payStore(id, name, amount) {
  if (amount <= 0) return toast('لا توجد مستحقات للتسليم', true);
  if (!confirm(`متأكد من تسليم ${fmt(amount)} د.ع إلى محل "${name}"؟\nهذا سيصفر حسابه الأسبوعي.`)) return;
  await guard(async () => {
    await API.post(`/api/admin/stores/${id}/pay`);
    toast('تم تصفير حساب المحل بنجاح وتخزين التسليم ✓');
    renderCash();
  });
}

async function cashDecision(id, status) {
  await guard(async () => {
    await API.patch(`/api/admin/cash/${id}`, { status });
    toast(status === 'approved' ? 'تأكد الكاش — وصدر الإيصال ✓' : 'سجّل النقصان ضد المندوب');
    renderCash();
  });
}
