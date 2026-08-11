import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, useTitle } from '../ui';

export default function Notifications() {
  useTitle('الإشعارات');
  const { token, notify, setNotifN, setLoginOpen } = useApp();
  const nav = useNavigate();
  const [list, setList] = useState(null);

  useEffect(() => {
    if (!token) return;
    api('/api/customer/notifications').then(d => {
      setList(d.notifications || []);
      setNotifN(0);
    }).catch(() => setList([]));
  }, [token]);

  const open = async (n) => {
    try { await api('/api/customer/notifications/' + n.id + '/read', { method: 'POST' }); } catch (e) {}
    setList((l) => l.map(x => x.id === n.id ? { ...x, read_at: 1 } : x));
    if (n.type === 'order') nav('/orders/' + n.ref_id);
    else if (n.type === 'chat') nav('/chat');
    else if (n.url) nav(n.url);
  };

  const del = async (n) => {
    try {
      await api('/api/customer/notifications/' + n.id, { method: 'DELETE' });
      setList(l => l.filter(x => x.id !== n.id));
    } catch (e) { notify(e.message, 'err'); }
  };

  const markAll = async () => {
    try {
      await api('/api/customer/notifications/read-all', { method: 'POST' });
      setList(l => l.map(x => ({ ...x, read_at: 1 })));
      setNotifN(0);
    } catch (e) {}
  };

  if (!token) return <div className="sect"><Empty icon="🔐" msg="سجّل دخولك للإشعارات"
    action={<button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (!list) return <Loader />;

  return (
    <div className="sect" style={{ maxWidth: 600 }}>
      <div className="sect-head"><h2><span className="ln" />🔔 الإشعارات</h2>
        {list.some(n => !n.read_at) && <button className="btn btn-o btn-sm" onClick={markAll}>قراءة الكل</button>}</div>
      {!list.length && <Empty icon="🔕" msg="لا إشعارات — طلباتك وتتبعك سيظهر هنا" />}
      {list.map(n => (
        <div key={n.id} className={`card notif ${n.read_at ? '' : 'new'}`} onClick={() => open(n)} style={{ cursor: 'pointer' }}>
          <div className="notif-ic">{n.title.includes('طلب') ? '📦' : n.title.includes('نقطة') ? '🎁' : n.title.includes('محادثة') || n.title.includes('رسالة') ? '💬' : '✨'}</div>
          <div style={{ flex: 1 }}>
            <b style={{ fontSize: 13 }}>{n.title}</b>
            <div style={{ fontSize: 12, color: 'var(--muted)' }}>{n.body}</div>
            <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 3 }}>{timeAgo(n.created_at)}</div>
          </div>
          {!n.read_at && <span className="chat-badge"></span>}
          <button className="notif-x" onClick={(e) => { e.stopPropagation(); del(n); }}>✕</button>
        </div>
      ))}
    </div>
  );
}