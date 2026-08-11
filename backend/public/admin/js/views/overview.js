/* ═══════════ نظرة عامة ═══════════ */
const VIEWS = {
  overview: { title: 'نظرة عامة 📊', icon: '📊', render: () => renderOverview() },
  stores: { title: 'المحلات 🏪', icon: '🏪', render: () => renderStores() },
  orders: { title: 'الطلبات 🧾', icon: '🧾', render: () => renderOrders() },
  ads: { title: 'الإعلانات 🖼', icon: '🖼', render: () => renderAds() },
  cash: { title: 'الكاش والتحصيل 💵', icon: '💵', render: () => renderCash() },
  users: { title: 'المستخدمون 👥', icon: '👥', render: () => renderUsers() },
  geo: { title: 'المحافظات والأحياء 🗺', icon: '🗺', render: () => renderGeo() },
  notify: { title: 'الإشعارات الجماعية 🔔', icon: '🔔', render: () => renderNotify() },
  settings: { title: 'الإعدادات ⚙️', icon: '⚙️', render: () => renderSettings() },
  coupons: { title: 'الكوبونات 🏷', icon: '🏷', render: () => renderCoupons() },
  reviews: { title: 'التقييمات ⭐', icon: '⭐', render: () => renderReviews() },
  refunds: { title: 'الإرجاعات 🔄', icon: '🔄', render: () => renderRefunds() },
  audit: { title: 'سجل العمليات 🕵️', icon: '🕵️', render: () => renderAudit() },
};

async function renderOverview() {
  const el = document.getElementById('content');
  el.innerHTML = '<div class="skel"></div><div class="skel"></div><div class="skel"></div>';
  const [s, sales] = await Promise.all([API.get('/api/admin/stats'), API.get('/api/admin/sales')]);
  const st = s.stats, q = st.queue;

  const queueItems = [];
  if (q.ads) queueItems.push({ ic: '🖼', t: `طلبات إعلان (${q.ads})`, b: 'بانتظار موافقتك', to: 'ads' });
  if (q.docs) queueItems.push({ ic: '📄', t: `مستندات توثيق (${q.docs})`, b: 'محلات قيد المراجعة', to: 'stores' });
  if (q.cash) queueItems.push({ ic: '💵', t: `تسليم كاش (${q.cash})`, b: 'مباشرة المندوبين', to: 'cash' });

  const max = Math.max(...sales.days.map(d => d.total), 1);
  const today = sales.days[sales.days.length - 1];
  const goal = await API.get('/api/admin/settings').then(d => d.settings.daily_goal || '5000000');

  const catMax = Math.max(...sales.categories.map(c => c.total), 1);

  el.innerHTML = `
    <div class="kpi-grid">
      <div class="kpi glass clickable" onclick="router.go('orders')">
        <div class="kic">🧾</div><div class="kn">${st.orders_today}</div><div class="kl">طلبات اليوم</div>
        <div class="kd up">${st.new_orders} جديدة 🔔</div>
      </div>
      <div class="kpi glass clickable" onclick="router.go('orders')">
        <div class="kic">💰</div><div class="kn">${fmt(st.sales_today)}</div><div class="kl">مبيعات اليوم د.ع</div>
        <div class="kd flat">المجموع الخام ${fmt(st.gross_today)}</div>
      </div>
      <div class="kpi glass">
        <div class="kic">🏦</div><div class="kn">${fmt(st.commission_today)}</div><div class="kl">عمولة المنصة (10%)</div>
        <div class="kd flat">— تلقائي</div>
      </div>
      <div class="kpi glass clickable" onclick="router.go('stores')">
        <div class="kic">🏪</div><div class="kn">${st.active_stores}</div><div class="kl">محل نشط</div>
        <div class="kd flat">${q.docs} قيد التوثيق</div>
      </div>
      <div class="kpi glass clickable" onclick="router.go('users')">
        <div class="kic">👥</div><div class="kn">${st.new_customers}</div><div class="kl">زبون جديد اليوم</div>
        <div class="kd flat">${st.total_customers} زبون إجمالاً</div>
      </div>
      <div class="kpi glass clickable" onclick="router.go('users')">
        <div class="kic">🛵</div><div class="kn">${st.couriers}</div><div class="kl">مندوب مسجل</div>
        <div class="kd flat">— كلشي تمام</div>
      </div>
    </div>

    <div class="grid2-1">
      <div class="card">
        <div class="card-title"><span>المبيعات — آخر 7 أيام</span><span class="more">بالمليون د.ع</span></div>
        <div class="chart" id="chart7">${sales.days.map((d, i) => {
          const isT = i === sales.days.length - 1;
          const h = Math.max(5, d.total / max * 100);
          return `<div class="bar${isT ? ' today' : ''}" style="height:${h}%"><span class="val">${(d.total / 1000000).toFixed(1)}M</span></div>`;
        }).join('')}</div>
        <div class="chart-lbls">${sales.days.map((d, i) => {
          const n = new Date(d.date + 'T00:00:00');
          const names = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
          return `<span class="${i === sales.days.length - 1 ? 'today' : ''}">${i === sales.days.length - 1 ? 'اليوم' : names[n.getDay()]}</span>`;
        }).join('')}</div>
      </div>

      <div class="card">
        <div class="card-title"><span>🎯 هدف اليوم</span><span class="more" style="color:var(--success)">${Math.min(100, Math.round(today.total / goal * 100))}%</span></div>
        <div style="height:10px;border-radius:99px;background:var(--glass-l3);overflow:hidden">
          <div style="height:100%;width:${Math.min(100, Math.round(today.total / goal * 100))}%;border-radius:99px;background:linear-gradient(90deg,var(--primary),var(--cyan));transition:width 1.2s var(--ease)"></div>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10.5px;color:var(--muted);font-weight:700;margin-top:8px">
          <span>${fmt(today.total)} من ${fmt(goal)} د.ع</span><span>باقي ${fmt(Math.max(0, goal - today.total))}</span>
        </div>
        <div class="card-title" style="margin-top:18px"><span>محتاج قرارك ⚠️</span><span class="more" id="qCount">${queueItems.length}</span></div>
        ${queueItems.length ? queueItems.map(qi => `
          <div class="list-item glass" style="cursor:pointer" onclick="router.go('${qi.to}')">
            <div class="lic">${qi.ic}</div>
            <div class="lt"><div class="a">${qi.t}</div><div class="b">${qi.b}</div></div>
            <span style="color:var(--primary);font-weight:900;font-size:11px">افتح ←</span>
          </div>`).join('') : `<div class="empty" style="padding:16px"><span class="ic">🎉</span>ماكو شي معلق — كلشي مصفى يا معلم</div>`}
      </div>
    </div>

    <div class="grid2">
      <div class="card">
        <div class="card-title"><span>المبيعات حسب القسم</span><span class="more">اليوم</span></div>
        ${sales.categories.length ? sales.categories.map(c => `
          <div class="cat-row"><span class="cn">${c.icon} ${c.name}</span><div class="ct"><div class="cf" style="width:${Math.max(3, c.total / catMax * 100)}%"></div></div><span class="cv">${fmt(c.total)}</span></div>
        `).join('') : '<div class="empty"><span class="ic">📊</span>لا مبيعات اليوم بعد</div>'}
      </div>

      <div class="card">
        <div class="card-title"><span>🏆 أفضل المحلات اليوم</span><span class="more">الترتيب</span></div>
        ${sales.top_stores.map((s, i) => `
          <div class="lb-row glass">
            <div class="rank">${i + 1}</div>
            <div class="lic">${s.logo}</div>
            <div class="lt"><div class="a">${esc(s.name)}</div><div class="b">عمولته: ${fmt(s.sales * s.commission_rate / 100)} د.ع</div></div>
            <div class="lv"><div class="a">${fmt(s.sales)}</div><div class="b" style="color:var(--muted)">مبيعات</div></div>
          </div>`).join('')}
      </div>
    </div>

    <div class="card">
      <div class="card-title"><span>آخر الطلبات</span><span class="more" onclick="router.go('orders')">كل الطلبات ←</span></div>
      ${s.recent.length ? `<div class="table-wrap"><table class="tbl">
        <tr><th>الطلب</th><th>المحل</th><th>الزبون</th><th>المبلغ</th><th>الحالة</th><th>الوقت</th></tr>
        ${s.recent.map(o => `<tr>
          <td><span class="nm" style="direction:ltr;display:inline-block">${esc(o.code)}</span></td>
          <td>${esc(o.store_name)}</td><td>${esc(o.user_name || '-')}</td>
          <td>${moneySpan(o.total)}</td><td>${statusChip(o.status)}</td><td class="muted">${timeAgo(o.created_at)}</td>
        </tr>`).join('')}
      </table></div>` : '<div class="empty"><span class="ic">🧾</span>ماكو طلبات بعد</div>'}
    </div>`;
}
