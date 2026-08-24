<script setup>
/* ═══ تتبع الطلب — خريطة Leaflet حية لموقع المندوب + شريط مراحل ═══ */
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useApp } from '../state';
import { api, st, fmtDate, S } from '../api';
import leaflet from 'leaflet';
import 'leaflet/dist/leaflet.css';

const route = useRoute();
const router = useRouter();
const { toast } = useApp();

const t = ref(null);
const loading = ref(true);
const mapEl = ref(null);
let map = null;
let courierMark = null;
let pathLine = null;
let groupMarks = [];
let timer = null;

const STEPS = ['new', 'pending', 'ready', 'delivering', 'delivered'];

const load = async (withMap = false) => {
  try {
    const d = await api(`/api/customer/orders/${route.params.id}/track`);
    t.value = d.tracking;
    if (!map) initMap();
    updateMap();
  } catch (e) { toast(e.message, false); }
  loading.value = false;
};

const initMap = () => {
  if (map || !mapEl.value) return;
  map = leaflet.map(mapEl.value, { zoomControl: true, attributionControl: false }).setView([32.5, 45.5], 11);
  leaflet.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(map);
};

const updateMap = () => {
  if (!t.value || !map) return;
  const pts = [];
  // المندوب
  if (t.value.courier_lat && t.value.courier_lng) {
    pts.push({ lat: +t.value.courier_lat, lng: +t.value.courier_lng });
    if (!courierMark) {
      const div = leaflet.divIcon({ className: 'mark-courier', html: '<span>🛵</span>', iconSize: [40, 40] });
      courierMark = leaflet.marker([+t.value.courier_lat, +t.value.courier_lng], { icon: div }).addTo(map);
    } else courierMark.setLatLng([+t.value.courier_lat, +t.value.courier_lng]);
  }
  // المحلات (المجموعة)
  const stores = t.value.group_stores?.length ? t.value.group_stores : [{ name: t.value.store_name, lat: t.value.store_lat, lng: t.value.store_lng }];
  groupMarks.forEach((m) => m.remove());
  groupMarks = [];
  for (const s of stores) {
    if (s.lat && s.lng) {
      pts.push({ lat: +s.lat, lng: +s.lng });
      const m = leaflet.marker([+s.lat, +s.lng]).addTo(map).bindPopup(s.name);
      groupMarks.push(m);
    }
  }
  // موقع الزبون
  if (t.value.user_lat && t.value.user_lng) {
    pts.push({ lat: +t.value.user_lat, lng: +t.value.user_lng });
    const div = leaflet.divIcon({ className: 'mark-user', html: '<span>📍</span>', iconSize: [30, 30] });
    leaflet.marker([+t.value.user_lat, +t.value.user_lng], { icon: div }).addTo(map);
  }
  // المسار المسجل
  if (pathLine) { pathLine.remove(); pathLine = null; }
  if (t.value.path?.length > 1) {
    pathLine = leaflet.polyline(t.value.path.map((p) => [p.lat, p.lng]), { color: '#D45B8A', weight: 4, opacity: .7 }).addTo(map);
    pts.push(...t.value.path.map((p) => [p.lat, p.lng]));
  }
  if (pts.length) map.fitBounds(pts, { padding: [50, 50] });
};

const startPoll = () => {
  timer = setInterval(() => load(false), 8000);
};
onMounted(() => { load(true); startPoll(); });
onBeforeUnmount(() => { if (timer) clearInterval(timer); if (map) { map.remove(); map = null; } });

const stepIdx = () => {
  const i = STEPS.indexOf(t.value?.status);
  return i === -1 ? 0 : i;
};
</script>

<template>
  <div class="container-narrow">
    <div class="page-head">
      <button class="btn btn-ghost btn-sm" style="margin-block-end:var(--sp-2)" @click="router.push(`/orders/${route.params.id}`)">
        <span class="msm">arrow_forward</span> رجوع للطلب
      </button>
      <h1>تتبع الطلب <span class="num">{{ t?.code }}</span></h1>
    </div>

    <div v-if="loading" class="loader-block"><div class="loader"></div></div>

    <div v-else-if="t" class="flex-col gap-4" style="max-width:860px">
      <!-- شريط المراحل -->
      <section class="panel panel-pad">
        <div class="track-rail">
          <div v-for="(step, i) in ['new','pending','ready','delivering','delivered']" :key="step" class="track-step" :class="{ done: i < stepIdx(), current: i === stepIdx() }">
            <span class="dot"><span class="msm">{{ ['note_add','cooking','package_2','directions_bike','home'][i] }}</span></span>
            <span>{{ ['استلام الطلب','قيد التحضير','جاهز','بالتوصيل','تم التسليم'][i] }}</span>
          </div>
        </div>
        <div class="flex between gap-3 wrap">
          <div>
            <b v-if="t.courier_name">{{ t.courier_name }}</b><span v-else class="text-muted text-sm">المندوب يجهز الطلب</span>
            <p class="text-xs text-muted" style="margin-block-start:2px">
              {{ t.location_updated_at ? 'آخر تحديث للموقع: ' + fmtDate(t.location_updated_at) : (t.status === 'delivering' ? 'بانتظار إرسال الموقع…' : 'سيتحرك المندوب حال جاهزية طلبك') }}
            </p>
          </div>
          <span class="st-pill" :class="st(t.status)[1]"><span class="dot"></span>{{ st(t.status)[0] }}</span>
        </div>
      </section>

      <!-- الخريطة -->
      <section class="panel" style="overflow:hidden">
        <div ref="mapEl" style="height:420px;background:var(--bg-map)"></div>
        <div class="panel-pad" style="border-block-start:1px solid var(--line)">
          <div class="flex gap-3 wrap" style="font-size:var(--fs-xs);color:var(--muted)">
            <span>🛵 المندوب</span>
            <span v-if="t.store_name">🏪 {{ t.store_name }}</span>
            <span v-for="s in t.group_stores" :key="s.id">🏪 {{ s.name }}</span>
            <span>📍 موقعك</span>
            <span style="margin-inline-start:auto" class="num">العدّاد يحدث كل 8 ثوانٍ</span>
          </div>
        </div>
      </section>
    </div>

    <div v-else class="empty">
      <span class="msm">route</span>
      <h3>لا يوجد تتبع لهذا الطلب</h3>
      <button class="btn btn-primary btn-md" @click="router.push('/orders')">طلباتي</button>
    </div>
  </div>
</template>

<style>
.mark-courier span, .mark-user span { font-size: 30px; filter: drop-shadow(0 2px 4px rgba(0,0,0,.3)); }
.leaflet-container { font-family: var(--f-ui); border-radius: var(--r-lg); }
</style>