import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List notifs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/customer/notifications');
      notifs = (d['notifications'] ?? []) as List;
      _refreshUnread();
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _refreshUnread() {
    AppState.i.unreadNotifs.value =
        notifs.where((n) => !(n['read'] == true || n['read'] == 1)).length;
  }

  Future<void> _markAll() async {
    try {
      await Api.post('/api/customer/notifications/read');
      await _load();
    } catch (_) {}
  }

  Future<void> _markOne(Map n) async {
    try {
      await Api.post('/api/customer/notifications/${n['id']}/read');
    } catch (_) {}
    setState(() => n['read'] = true);
    _refreshUnread();
  }

  Future<void> _delete(Map n) async {
    try {
      await Api.del('/api/customer/notifications/${n['id']}');
    } catch (_) {}
    setState(() => notifs.remove(n));
    _refreshUnread();
  }

  Color _typeColor(String t) => switch (t) {
        'success' => A.success,
        'danger' => A.danger,
        'warning' => A.warning,
        'info' => A.info,
        _ => A.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: A.bg,
      appBar: AppBar(
        title: const Text('الإشعارات 🔔'),
        actions: [
          if (!loading && notifs.isNotEmpty)
            TextButton.icon(
              onPressed: _markAll,
              icon: const Icon(Icons.done_all_rounded, size: 17, color: A.primary),
              label: Text('تعليم الكل', style: A.t(11.5, c: A.primary, w: FontWeight.w800)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Loader()
          : notifs.isEmpty
              ? const EmptyState(icon: '🔕', title: 'لا إشعارات', sub: 'كل جديد بيوصلك هنا')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final n = Map<String, dynamic>.from(notifs[i] as Map);
                    final read = n['read'] == true || n['read'] == 1;
                    final tc = _typeColor('${n['type'] ?? 'info'}');
                    return Dismissible(
                      key: ValueKey(n['id']),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(n),
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsetsDirectional.only(end: 18),
                        decoration: BoxDecoration(
                          color: A.danger,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          SizedBox(width: 5),
                          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 19),
                        ]),
                      ),
                      child: GestureDetector(
                        onTap: () => read ? {} : _markOne(n),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          decoration: read
                              ? A.glass(radius: 16, soft: true)
                              : BoxDecoration(
                                  color: tc.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: tc.withOpacity(0.22)),
                                ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: read ? A.bg : tc.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${n['icon'] ?? '🔔'}', style: A.t(17)),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(n['title'] ?? '',
                                        style: A.t(13, c: read ? A.ink : A.ink, w: FontWeight.w900),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  if (!read) DotChip(label: 'جديد', color: tc),
                                ]),
                                const SizedBox(height: 3),
                                Text(n['body'] ?? '', style: A.t(11.5, c: A.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(Icons.schedule_rounded, size: 11, color: A.muted.withOpacity(0.8)),
                                  const SizedBox(width: 4),
                                  Text(timeAgo(n['created_at'] ?? ''), style: A.t(9.5, c: A.muted)),
                                ]),
                              ]),
                            ),
                            const SizedBox(width: 6),
                            // تلميح سحب للحذف
                            Icon(Icons.swipe_left_alt_rounded, size: 15, color: A.muted.withOpacity(0.45)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}