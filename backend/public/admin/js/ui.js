/* ═══════════ أدوات الواجهة ═══════════ */
function toast(msg, err = false) {
  const wrap = document.getElementById('toastWrap');
  const t = document.createElement('div');
  t.className = 'toast' + (err ? ' err' : '');
  t.textContent = msg;
  wrap.appendChild(t);
  setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity .3s'; setTimeout(() => t.remove(), 300); }, 2600);
}

const fmt = (n) => Number(n || 0).toLocaleString('en-US');
const fmtMoney = (n) => fmt(n) + ' د.ع';
const moneySpan = (n) => `<span class="money">${fmt(n)}</span>`;

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// تمرير النص داخل خصائص onclick — يهرب باك سلاش واقتباسات JS أولاً ثم HTML
// esc() وحده لا يكفي لأن المتصفح يفك entities قبل تنفيذ JS فيكسر السلسلة
function jsStr(s) {
  return String(s ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/"/g, '&quot;').replace(/&/g, '&amp;');
}

function statusChip(st) {
  const map = {
    new: ['جديد', 'st-new'], preparing: ['قيد التجهيز', 'st-preparing'], ready: ['جاهز', 'st-ready'],
    delivering: ['مع المندوب', 'st-delivering'], delivered: ['تم التسليم', 'st-delivered'],
    cancelled: ['ملغي', 'st-cancelled'], returned: ['مرتجع', 'st-cancelled'],
    pending: ['قيد المراجعة', 'st-pending'], approved: ['مقبول', 'st-approved'],
    rejected: ['مرفوض', 'st-rejected'], suspended: ['موقوف', 'st-suspended'],
    active: ['نشط', 'st-active'], expired: ['منتهي', 'st-expired'],
  };
  const [label, cls] = map[st] || [st, 'st-pending'];
  return `<span class="status ${cls}"><span class="dot"></span>${label}</span>`;
}

function timeAgo(d) {
  if (!d) return '';
  const s = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
  if (s < 60) return 'هسه';
  if (s < 3600) return `قبل ${Math.floor(s / 60)} دقيقة`;
  if (s < 86400) return `قبل ${Math.floor(s / 3600)} ساعة`;
  return `قبل ${Math.floor(s / 86400)} يوم`;
}

function openModal(html) {
  const m = document.createElement('div');
  m.className = 'overlay show';
  m.innerHTML = `<div class="modal">${html}</div>`;
  m.addEventListener('click', (e) => { if (e.target === m) m.remove(); });
  document.body.appendChild(m);
  return m;
}

function closeModal() { document.querySelector('.overlay.show')?.remove(); }

async function guard(fn) {
  try { await fn(); } catch (e) { toast(e.message, true); }
}
