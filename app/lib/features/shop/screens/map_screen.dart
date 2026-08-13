import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

const LatLng _kut = LatLng(32.5056, 45.8249);

TileLayer mapTiles() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.zaboon.zaboon',
  maxZoom: 19,
);

double _hav(LatLng a, LatLng b) {
  const r = 6371000.0;
  final p1 = a.latitude * 3.141592653589793 / 180,
      p2 = b.latitude * 3.141592653589793 / 180;
  final dp = (b.latitude - a.latitude) * 3.141592653589793 / 180;
  final dl = (b.longitude - a.longitude) * 3.141592653589793 / 180;
  final h = (1 - cos(dp)) / 2 + cos(p1) * cos(p2) * (1 - cos(dl)) / 2;
  return r * 2 * asin(sqrt(h));
}

Future<List<LatLng>> _fetchPlan(LatLng from, LatLng to) async {
  try {
    final d = await Api.get(
      '/api/routing/route?from_lat=${from.latitude}&from_lng=${from.longitude}&to_lat=${to.latitude}&to_lng=${to.longitude}',
    );
    final pts = d['points'] as List? ?? [];
    return [
      for (final p in pts)
        LatLng(
          ((p as Map)['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        ),
    ];
  } catch (_) {
    return [];
  }
}

// مسار يمر بأقرب المحلات أولاً ثم بيت الزبون (طلب من أكثر من محل)
Future<({List<LatLng> pts, double km, double min})> _fetchMultiPlan(
  LatLng from,
  List<LatLng> stops,
  LatLng to,
) async {
  try {
    final stopsStr = stops.map((s) => '${s.latitude},${s.longitude}').join(';');
    final d = await Api.get(
      '/api/routing/multi-route?from_lat=${from.latitude}&from_lng=${from.longitude}&to_lat=${to.latitude}&to_lng=${to.longitude}&stops=$stopsStr',
    );
    final pts = d['points'] as List? ?? [];
    final out = <LatLng>[
      for (final p in pts)
        LatLng(
          ((p as Map)['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        ),
    ];
    return (
      pts: out,
      km: ((d['distance'] as num?) ?? 0) / 1000,
      min: ((d['duration'] as num?) ?? 0) / 60,
    );
  } catch (_) {
    return (pts: <LatLng>[], km: 0.0, min: 0.0);
  }
}

// محلات الطلب المتعدد (من orders أو group_stores) — بإحداثيات فقط
List<LatLng> _storesOf(Map tr, {String listKey = 'orders'}) {
  final out = <LatLng>[];
  for (final o in (tr[listKey] as List? ?? [])) {
    final m = o as Map;
    final la = m['lat'] ?? m['store_lat'];
    final ln = m['lng'] ?? m['store_lng'];
    if (la is num && ln is num) out.add(LatLng(la.toDouble(), ln.toDouble()));
  }
  return out;
}

String shortName(String? s) {
  if (s == null || s.isEmpty) return 'محل';
  final t = s.replaceAll(' — ', ' ');
  return t.length <= 12 ? t : '${t.substring(0, 12)}…';
}

String _fmtMin(double m) => m < 1
    ? '${(m * 60).round()} ثانية'
    : m >= 60
    ? '${m.floor()}س ${(m % 60).round()}د'
    : '${m.round()} دقيقة';

({double km, double min}) _eta(List<LatLng> plan, LatLng pos) {
  if (plan.isEmpty) return (km: 0, min: 0);
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < plan.length; i++) {
    final d = _hav(plan[i], pos);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  var rest = 0.0;
  for (var i = best; i < plan.length - 1; i++)
    rest += _hav(plan[i], plan[i + 1]);
  final km = rest / 1000;
  return (km: km, min: km / 25 * 60);
}

Widget mapPin(String emoji, Color bg, {double size = 42}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: bg,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white, width: 2.5),
    boxShadow: const [
      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
    ],
  ),
  child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
);

Marker mMaker(LatLng p, Widget child, {String? label}) => Marker(
  point: p,
  width: 60,
  height: 62,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      if (label != null)
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
    ],
  ),
);

Future<Position?> askGps() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever)
      return null;
    return await Geolocator.getCurrentPosition();
  } catch (_) {
    return null;
  }
}

class PickMapScreen extends StatefulWidget {
  final double? lat, lng;
  const PickMapScreen({super.key, this.lat, this.lng});

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  final _c = MapController();
  LatLng _pos = _kut;
  bool _moved = false;
  bool _centering = false;

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null)
      _pos = LatLng(widget.lat!, widget.lng!);
  }

  void _pick(LatLng p) {
    setState(() {
      _pos = p;
      _moved = true;
    });
  }

  Future<void> _centerOnMe() async {
    setState(() => _centering = true);
    final gps = await askGps();
    if (!mounted) return;
    if (gps != null) {
      setState(() => _pos = LatLng(gps.latitude, gps.longitude));
      _c.move(_pos, 16);
    } else {
      toast(
        context,
        'شغل الـ GPS أو اختر الموقع بالضغط على الخريطة',
        error: true,
      );
    }
    setState(() => _centering = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(Icons.my_location_rounded, 'تحديد الموقع على الخريطة'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _c,
            options: MapOptions(
              initialCenter: _pos,
              initialZoom: 14,
              onTap: (_, p) => _pick(p),
            ),
            children: [
              mapTiles(),
              MarkerLayer(
                markers: [
                  mMaker(
                    _pos,
                    mapPin('📍', AppColors.primary),
                    label: _moved ? null : 'موقعك',
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: FloatingActionButton.small(
              heroTag: 'center',
              backgroundColor: Colors.white,
              child: _centering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
              onPressed: _centering ? null : _centerOnMe,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'اضغط على أي نقطة بالخريطة لتحديد الموقع',
                    style: AppType.style(11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_pos.latitude.toStringAsFixed(5)} ، ${_pos.longitude.toStringAsFixed(5)}',
                    style: AppType.style(
                      16,
                      weight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SolidBtn(
                    label: 'حفظ هذا الموقع ✓',
                    onTap: () => Navigator.pop(context, _pos),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveTrackMapScreen extends StatefulWidget {
  final int orderId;
  const LiveTrackMapScreen({super.key, required this.orderId});

  @override
  State<LiveTrackMapScreen> createState() => _LiveTrackMapScreenState();
}

List<Widget> _routeOverlays(List<LatLng> pts, {required bool done}) {
  if (pts.length <= 1) return const [];
  return [
    PolylineLayer(
      polylines: [
        Polyline(
          points: pts,
          strokeWidth: done ? 5 : 3.5,
          color: done
              ? AppColors.primary.withValues(alpha: .85)
              : const Color(0xFF6B7280).withValues(alpha: .65),
          borderStrokeWidth: 1.2,
          borderColor: Colors.white70,
        ),
      ],
    ),
  ];
}

// أفضل مسار من موقع المندوب الحالي → المحلات المتبقية → البيت (يتبع المندوب)
Future<List<LatLng>> _remainderFrom(Map tr, LatLng from) async {
  final home = (tr['user_lat'] != null && tr['user_lng'] != null)
      ? LatLng(
          (tr['user_lat'] as num).toDouble(),
          (tr['user_lng'] as num).toDouble(),
        )
      : null;
  if (home == null) return [];
  final gs = _storesOf(tr, listKey: 'group_stores');
  final rest = [
    for (final s in gs)
      if (_hav(from, s) > 250) s,
  ];
  if (gs.isNotEmpty) {
    return (await _fetchMultiPlan(from, rest, home)).pts;
  }
  if (tr['store_lat'] != null) {
    return _fetchPlan(from, home);
  }
  return [];
}

// دمج المسار المسلوك فعلياً + أفضل مسار من الموقع الحالي
List<LatLng> _drawnFrom(
  Map tr,
  List<LatLng> path,
  List<LatLng> rem,
  List<LatLng> plan,
) {
  final done = tr['status'] == 'delivered';
  if (done && path.length > 1) return path;
  if (!done && path.isNotEmpty && rem.isNotEmpty) {
    final a = path.last, b = rem.first;
    if ((a.latitude - b.latitude).abs() < 1e-9 &&
        (a.longitude - b.longitude).abs() < 1e-9) {
      return [...path, ...rem.sublist(1)];
    }
    return [...path, ...rem];
  }
  return rem.isNotEmpty ? rem : plan;
}

List<LatLng> _pathFrom(Map tr) {
  final path = <LatLng>[];
  for (final p in (tr['path'] as List? ?? [])) {
    try {
      path.add(
        LatLng(
          ((p as Map)['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        ),
      );
    } catch (_) {}
  }
  return path;
}

class _LiveTrackMapScreenState extends State<LiveTrackMapScreen> {
  final _c = MapController();
  Timer? _t;
  Map<String, dynamic>? tr;
  List<LatLng> _plan = [];
  List<LatLng> _remain = [];
  List<LatLng> _drawn = [];
  LatLng? _lastRemPos;
  DateTime? _lastRemAt;
  bool _remBusy = false;
  bool loading = true;
  bool _fitted = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await Api.get('/api/customer/orders/${widget.orderId}/track');
      final nt = d['tracking'];
      if (nt == null) return;
      final data = nt as Map<String, dynamic>;
      if (mounted)
        setState(() {
          tr = data;
          loading = false;
        });
      if (_plan.isEmpty &&
          data['user_lat'] != null &&
          data['user_lng'] != null) {
        final home = LatLng(
          (data['user_lat'] as num).toDouble(),
          (data['user_lng'] as num).toDouble(),
        );
        // طلب من أكثر من محل: مسار واحد يمر بكل المحلات ثم بيتي
        final gs = _storesOf(data, listKey: 'group_stores');
        if (gs.isNotEmpty &&
            data['courier_lat'] != null &&
            data['courier_lng'] != null) {
          final m = await _fetchMultiPlan(
            LatLng(
              (data['courier_lat'] as num).toDouble(),
              (data['courier_lng'] as num).toDouble(),
            ),
            gs,
            home,
          );
          if (mounted && m.pts.isNotEmpty) setState(() => _plan = m.pts);
        } else if (data['store_lat'] != null) {
          final plan = await _fetchPlan(
            LatLng(
              (data['store_lat'] as num).toDouble(),
              (data['store_lng'] as num).toDouble(),
            ),
            home,
          );
          if (mounted && plan.isNotEmpty) setState(() => _plan = plan);
        }
      }
      // المتبقي يعاد حسابه من موقع المندوب الحالي كلما تحرك أكثر من 200م (بحد أقصى مرة كل 10 ثواني)
      if (data['status'] != 'delivered' &&
          data['courier_lat'] != null &&
          data['courier_lng'] != null) {
        final cp = LatLng(
          (data['courier_lat'] as num).toDouble(),
          (data['courier_lng'] as num).toDouble(),
        );
        final moved = _lastRemPos == null || _hav(_lastRemPos!, cp) > 200;
        final cooled =
            _lastRemAt == null ||
            DateTime.now().difference(_lastRemAt!) >
                const Duration(seconds: 10);
        if (moved && cooled && !_remBusy) {
          _remBusy = true;
          final r = await _remainderFrom(data, cp);
          _remBusy = false;
          _lastRemAt = DateTime.now();
          if (r.isNotEmpty) {
            if (mounted) setState(() => _remain = r);
            _lastRemPos = cp;
          }
        }
      }
      final drawn = _drawnFrom(data, _pathFrom(data), _remain, _plan);
      if (mounted && drawn.isNotEmpty) setState(() => _drawn = drawn);
      if (!_fitted &&
          _mapReady &&
          data['courier_lat'] != null &&
          data['courier_lng'] != null) {
        _fitted = true;
        _fitAll(data);
      }
    } catch (_) {
      if (!silent && mounted) loading = false;
    }
  }

  void _fitAll(Map tr) {
    final pts = _pathFrom(tr);
    if (tr['courier_lat'] != null)
      pts.add(
        LatLng(
          (tr['courier_lat'] as num).toDouble(),
          (tr['courier_lng'] as num).toDouble(),
        ),
      );
    for (final s in _storesOf(tr, listKey: 'group_stores')) {
      pts.add(s);
    }
    if (tr['store_lat'] != null)
      pts.add(
        LatLng(
          (tr['store_lat'] as num).toDouble(),
          (tr['store_lng'] as num).toDouble(),
        ),
      );
    if (tr['user_lat'] != null && tr['user_lng'] != null)
      pts.add(
        LatLng(
          (tr['user_lat'] as num).toDouble(),
          (tr['user_lng'] as num).toDouble(),
        ),
      );
    if (pts.isEmpty) return;
    try {
      _c.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {
      _c.move(pts.first, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = this.tr;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr != null && tr['status'] == 'delivered'
              ? 'تم تسليم الطلب ✅'
              : 'تتبع المندوب حياً 🛵',
        ),
      ),
      body: loading && tr == null
          ? const Loader()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _c,
                  options: MapOptions(
                    initialCenter: _kut,
                    initialZoom: 13,
                    onMapReady: () {
                      _mapReady = true;
                      if (tr != null &&
                          !_fitted &&
                          tr!['courier_lat'] != null &&
                          tr!['courier_lng'] != null) {
                        _fitted = true;
                        _fitAll(tr!);
                      }
                    },
                  ),
                  children: [
                    mapTiles(),
                    ..._routeOverlays(
                      _drawn,
                      done: tr != null && tr['status'] == 'delivered',
                    ),
                    MarkerLayer(
                      markers: [
                        if (tr != null) ...[
                          for (final s in _storesOf(
                            tr,
                            listKey: 'group_stores',
                          ))
                            mMaker(
                              s,
                              mapPin('🏪', AppColors.primaryLight),
                              label: 'محل',
                            ),
                          if (tr['store_lat'] != null)
                            mMaker(
                              LatLng(
                                (tr['store_lat'] as num).toDouble(),
                                (tr['store_lng'] as num).toDouble(),
                              ),
                              mapPin('🏪', AppColors.primaryLight),
                              label: tr['store_name'] ?? 'المتجر',
                            ),
                          if (tr['user_lat'] != null &&
                              tr['user_lng'] != null &&
                              (tr['courier_lat'] == null ||
                                  tr['status'] == 'delivered'))
                            mMaker(
                              LatLng(
                                (tr['user_lat'] as num).toDouble(),
                                (tr['user_lng'] as num).toDouble(),
                              ),
                              mapPin('🏠', AppColors.success),
                              label: 'بيتي',
                            ),
                          if (tr['courier_lat'] != null &&
                              tr['courier_lng'] != null)
                            mMaker(
                              LatLng(
                                (tr['courier_lat'] as num).toDouble(),
                                (tr['courier_lng'] as num).toDouble(),
                              ),
                              mapPin('🛵', AppColors.primary),
                              label: tr['courier_name'] ?? 'المندوب',
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 14,
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: tr == null
                        ? Text(
                            'بالانتظار لانطلاقه للتوصيل...',
                            style: AppType.style(12.5),
                          )
                        : Row(
                            children: [
                              (tr['courier_lat'] == null ||
                                          tr['courier_lng'] == null) &&
                                      tr['status'] != 'delivered'
                                  ? Expanded(
                                      child: Text(
                                        'المندوب صار بالتوصيل 💨 — الموقع رح يظهر معناه',
                                        style: AppType.style(12.5),
                                      ),
                                    )
                                  : Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${tr['courier_name'] ?? ''} — ${tr['courier_phone'] ?? ''}',
                                            style: AppType.style(
                                              12.5,
                                              weight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            tr['courier_lat'] != null
                                                ? 'آخر تنسيب: ${(tr['courier_lat'] as num).toStringAsFixed(5)}, ${(tr['courier_lng'] as num).toStringAsFixed(5)}'
                                                : 'لم يرسل موقعه بعد',
                                            style: AppType.style(
                                              10,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class CourierMapScreen extends StatefulWidget {
  final Map trip;
  const CourierMapScreen({super.key, required this.trip});

  @override
  State<CourierMapScreen> createState() => _CourierMapScreenState();
}

class _CourierMapScreenState extends State<CourierMapScreen> {
  final _c = MapController();
  Timer? _auto;
  Timer? _rerouteT;
  Position? me;
  LatLng? meManual;
  bool busy = false;
  bool _follow = true;
  bool _routing = false;
  bool _mapReady = false;
  DateTime _lastTouch = DateTime(2000);
  LatLng? _lastRouteFrom;
  List<LatLng> _plan = [];
  List<LatLng> _remain = [];
  double _tripKm = 0, _tripMin = 0;
  int _multiCount = 1;

  double? get _mlat => meManual?.latitude ?? me?.latitude;
  double? get _mlng => meManual?.longitude ?? me?.longitude;
  int get _tripId =>
      (widget.trip['id'] as num?)?.toInt() ??
      (widget.trip['trip_id'] as num?)?.toInt() ??
      0;

  @override
  void initState() {
    super.initState();
    // ═══ أي خطأ في الإقلاع (GPS/شبكة) ما يخرب الشاشة — يضل الخريطة تشتغل ═══
    try {
      _loadPlan();
      _sendMyPos();
      _auto = Timer.periodic(const Duration(seconds: 5), (_) => _sendMyPos());
      _rerouteT = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _maybeReroute(),
      );
    } catch (e) {
      debugPrint('خطأ إقلاع خريطة التوصيل: $e');
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _rerouteT?.cancel();
    super.dispose();
  }

  // المحلات المتبقية: ما زالت بعيدة عن المندوب (بعدّها "وصلها" إذا صار أقرب من 250م)
  List<LatLng> _remainingStores(LatLng from) {
    final all = _storesOf(widget.trip, listKey: 'orders');
    return [
      for (final s in all)
        if (_hav(from, s) > 250) s,
    ];
  }

  Future<void> _loadPlan({LatLng? from}) async {
    final tr = widget.trip;
    final to = (tr['user_lat'] != null && tr['user_lng'] != null)
        ? LatLng(
            (tr['user_lat'] as num).toDouble(),
            (tr['user_lng'] as num).toDouble(),
          )
        : null;
    if (to == null) return;
    final stores = _storesOf(tr, listKey: 'orders');
    if (stores.isNotEmpty) {
      // طلب من أكثر من محل: المسار يمر ببقية المحلات (بالأقرب) ثم البيت
      final rest = (from != null) ? _remainingStores(from) : stores;
      final f =
          from ??
          ((_mlat != null)
              ? LatLng(_mlat!, _mlng!)
              : rest.isNotEmpty
              ? rest.first
              : to);
      final m = await _fetchMultiPlan(f, rest, to);
      if (mounted && m.pts.isNotEmpty) {
        setState(() {
          _plan = m.pts;
          _remain = m.pts;
          _tripKm = m.km;
          _tripMin = m.min;
          _multiCount = rest.length;
          _lastRouteFrom = f;
        });
      }
      return;
    }
    final s = (tr['store_lat'] != null && tr['store_lng'] != null)
        ? LatLng(
            (tr['store_lat'] as num).toDouble(),
            (tr['store_lng'] as num).toDouble(),
          )
        : null;
    final f = from ?? ((_mlat != null) ? LatLng(_mlat!, _mlng!) : s);
    if (f == null) return;
    final plan = await _fetchPlan(f, to);
    if (mounted && plan.isNotEmpty) {
      setState(() {
        _plan = plan;
        _remain = plan;
        _lastRouteFrom = f;
      });
    }
  }

  // يعيد حساب المسار فقط إذا تحرك المندوب أكثر من 200 متر عن آخر مسار
  void _maybeReroute() {
    if (_routing || _mlat == null || _mlng == null) return;
    final pos = LatLng(_mlat!, _mlng!);
    final moved = _lastRouteFrom == null || _hav(_lastRouteFrom!, pos) > 200;
    if (!moved) return;
    _routing = true;
    _loadPlan(from: pos).whenComplete(() => _routing = false);
  }

  void _fitAll() {
    // ═══ لا تلمس الكاميرا قبل جاهزية الخريطة — يسبب تجمد الشاشة ═══
    if (!_mapReady) return;
    final tr = widget.trip;
    final pts = <LatLng>[];
    void add(Object? lat, Object? lng) {
      if (lat is num && lng is num)
        pts.add(LatLng((lat as num).toDouble(), (lng as num).toDouble()));
    }

    add(tr['user_lat'], tr['user_lng']);
    add(tr['store_lat'], tr['store_lng']);
    if (pts.isEmpty) pts.add(_kut);
    try {
      _c.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {
      try {
        _c.move(pts.first, 13);
      } catch (_) {}
    }
  }

  Future<void> _send(LatLng p) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Api.post('/api/delivery/location', {
        'trip_id': _tripId,
        'lat': p.latitude,
        'lng': p.longitude,
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendMyPos() async {
    final pos = await askGps();
    if (!mounted || pos == null) return;
    final p = LatLng(pos.latitude, pos.longitude);
    setState(() => me = pos);
    await _send(p);
    // المسار يتبع المندوب: يعيد الحساب من موقعه الجديد إذا تحرك عن آخر مسار
    _maybeReroute();
    // الكاميرا تتبع المندوب إلا إذا المستخدم حرك الخريطة بنفسه
    if (_follow && _mapReady && DateTime.now().difference(_lastTouch).inSeconds > 10) {
      try {
        _c.move(p, 15);
      } catch (_) {}
    }
  }

  Future<void> _openNav(String kind) async {
    final tr = widget.trip;
    String? pt(Object? la, Object? ln) =>
        (la != null && ln != null) ? '$la,$ln' : null;
    final start = pt(tr['store_lat'], tr['store_lng']);
    final dest = pt(tr['user_lat'], tr['user_lng']);
    final d = dest ?? start;
    if (d == null) {
      toast(context, 'ماكو إحداثيات للمسار', error: true);
      return;
    }
    String url;
    switch (kind) {
      case 'waze':
        url = 'https://waze.com/ul?ll=$d&navigate=yes';
        break;
      case 'mapsme':
        final s = start ?? d;
        url =
            'mapsme://route?slat=${s.split(',')[0]}&slon=${s.split(',')[1]}&dlat=${d.split(',')[0]}&dlon=${d.split(',')[1]}';
        break;
      default:
        url =
            'https://www.google.com/maps/dir/?api=1${start != null ? '&origin=$start' : ''}&destination=$d&travelmode=driving';
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted)
      toast(context, 'التطبيق غير مثبت على الجهاز', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.trip;
    LatLng? store = (tr['store_lat'] != null)
        ? LatLng(
            (tr['store_lat'] as num).toDouble(),
            (tr['store_lng'] as num).toDouble(),
          )
        : null;
    LatLng? user = (tr['user_lat'] != null && tr['user_lng'] != null)
        ? LatLng(
            (tr['user_lat'] as num).toDouble(),
            (tr['user_lng'] as num).toDouble(),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(Icons.delivery_dining_rounded, 'خريطة التوصيل'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _c,
            options: MapOptions(
              initialCenter: store ?? user ?? _kut,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _fitAll();
                _loadPlan();
              },
              onTap: (_, p) {
                _lastTouch = DateTime.now();
                setState(() => meManual = p);
                _send(p);
              },
              onPointerDown: (_, __) {
                _lastTouch = DateTime.now();
              },
            ),
            children: [
              mapTiles(),
              if ((_remain.isNotEmpty ? _remain : _plan).length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _remain.isNotEmpty ? _remain : _plan,
                      strokeWidth: 4,
                      color: AppColors.primary.withValues(alpha: .85),
                      borderStrokeWidth: 1.2,
                      borderColor: Colors.white70,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final e in (tr['orders'] as List? ?? []).indexed)
                    if (e.$2 is Map &&
                        (e.$2 as Map)['store_lat'] is num &&
                        (e.$2 as Map)['store_lng'] is num)
                      mMaker(
                        LatLng(
                          ((e.$2 as Map)['store_lat'] as num).toDouble(),
                          ((e.$2 as Map)['store_lng'] as num).toDouble(),
                        ),
                        mapPin('🏪', AppColors.primaryLight),
                        label: shortName(
                          (e.$2 as Map)['store_name'] as String?,
                        ),
                      ),
                  if (user != null)
                    mMaker(
                      user,
                      mapPin('🏠', AppColors.success),
                      label: 'الزبون',
                    ),
                  if (_mlat != null)
                    mMaker(
                      LatLng(_mlat!, _mlng!),
                      mapPin('🛵', AppColors.primary),
                      label: 'أنا',
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 14,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_tripMin > 0 || _multiCount > 1) ...[
                    Text(
                      [
                        if (_tripMin > 0) 'الرحلة ${_fmtMin(_tripMin)}',
                        if (_tripKm > 0) '${_tripKm.toStringAsFixed(1)} كم',
                        if (_multiCount > 1) '$_multiCount محلات',
                      ].join(' · '),
                      style: AppType.style(
                        12.5,
                        weight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'مشاركة المسار مع تطبيق خريطة آخر:',
                    style: AppType.style(
                      11,
                      weight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          onPressed: () => _openNav('gmaps'),
                          child: const Text(
                            'جوجل مابس 🗺',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          onPressed: () => _openNav('waze'),
                          child: const Text(
                            'واز 🚗',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          onPressed: () => _openNav('mapsme'),
                          child: const Text(
                            'مابزمي 📍',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يفتح الملاحة بالمسار: من المتجر 🏪 إلى بيت الزبون 🏠',
                    style: AppType.style(9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// معاينة المسار قبل قبول الطلب — للمندوب في صفحة «متاح»
class RoutePreviewScreen extends StatefulWidget {
  final LatLng? from;
  final List<LatLng> stops;
  final LatLng to;
  final String? fromLabel;
  final String? toLabel;
  const RoutePreviewScreen({
    super.key,
    this.from,
    this.stops = const [],
    required this.to,
    this.fromLabel,
    this.toLabel,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final _c = MapController();
  List<LatLng> _plan = [];
  double _km = 0, _min = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.stops.isNotEmpty) {
        final m = await _fetchMultiPlan(
          widget.from ?? widget.stops.first,
          widget.stops,
          widget.to,
        );
        if (mounted)
          setState(() {
            _plan = m.pts;
            _km = m.km;
            _min = m.min;
            loading = false;
          });
      } else if (widget.from != null) {
        final plan = await _fetchPlan(widget.from!, widget.to);
        if (mounted)
          setState(() {
            _plan = plan;
            loading = false;
          });
        if (plan.isNotEmpty && mounted) {
          var km = 0.0;
          for (var i = 0; i < plan.length - 1; i++)
            km += _hav(plan[i], plan[i + 1]);
          setState(() {
            _km = km / 1000;
            _min = km / 25 * 60;
          });
        }
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _fit() {
    final pts = <LatLng>[
      if (widget.from != null) widget.from!,
      ...widget.stops,
      widget.to,
    ];
    if (pts.isEmpty) return;
    try {
      _c.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {
      try {
        _c.move(pts.first, 13);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(Icons.route_rounded, 'معاينة المسار'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _c,
            options: MapOptions(
              initialCenter: widget.from ?? widget.to,
              initialZoom: 13,
              onMapReady: _fit,
            ),
            children: [
              mapTiles(),
              if (_plan.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _plan,
                      strokeWidth: 4,
                      color: AppColors.primary.withValues(alpha: .85),
                      borderStrokeWidth: 1.2,
                      borderColor: Colors.white70,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.from != null)
                    mMaker(
                      widget.from!,
                      mapPin('🏪', AppColors.primaryLight),
                      label: shortName(widget.fromLabel),
                    ),
                  for (final s in widget.stops)
                    mMaker(
                      s,
                      mapPin('🏪', AppColors.primaryLight),
                      label: 'محل',
                    ),
                  mMaker(
                    widget.to,
                    mapPin('🏠', AppColors.success),
                    label: shortName(widget.toLabel),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 14,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: loading
                  ? Row(
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('جاري حساب المسار...'),
                      ],
                    )
                  : _plan.isEmpty
                  ? const Text(
                      'ماكو إحداثيات كافية للمسار',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.route_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _km > 0
                                    ? 'من المحل إلى الزبون: ${_km.toStringAsFixed(1)} كم'
                                    : 'المسار على الشوارع',
                                style: AppType.style(
                                  13,
                                  weight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                'الوقت المتوقع: ${_fmtMin(_min)} · $shortRoute',
                                style: AppType.style(
                                  11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String get shortRoute => 'المحل 🏪 ← الزبون 🏠';
}

/// كرت الخريطة الحي — يُعرض أوتوماتيك داخل تفاصيل الطلب للزبون
class LiveTrackCard extends StatefulWidget {
  final int orderId;
  const LiveTrackCard({super.key, required this.orderId});

  @override
  State<LiveTrackCard> createState() => _LiveTrackCardState();
}

class _LiveTrackCardState extends State<LiveTrackCard> {
  final _c = MapController();
  Timer? _t;
  Map<String, dynamic>? tr;
  List<LatLng> _plan = [];
  List<LatLng> _remain = [];
  List<LatLng> _drawn = [];
  LatLng? _lastRemPos;
  DateTime? _lastRemAt;
  bool _remBusy = false;
  bool _fitted = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await Api.get('/api/customer/orders/${widget.orderId}/track');
      final nt = d['tracking'];
      if (nt == null) return;
      final data = nt as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => tr = data);
      if (_plan.isEmpty &&
          data['user_lat'] != null &&
          data['user_lng'] != null) {
        final home = LatLng(
          (data['user_lat'] as num).toDouble(),
          (data['user_lng'] as num).toDouble(),
        );
        final gs = _storesOf(data, listKey: 'group_stores');
        if (gs.isNotEmpty &&
            data['courier_lat'] != null &&
            data['courier_lng'] != null) {
          final m = await _fetchMultiPlan(
            LatLng(
              (data['courier_lat'] as num).toDouble(),
              (data['courier_lng'] as num).toDouble(),
            ),
            gs,
            home,
          );
          if (mounted && m.pts.isNotEmpty) setState(() => _plan = m.pts);
        } else if (data['store_lat'] != null) {
          final plan = await _fetchPlan(
            LatLng(
              (data['store_lat'] as num).toDouble(),
              (data['store_lng'] as num).toDouble(),
            ),
            home,
          );
          if (mounted && plan.isNotEmpty) setState(() => _plan = plan);
        }
      }
      // المتبقي يعاد حسابه من موقع المندوب الحالي كلما تحرك أكثر من 200م (بحد أقصى مرة كل 10 ثواني)
      if (data['status'] != 'delivered' &&
          data['courier_lat'] != null &&
          data['courier_lng'] != null) {
        final cp = LatLng(
          (data['courier_lat'] as num).toDouble(),
          (data['courier_lng'] as num).toDouble(),
        );
        final moved = _lastRemPos == null || _hav(_lastRemPos!, cp) > 200;
        final cooled =
            _lastRemAt == null ||
            DateTime.now().difference(_lastRemAt!) >
                const Duration(seconds: 10);
        if (moved && cooled && !_remBusy) {
          _remBusy = true;
          final r = await _remainderFrom(data, cp);
          _remBusy = false;
          _lastRemAt = DateTime.now();
          if (r.isNotEmpty) {
            if (mounted) setState(() => _remain = r);
            _lastRemPos = cp;
          }
        }
      }
      final drawn = _drawnFrom(data, _pathFrom(data), _remain, _plan);
      if (mounted && drawn.isNotEmpty) setState(() => _drawn = drawn);
      if (!_fitted &&
          _mapReady &&
          data['courier_lat'] != null &&
          data['courier_lng'] != null) {
        _fitted = true;
        final pts = _pathFrom(data);
        for (final s in _storesOf(data, listKey: 'group_stores')) {
          pts.add(s);
        }
        if (data['store_lat'] != null)
          pts.add(
            LatLng(
              (data['store_lat'] as num).toDouble(),
              (data['store_lng'] as num).toDouble(),
            ),
          );
        if (data['user_lat'] != null && data['user_lng'] != null)
          pts.add(
            LatLng(
              (data['user_lat'] as num).toDouble(),
              (data['user_lng'] as num).toDouble(),
            ),
          );
        if (pts.isNotEmpty) {
          try {
            _c.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(pts),
                padding: const EdgeInsets.all(34),
              ),
            );
          } catch (_) {
            _c.move(pts.first, 13);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tr = this.tr;
    if (tr == null) return const SizedBox(height: 200, child: Loader());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              tr['status'] == 'delivered'
                  ? 'وصل طلبك — هذا المسار الي انسلك به 🛵'
                  : 'مسار المندوب حياً 🛵',
              style: AppType.style(
                13.5,
                weight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              mapController: _c,
              options: MapOptions(
                initialCenter: _kut,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: () {
                  _mapReady = true;
                  if (tr != null &&
                      !_fitted &&
                      tr!['courier_lat'] != null &&
                      tr!['courier_lng'] != null) {
                    _fitted = true;
                    final pts = _pathFrom(tr!);
                    if (tr!['store_lat'] != null)
                      pts.add(
                        LatLng(
                          (tr!['store_lat'] as num).toDouble(),
                          (tr!['store_lng'] as num).toDouble(),
                        ),
                      );
                    if (tr!['user_lat'] != null && tr!['user_lng'] != null)
                      pts.add(
                        LatLng(
                          (tr!['user_lat'] as num).toDouble(),
                          (tr!['user_lng'] as num).toDouble(),
                        ),
                      );
                    if (pts.isNotEmpty) {
                      try {
                        _c.fitCamera(
                          CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(pts),
                            padding: const EdgeInsets.all(34),
                          ),
                        );
                      } catch (_) {
                        _c.move(pts.first, 13);
                      }
                    }
                  }
                },
              ),
              children: [
                mapTiles(),
                ..._routeOverlays(_drawn, done: tr['status'] == 'delivered'),
                MarkerLayer(
                  markers: [
                    for (final s in _storesOf(tr, listKey: 'group_stores'))
                      mMaker(
                        s,
                        mapPin('🏪', AppColors.primaryLight),
                        label: 'محل',
                      ),
                    if (tr['store_lat'] != null)
                      mMaker(
                        LatLng(
                          (tr['store_lat'] as num).toDouble(),
                          (tr['store_lng'] as num).toDouble(),
                        ),
                        mapPin('🏪', AppColors.primaryLight),
                        label: shortName(tr['store_name'] as String?),
                      ),
                    if (tr['courier_lat'] != null &&
                        tr['courier_lng'] != null &&
                        tr['status'] != 'delivered')
                      mMaker(
                        LatLng(
                          (tr['courier_lat'] as num).toDouble(),
                          (tr['courier_lng'] as num).toDouble(),
                        ),
                        mapPin('🛵', AppColors.primary),
                        label: tr['courier_name'] ?? 'المندوب',
                      ),
                    if (tr['user_lat'] != null && tr['user_lng'] != null)
                      mMaker(
                        LatLng(
                          (tr['user_lat'] as num).toDouble(),
                          (tr['user_lng'] as num).toDouble(),
                        ),
                        mapPin('🏠', AppColors.success),
                        label: 'بيتي',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr['courier_lat'] == null
              ? 'المندوب بالطريق 💨 — الموقع رح يبدي ما ينطلق'
              : tr['status'] == 'delivered'
              ? 'تم التسليم ✅ شكراً لتعاملك معنا'
              : (_remain.isNotEmpty ? _remain : _plan).isEmpty
              ? '${tr['courier_name'] ?? 'المندوب'} — ${tr['courier_phone'] ?? ''} · آخر تحديث للموقع'
              : _etaText(
                  _remain.isNotEmpty ? _remain : _plan,
                  LatLng(
                    (tr['courier_lat'] as num).toDouble(),
                    (tr['courier_lng'] as num).toDouble(),
                  ),
                  tr,
                ),
          style: AppType.style(11, color: AppColors.muted),
        ),
      ],
    );
  }

  String _etaText(List<LatLng> plan, LatLng pos, Map tr) {
    final e = _eta(plan, pos);
    final mins = (e.min * 60).round();
    final m = mins >= 60
        ? '${(mins / 60).floor()}س ${(mins % 60)}د'
        : '${mins}د';
    return '${tr['courier_name'] ?? 'المندوب'} — ${tr['courier_phone'] ?? ''} · المتبقي ${e.km.toStringAsFixed(1)} كم · وصول تقريبي $m';
  }
}
