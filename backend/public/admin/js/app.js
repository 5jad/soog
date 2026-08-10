/* ═══════════ التطبيق الرئيسي ═══════════ */
const router = {
  page: 'overview',
  async go(page) {
    if (!VIEWS[page]) page = 'overview';
    this.page = page;
    document.body.classList.remove('menu-open');
    document.getElementById('pageTitle').textContent = VIEWS[page].title;
    document.querySelectorAll('.menu-item').forEach(m => m.classList.toggle('active', m.dataset.page === page));
    await VIEWS[page].render();
  },
};

function showLogin() {
  document.getElementById('loginView').style.display = 'flex';
  document.getElementById('appView').style.display = 'none';
  API.clear();
}

function showApp() {
  document.getElementById('loginView').style.display = 'none';
  document.getElementById('appView').style.display = 'flex';
  const admin = JSON.parse(localStorage.getItem('zaboon_admin') || '{}');
  document.getElementById('adminName').textContent = admin.name || 'الأدمن';
}

async function buildMenu() {
  const menu = document.getElementById('menu');
  menu.innerHTML = Object.entries(VIEWS).map(([key, v]) =>
    `<div class="menu-item" data-page="${key}" onclick="router.go('${key}')"><span class="mi-ic">${v.icon}</span>${v.title.replace(/[^\u0600-\u06FF\s]/g, '').trim()}</div>`).join('');
  // إضافة رقم القرارات المعلقة لشريط القائمة
  const s = await API.get('/api/admin/stats').catch(() => null);
  const q = s && s.stats.queue;
  const total = q ? q.ads + q.docs + q.cash : 0;
  if (total) {
    const el = menu.querySelector('[data-page="overview"]');
    el.innerHTML += `<span class="mi-badge">${total}</span>`;
  }
}

(async function init() {
  document.getElementById('todayDate').textContent =
    new Date().toLocaleDateString('ar-IQ', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

  if (API.token()) {
    try {
      await API.get('/api/auth/me');
      showApp();
      await buildMenu();
      await router.go('overview');
      return;
    } catch { API.clear(); }
  }
  showLogin();
})();
