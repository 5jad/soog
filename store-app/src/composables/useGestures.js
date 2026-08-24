/* ═══ حركات التفاعل المركزية ═══
   - dragScroll: سحب بالماوس للشرائط الأفقية (اللمس يتعامل native)
   - pullRefresh: سحب للأسفل بأعلى الصفحة → تحديث (موبايل)
   - swipeTabs: سحب أفقي يبدّل تبويبات اللوحات
   - dismissDrag: سحب للأسفل يغلق الدروار/النافذة (مثل الموبايل) */

const isTouch = () => window.matchMedia?.('(pointer: coarse)')?.matches;

/* ═══ سحب الشريط الأفقي بالماوس + كتم النقر بعد السحب ═══ */
export const bindDragScroll = (el) => {
  if (!el) return;
  let down = false, moved = false, startX = 0, startLeft = 0;
  const onDown = (e) => {
    if (e.pointerType !== 'mouse' || e.button !== 0) return;
    down = true; moved = false;
    startX = e.clientX; startLeft = el.scrollLeft;
    el.style.cursor = 'grabbing';
    el.setPointerCapture?.(e.pointerId);
  };
  const onMove = (e) => {
    if (!down) return;
    const dx = e.clientX - startX;
    if (Math.abs(dx) > 5) { moved = true; el.scrollLeft = startLeft - dx; }
  };
  const onUp = () => {
    if (!down) return;
    down = false; el.style.cursor = '';
  };
  const onClick = (e) => { if (moved) { e.preventDefault(); e.stopPropagation(); moved = false; } };
  el.addEventListener('pointerdown', onDown);
  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerup', onUp);
  el.addEventListener('pointercancel', onUp);
  el.addEventListener('click', onClick, true);
  return () => {
    el.removeEventListener('pointerdown', onDown);
    el.removeEventListener('pointermove', onMove);
    el.removeEventListener('pointerup', onUp);
    el.removeEventListener('pointercancel', onUp);
    el.removeEventListener('click', onClick, true);
  };
};

/* ═══ سحب للأسفل → تحديث (أعلى الصفحة فقط، موبايل) ═══ */
export const usePullRefresh = (onRefresh) => {
  let startY = 0, pulling = false, over = false;
  let bar = null;
  const THRESHOLD = 72;
  const elFactory = () => {
    bar = document.createElement('div');
    bar.style.cssText = 'position:fixed;inset-block-start:0;inset-inline:0;display:flex;justify-content:center;z-index:60;pointer-events:none;transform:translateY(-100%);transition:transform .9s var(--ease-spring,-webkit-cubic-bezier(.34,1.3,.64,1));';
    bar.innerHTML = '<div style="background:var(--surface,#fff);border:1px solid var(--line,rgba(0,0,0,.08));border-radius:999px;box-shadow:0 6px 18px rgba(0,0,0,.12);display:flex;align-items:center;gap:8px;padding:7px 14px;font-size:12.5px;font-weight:700;color:var(--muted,#666)"><span class="msm" style="display:inline-block">refresh</span><span>اسحب لتحديث</span></div>';
    document.body.appendChild(bar);
  };
  const show = (v) => { bar.style.transform = v ? 'translateY(8px)' : 'translateY(-100%)'; };
  const onTouchStart = (e) => { if (window.scrollY <= 0 && e.touches[0]) { startY = e.touches[0].clientY; pulling = true; over = false; if (!bar) elFactory(); } };
  const onTouchMove = (e) => {
    if (!pulling) return;
    const dy = e.touches[0].clientY - startY;
    if (dy > 0 && window.scrollY <= 0) {
      const v = Math.min(dy, 110);
      bar.style.transform = `translateY(${v + 8}px)`;
      over = dy > THRESHOLD;
    }
  };
  const onTouchEnd = () => {
    if (!pulling) return;
    pulling = false;
    if (over) { show(false); onRefresh?.(); }
    else show(false);
  };
  window.addEventListener('touchstart', onTouchStart, { passive: true });
  window.addEventListener('touchmove', onTouchMove, { passive: true });
  window.addEventListener('touchend', onTouchEnd, { passive: true });
  return () => {
    window.removeEventListener('touchstart', onTouchStart);
    window.removeEventListener('touchmove', onTouchMove);
    window.removeEventListener('touchend', onTouchEnd);
    bar?.remove();
  };
};

/* ═══ سحب أفقي يبدّل التبويب (يمين/يسار) ═══ */
export const bindSwipeTabs = (el, { onPrev, onNext }) => {
  if (!el || isTouch()) return;   /* اللمس: مساحات السحب السفلية أفضل — الماوس يجرّب سريع */
  let sx = 0, sy = 0, active = false;
  const onDown = (e) => { if (e.pointerType !== 'mouse') return; sx = e.clientX; sy = e.clientY; active = true; };
  const onUp = (e) => {
    if (!active) return;
    active = false;
    const dx = e.clientX - sx, dy = e.clientY - sy;
    if (Math.abs(dx) > 80 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      (dx < 0 ? onNext : onPrev)?.();
    }
  };
  el.addEventListener('pointerdown', onDown);
  el.addEventListener('pointerup', onUp);
  return () => { el.removeEventListener('pointerdown', onDown); el.removeEventListener('pointerup', onUp); };
};

/* ═══ سحب للأسفل يغلق الدروار/النافذة — مع حركة حية ═══ */
export const bindDismissDrag = (el, { onClose, distance = 110 }) => {
  if (!el) return;
  let sy = 0, active = false, moved = false;
  const onDown = (e) => {
    if (e.pointerType !== 'touch') return;
    sy = e.clientY; active = true; moved = false;
  };
  const onMove = (e) => {
    if (!active || e.pointerType !== 'touch') return;
    const dy = e.clientY - sy;
    if (dy > 0) {
      moved = true;
      const v = Math.min(dy, 260);
      el.style.transform = `translateY(${v}px)`;
      el.style.transition = 'none';
      el.style.opacity = String(1 - v / 500);
    }
  };
  const onUp = (e) => {
    if (!active) return;
    active = false;
    const dy = e.clientY - sy;
    el.style.transition = '';
    if (dy > distance) { el.style.transform = ''; el.style.opacity = ''; onClose?.(); return; }
    el.style.transform = ''; el.style.opacity = '';
  };
  el.addEventListener('pointerdown', onDown);
  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerup', onUp);
  el.addEventListener('pointercancel', onUp);
  return () => { el.removeEventListener('pointerdown', onDown); el.removeEventListener('pointermove', onMove); el.removeEventListener('pointerup', onUp); el.removeEventListener('pointercancel', onUp); };
};