import React, { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, timeAgo } from '../api';
import { useApp } from '../ctx';
import { Loader, Empty, M, useTitle } from '../ui';

export default function ChatList() {
  useTitle('المحادثات');
  const { token, notify, setLoginOpen } = useApp();
  const [sp, setSp] = useSearchParams();
  const [list, setList] = useState(null);
  const [cur, setCur] = useState(sp.get('id') ? +sp.get('id') : null);
  const [msgs, setMsgs] = useState(null);
  const [txt, setTxt] = useState('');
  const [peer, setPeer] = useState(null);
  const box = useRef(null);

  useEffect(() => {
    if (!token) return;
    api('/api/customer/conversations').then(d => setList(d.conversations || [])).catch(() => setList([]));
  }, [token]);

  useEffect(() => {
    if (!token || !cur) return;
    let live = true;
    const load = async () => {
      try {
        const d = await api('/api/customer/conversations/' + cur + '/messages');
        if (!live) return;
        setMsgs(d.messages || []);
        setPeer(d.conversation);
        if (d.conversation.courier_name) setCur(-1);
      } catch (e) { if (live) notify(e.message, 'err'); }
    };
    load();
    const iv = setInterval(load, 4000);
    return () => { live = false; clearInterval(iv); };
  }, [token, cur]);

  useEffect(() => { box.current && box.current.scrollTop && (box.current.scrollTop = box.current.scrollHeight); }, [msgs]);

  if (!token) return <div className="container section"><Empty icon="🔐" msg="سجّل دخولك للمحادثات"
    action={<button className="btn btn--navy" style={{ marginTop: 14 }} onClick={() => setLoginOpen(true)}>تسجيل الدخول</button>} /></div>;
  if (!list) return <Loader />;

  const send = async () => {
    const t = txt.trim();
    if (!t || !cur) return;
    setTxt('');
    try {
      const d = await api('/api/customer/conversations/' + cur + '/messages', { method: 'POST', body: JSON.stringify({ text: t }) });
      setMsgs([...(msgs || []), d.message]);
    } catch (e) { notify(e.message, 'err'); }
  };

  return (
    <div className="container section" style={{ maxWidth: 680, paddingBlockStart: 12 }}>
      <div className="sect-head"><h2><M n="chat" s={19} c="var(--primary)" /> المحادثات</h2></div>
      {!list.length && <Empty icon="💬" msg="لا توجد محادثات بعد — تظهر تلقائياً عند تتبع طلبك" />}
      {cur ? (
        <div className="card chat-box" style={{ marginBlockEnd: 0, display: 'flex', flexDirection: 'column', height: 'calc(100dvh - 210px)', minHeight: 420 }}>
          <div className="chat-hd">
            <button className="btn btn--outline btn--sm" onClick={() => { setCur(null); setMsgs(null); }}>← القائمة</button>
            <b style={{ fontSize: 14 }}>🛵 {peer && (peer.courier_name || 'المندوب')}</b>
          </div>
          <div className="chat-msgs" ref={box}>
            {(msgs || []).map(m => (
              <div key={m.id} className={`msg ${m.sender_role === 'customer' ? 'me' : 'them'}`}>
                <b>{m.sender_role === 'customer' ? 'أنت' : m.sender_name}</b>
                <div className="b">{m.body}</div>
                <span>{timeAgo(m.created_at)}</span>
              </div>
            ))}
            {!(msgs || []).length && <Empty icon="👋" msg="ابدأ الرسالة الأولى للمندوب" />}
          </div>
          <div className="chat-in">
            <input className="inp" placeholder="اكتب رسالتك…" value={txt} onChange={e => setTxt(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()} />
            <button className="btn btn--navy" onClick={send} aria-label="إرسال"><M n="send" s={16} /></button>
          </div>
        </div>
      ) : (
        list.map(c => (
          <div key={c.id} className="card cchat" onClick={() => setCur(c.id)}>
            <div className="cchat-ava">🛵</div>
            <div style={{ flex: 1 }}>
              <b style={{ fontSize: 14 }}>{c.name} <span style={{ fontSize: 11, color: 'var(--muted)' }}>• مندوب توصيل</span></b>
              <div style={{ fontSize: 12, color: 'var(--muted)' }}>{c.last_message || 'لا رسائل بعد'}</div>
            </div>
            {c.has_unread ? <span className="chat-badge"></span> : null}
          </div>
        ))
      )}
    </div>
  );
}