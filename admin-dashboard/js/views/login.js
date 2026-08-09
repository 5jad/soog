/* ═══════════ الدخول ═══════════ */
async function doLogin() {
  const phone = document.getElementById('loginPhone').value.trim();
  const pass = document.getElementById('loginPass').value;
  const hint = document.getElementById('loginHint');
  const btn = document.getElementById('loginBtn');
  if (!phone || !pass) return toast('أدخل الرقم وكلمة السر', true);
  btn.disabled = true; btn.textContent = 'جاري الدخول...';
  try {
    const d = await API.post('/api/auth/login', { phone, password: pass });
    API.setToken(d.token);
    localStorage.setItem('zaboon_admin', JSON.stringify(d.user));
    showApp();
    await buildMenu();
    toast('أهلاً بيك 👑 ' + d.user.name);
    router.go('overview');
  } catch (e) {
    hint.textContent = e.message;
    toast(e.message, true);
  } finally {
    btn.disabled = false; btn.textContent = 'دخول 👑';
  }
}

function logout() {
  API.clear();
  showLogin();
}
