/* طيران المنتج إلى أيقونة السلة — مثل التطبيق */
export function flyToCart(from, imgSrc) {
  const sink = document.getElementById('cartSink');
  if (!sink || !from) return;
  const to = sink.getBoundingClientRect();
  const el = document.createElement(imgSrc ? 'img' : 'span');
  el.className = 'fly';
  if (imgSrc) el.src = imgSrc;
  else el.textContent = '🛍️';
  const sx = from.left + from.width / 2;
  const sy = from.top + from.height / 2;
  el.style.left = (sx - 28) + 'px';
  el.style.top = (sy - 28) + 'px';
  document.body.appendChild(el);
  const dx = to.left + to.width / 2 - sx;
  const dy = to.top + to.height / 2 - sy;
  requestAnimationFrame(() => requestAnimationFrame(() => {
    el.style.transform = `translate(${dx}px, ${dy}px) scale(.12) rotate(-10deg)`;
    el.style.opacity = '.5';
  }));
  setTimeout(() => el.remove(), 680);
}

export const srcRectOf = (el) => {
  const card = el && el.closest ? el.closest('.pcard, .dcard') : null;
  const box = card ? card.querySelector('.pcard-img, .dcard-img') : null;
  return (box || el).getBoundingClientRect();
};