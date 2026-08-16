import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/notifications/screens/notifications_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// مفتاح آخر إشعار تم عرضه على هذا الجهاز (يُخزن محلياً لتفادي التكرار)
const _lastShownKey = 'zaboon_last_notif_id';

const _channel = AndroidNotificationDetails(
  'zaboon_channel',
  'إشعارات زبون',
  channelDescription: 'إشعارات الطلبات والتحديثات من زبون',
  importance: Importance.max,
  priority: Priority.high,
  playSound: true,
  enableVibration: true,
);

/// ═══════════ المهمة الخلفية (تشتغل حتى لو التطبيق مقفول) ═══════════
/// تستيقظ كل 15 دقيقة، تجلب عدد الإشعارات غير المقروءة،
/// وإذا فيه إشعار جديد يعرض إشعار نظام حقيقي على الهاتف.
@pragma('vm:entry-point')
void notifBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('zaboon_token');
      var base = prefs.getString('zaboon_base') ?? '';
      if (token == null || token.isEmpty) return true;
      if (base.isEmpty) base = Api.cloud;
      final r = await httpGet('$base/api/customer/notifications/count', token);
      if (r == null) return true;
      final latest = r['latest'];
      if (latest is! Map || latest.isEmpty) return true;
      final id = (latest['id'] as num?)?.toInt() ?? 0;
      final lastShown = prefs.getInt(_lastShownKey) ?? 0;
      if (id <= lastShown) return true;
      await prefs.setInt(_lastShownKey, id);

      final plugin = FlutterLocalNotificationsPlugin();
      const init = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      );
      await plugin.initialize(init);
      await plugin.show(
        id,
        '${latest['title'] ?? 'إشعار جديد'}',
        '${latest['body'] ?? ''}',
        const NotificationDetails(android: _channel),
      );
    } catch (_) {
      // لا اتصال أو خطأ — نتجاهل بهدوء، يعيد المحاولة الجولة الجاية
    }
    return true;
  });
}

Future<Map<String, dynamic>?> httpGet(String url, String token) async {
  try {
    final r = await http
        .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

/// محرك الإشعارات:
/// 1) جلب دوري خفيف كل 8 ثوانٍ (التطبيق مفتوح) — نافذة منبثقة + إشعار نظام
/// 2) مهمة خلفية كل 15 دقيقة (التطبيق مقفول) — إشعار نظام حقيقي
class NotifPusher {
  static final NotifPusher i = NotifPusher._();
  NotifPusher._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  int _lastCount = -1;
  int _lastShownId = 0;
  bool _permissionAsked = false;

  static const _taskName = 'zaboonNotifSync';
  static const _taskTag = 'zaboon-notif-sync';

  /// يُستدعى مرة واحدة عند إقلاع التطبيق
  Future<void> start() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    // تسجيل المهمة الخلفية (مرة واحدة تكفي — أندرويد يخلّيها حتى بعد إغلاق التطبيق)
    final prefs = await SharedPreferences.getInstance();
    _lastShownId = prefs.getInt(_lastShownKey) ?? 0;
    try {
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskTag,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        initialDelay: const Duration(minutes: 1),
      );
    } catch (_) {}

    _timer ??= Timer.periodic(const Duration(seconds: 8), (_) => _tick());
    _tick(); // فحص فوري عند الفتح
  }

  Future<void> requestPermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    // أندرويد 13+ يطلب الإذن من المستخدم صراحةً
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _tick() async {
    if (!Api.logged) return;
    try {
      final d = await Api.get('/api/customer/notifications/count');
      final count = (d?['count'] as num?)?.toInt() ?? 0;
      final first = _lastCount < 0; // أول جولة — نكتفي بتزامن العداد
      _lastCount = count;
      AppState.i.unreadNotifs.value = count;
      if (first) return;
      final latest = d?['latest'];
      if (latest is Map && latest.isNotEmpty) {
        final id = (latest['id'] as num?)?.toInt() ?? 0;
        if (id <= _lastShownId) return;
        _lastShownId = id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastShownKey, id);
        _show('${latest['title'] ?? 'إشعار جديد'}', '${latest['body'] ?? ''}', id);
        AppState.i.notifReload.value++;
      }
    } catch (_) {
      // لا اتصال — نتجاهل بهدوء
    }
  }

  Future<void> _show(String title, String body, int id) async {
    showNotifPopup(title, body);
    await _plugin.show(id, title, body, const NotificationDetails(android: _channel));
  }
}

/// نافذة منبثقة أنيقة أعلى الشاشة — تختفي بعد 4 ثوانٍ، ضغطة عليها تفتح الإشعارات
void showNotifPopup(String title, String body) {
  final nav = appNavigatorKey.currentState;
  final overlay = nav?.overlay;
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _NotifBanner(
      title: title,
      body: body,
      onClose: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 4), () {
    if (entry.mounted) entry.remove();
  });
}

class _NotifBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onClose;
  const _NotifBanner({required this.title, required this.body, required this.onClose});

  @override
  State<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends State<_NotifBanner> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _in = true));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          ignoring: false,
          child: AnimatedSlide(
            offset: _in ? Offset.zero : const Offset(0, -1.4),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _in ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    widget.onClose();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12294E),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2560F),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 19),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
