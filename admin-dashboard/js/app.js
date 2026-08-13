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

/* ═══ القائمة الجانبية — مجموعات مرتّبة ═══ */
const MENU_GROUPS = [
  { label: 'الرئيسية', items: [['overview', '📊', 'نظرة عامة']] },
  { label: 'العمليات', items: [
    ['orders', '🧾', 'الطلبات'],
    ['cash', '💵', 'الكاش والتحصيل'],
    ['ads', '🖼', 'الإعلانات'],
  ] },
  { label: 'التجار والمحتوى', items: [
    ['stores', '🏪', 'المحلات'],
    ['geo', '🗺', 'المحافظات والأحياء'],
  ] },
  { label: 'المجتمع', items: [
    ['users', '👥', 'المستخدمون'],
    ['notify', '🔔', 'الإشعارات الجماعية'],
  ] },
  { label: 'النظام', items: [
    ['settings', '⚙️', 'الإعدادات'],
    ['audit', '🕵️', 'سجل العمليات'],
  ] },
];

/* ═══ الوضع الليلي/النهاري ═══ */
function currentTheme() {
  return document.documentElement.getAttribute('data-theme') === 'dark';
}
function applyTheme(dark) {
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : '');
  try { localStorage.setItem('zaboon_theme', dark ? 'dark' : 'light'); } catch (e) {}
  const b = document.getElementById('themeBtn');
  if (b) b.textContent = dark ? '☀️' : '🌙';
}
function toggleTheme() { applyTheme(!currentTheme()); }

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
  applyTheme(currentTheme());
}

function badgeOn(page, count) {
  const el = document.querySelector(`.menu-item[data-page="${page}"]`);
  if (el && count > 0) el.innerHTML += `<span class="mi-badge">${count}</span>`;
}

async function buildMenu() {
  const menu = document.getElementById('menu');
  menu.innerHTML = MENU_GROUPS.map(g => `
    <div class="menu-sec">${g.label}</div>
    ${g.items.map(([key, icon, label]) => `
      <div class="menu-item" data-page="${key}" onclick="router.go('${key}')">
        <span class="mi-ic">${icon}</span>${label}
      </div>`).join('')}
  `).join('');
  // شارات المعلقات على عناصرها + مجموعها على نظرة عامة
  const s = await API.get('/api/admin/stats').catch(() => null);
  const q = s && s.stats.queue;
  if (q) {
    badgeOn('ads', q.ads);
    badgeOn('stores', q.docs);
    badgeOn('cash', q.cash);
    const total = q.ads + q.docs + q.cash;
    if (total) badgeOn('overview', total);
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
    } catch (e) {
      // فقط رمز فعلاً مرفوض يمسح الجلسة — انقطاع الشبكة يبقيها محفوظة
      if (e && e.unauthorized) API.clear();
    }
  }
  showLogin();
})();
