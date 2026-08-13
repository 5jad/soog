import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/features/notifications/screens/notifications_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// محرك الإشعارات — جلب دوري خفيف كل 8 ثوانٍ:
/// يفحص عدد غير المقروء + آخر إشعار، وعند أي جديد يعرض:
/// 1) نافذة منبثقة داخل التطبيق  2) إشعار نظام حقيقي على الهاتف
class NotifPusher {
  static final NotifPusher i = NotifPusher._();
  NotifPusher._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  int _lastCount = -1;
  bool _permissionAsked = false;

  static const _channel = AndroidNotificationDetails(
    'zaboon_channel',
    'إشعارات زبون',
    channelDescription: 'إشعارات الطلبات والتحديثات من زبون',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  /// يُستدعى مرة واحدة عند إقلاع التطبيق
  Future<void> start() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _requestPermission();
    _timer ??= Timer.periodic(const Duration(seconds: 8), (_) => _tick());
    _tick(); // فحص فوري عند الفتح
  }

  Future<void> _requestPermission() async {
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
        final title = '${latest['title'] ?? 'إشعار جديد'}';
        final body = '${latest['body'] ?? ''}';
        _show(title, body);
        AppState.i.notifReload.value++;
      }
    } catch (_) {
      // لا اتصال — نتجاهل بهدوء
    }
  }

  Future<void> _show(String title, String body) async {
    showNotifPopup(title, body);
    await _plugin.show(_lastCount, title, body, const NotificationDetails(android: _channel));
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