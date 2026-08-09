import { Router } from 'express';
import { auth, roles } from '../middleware.js';

// ── مسارات الطرق: يبحث عن المسار الحقيقي على الشوارع عبر OSRM ──
const r = Router();
r.use(auth, roles('customer', 'delivery', 'vendor'));

const cache = new Map();

function decimate(points, max = 240) {
  if (points.length <= max) return points;
  const step = (points.length - 1) / (max - 1);
  const out = [];
  for (let i = 0; i < max; i++) out.push(points[Math.round(i * step)]);
  return out;
}

const hav = (la1, lo1, la2, lo2) => {
  const r = 6371000, rad = 3.141592653589793 / 180;
  const p1 = la1 * rad, p2 = la2 * rad;
  const dp = (la2 - la1) * rad, dl = (lo2 - lo1) * rad;
  const h = (1 - Math.cos(dp)) / 2 + Math.cos(p1) * Math.cos(p2) * (1 - Math.cos(dl)) / 2;
  return r * 2 * Math.asin(Math.sqrt(h));
};

async function routeBetween(fla, flo, tla, tlo) {
  const key = `${fla.toFixed(4)},${flo.toFixed(4)};${tla.toFixed(4)},${tlo.toFixed(4)}`;
  const hit = cache.get(key);
  if (hit) return hit;
  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${flo},${fla};${tlo},${tla}?overview=full&geometries=geojson`;
    const resp = await fetch(url, { signal: AbortSignal.timeout(9000) });
    const data = await resp.json();
    if (data.code !== 'Ok' || !data.routes?.length) throw new Error('osrm-fail');
    const coords = data.routes[0].geometry.coordinates.map(([lo, la]) => ({ lat: la, lng: lo }));
    const result = {
      points: decimate(coords),
      distance: Math.round(data.routes[0].distance),
      duration: Math.round(data.routes[0].duration),
    };
    cache.set(key, result);
    return result;
  } catch {
    const result = { points: [{ lat: fla, lng: flo }, { lat: tla, lng: tlo }], distance: 0, duration: 0 };
    cache.set(key, result);
    return result;
  }
}

r.get('/route', async (req, res) => {
  const { from_lat, from_lng, to_lat, to_lng } = req.query;
  const fla = parseFloat(from_lat), flo = parseFloat(from_lng), tla = parseFloat(to_lat), tlo = parseFloat(to_lng);
  if ([fla, flo, tla, tlo].some(isNaN)) return res.status(400).json({ error: 'إحداثيات ناقصة' });
  const { points, distance, duration } = await routeBetween(fla, flo, tla, tlo);
  res.json({ points, distance, duration, direct: points.length === 2 && distance === 0 });
});

// ── مسار متعدد المحطات: يمر بأقرب المحلات أولاً ثم البيت ──
// from_lat/from_lng = موقع المندوب الحالي · stops = "lat,lng;lat,lng" · to_lat/to_lng = بيت الزبون
r.get('/multi-route', async (req, res) => {
  const { from_lat, from_lng, to_lat, to_lng, stops } = req.query;
  const fla = parseFloat(from_lat), flo = parseFloat(from_lng), tla = parseFloat(to_lat), tlo = parseFloat(to_lng);
  if ([fla, flo, tla, tlo].some(isNaN)) return res.status(400).json({ error: 'إحداثيات ناقصة' });
  const stopList = String(stops || '')
    .split(';')
    .map(s => s.split(',').map(parseFloat))
    .filter(p => p.length === 2 && !p.some(isNaN))
    .slice(0, 6);
  // ترتيب المحلات من الأقرب إلى الأبعد من نقطة الانطلاق (greedy)
  const order = [];
  let cur = { lat: fla, lng: flo };
  const rest = stopList.map(([lat, lng]) => ({ lat, lng }));
  while (rest.length) {
    let bi = 0, bd = Infinity;
    for (let i = 0; i < rest.length; i++) {
      const d = hav(cur.lat, cur.lng, rest[i].lat, rest[i].lng);
      if (d < bd) { bd = d; bi = i; }
    }
    order.push(rest.splice(bi, 1)[0]);
    cur = order[order.length - 1];
  }
  // سلسلة النقاط: من → المحلات بالترتيب → البيت
  const chain = [{ lat: fla, lng: flo }, ...order, { lat: tla, lng: tlo }];
  let points = [], distance = 0, duration = 0;
  for (let i = 0; i < chain.length - 1; i++) {
    const leg = await routeBetween(chain[i].lat, chain[i].lng, chain[i + 1].lat, chain[i + 1].lng);
    if (points.length) points.pop();
    points.push(...leg.points);
    distance += leg.distance;
    duration += leg.duration;
  }
  res.json({ points, distance, duration, stops_order: order.map(o => o.lat + ',' + o.lng) });
});

export default r;
