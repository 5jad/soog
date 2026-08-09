/* ═══════════ سجل العمليات ═══════════ */
async function renderAudit() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div>';
  const d = await API.get('/api/admin/audit');
  el.innerHTML = `
    <div class="card">
      <div class="card-title"><span>🕵️ سجل العمليات</span><span class="more">آخر ${d.logs.length}</span></div>
      ${d.logs.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>الوقت</th><th>الأدمن</th><th>الإجراء</th><th>الكيان</th><th>التفاصيل</th></tr>
        ${d.logs.map(l => `<tr>
          <td class="muted">${timeAgo(l.created_at)}</td>
          <td>${esc(l.admin_name || '-')}</td>
          <td><span class="chip" style="cursor:default">${esc(l.action)}</span></td>
          <td class="muted">${esc(l.entity || '-')} ${l.entity_id ? '#' + l.entity_id : ''}</td>
          <td class="muted" style="font-size:11px;max-width:320px;line-height:1.6">
            ${l.new_data ? Object.entries(l.new_data).map(([k,v]) => `<span style="background:var(--glass-l2);padding:2px 6px;border-radius:4px;margin:2px;display:inline-block"><b>${k}:</b> ${v}</span>`).join('') : ''}
          </td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">🕵️</span>لا عمليات بعد</div>'}
    </div>`;
}
