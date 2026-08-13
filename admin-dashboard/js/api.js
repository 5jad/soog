/* ═══════════ API ═══════════ */
const here = location.origin || '';
const savedApi = localStorage.getItem('zaboon_api');
// إذا كان المحفوظ يشير لـ localhost لكن الصفحة مفتوحة على السحابة → تجاهله واستخدم موقع الصفحة نفسه
const staleLocal = savedApi === 'http://localhost:4000' && here && !/^http:\/\/(localhost|127\.0\.0\.1)/.test(here);
const API = {
  base: (staleLocal ? null : savedApi) || here || 'http://localhost:4000',
  token: () => localStorage.getItem('zaboon_token'),
  setToken: (t) => localStorage.setItem('zaboon_token', t),
  clear: () => { localStorage.removeItem('zaboon_token'); localStorage.removeItem('zaboon_admin'); },

  async req(method, path, body) {
    const headers = { 'Content-Type': 'application/json' };
    const t = this.token();
    if (t) headers['Authorization'] = 'Bearer ' + t;
    let res;
    try {
      res = await fetch(this.base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
    } catch {
      const err = new Error('السيرفر غير متصل — تأكد من الإنترنت أو شغّل السيرفر');
      err.network = true;
      throw err;
    }
    let data = null;
    try { data = await res.json(); } catch {}
    if (!res.ok) {
      if (res.status === 401 && path !== '/api/auth/verify') { showLogin(); }
      const err = new Error((data && data.error) || 'صارت مشكلة بالسيرفر');
      err.unauthorized = res.status === 401;
      throw err;
    }
    return data;
  },
  get: (p) => API.req('GET', p),
  post: (p, b) => API.req('POST', p, b),
  patch: (p, b) => API.req('PATCH', p, b),
  del: (p) => API.req('DELETE', p),
};
