/* ═══════════ API ═══════════ */
const API = {
  base: localStorage.getItem('zaboon_api') || 'http://localhost:4000',
  token: () => localStorage.getItem('zaboon_token'),
  setToken: (t) => localStorage.setItem('zaboon_token', t),
  clear: () => { localStorage.removeItem('zaboon_token'); localStorage.removeItem('zaboon_admin'); },

  async req(method, path, body) {
    const headers = { 'Content-Type': 'application/json' };
    const t = this.token();
    if (t) headers['Authorization'] = 'Bearer ' + t;
    const res = await fetch(this.base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
    let data = null;
    try { data = await res.json(); } catch {}
    if (!res.ok) {
      if (res.status === 401 && path !== '/api/auth/verify') { showLogin(); }
      throw new Error((data && data.error) || 'صارت مشكلة بالسيرفر');
    }
    return data;
  },
  get: (p) => API.req('GET', p),
  post: (p, b) => API.req('POST', p, b),
  patch: (p, b) => API.req('PATCH', p, b),
  del: (p) => API.req('DELETE', p),
};
