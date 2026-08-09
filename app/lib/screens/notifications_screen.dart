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
      AppState.i.unreadNotifs = notifs.where((n) => !(n['read'] == true || n['read'] == 1)).length;
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات 🔔')),
      body: loading
          ? const Loader()
          : notifs.isEmpty
              ? const EmptyState(icon: '🔕', title: 'لا إشعارات')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = Map<String, dynamic>.from(notifs[i] as Map);
                    final read = n['read'] == true || n['read'] == 1;
                    return GestureDetector(
                      onTap: () async {
                        try {
                          await Api.post('/api/customer/notifications/${n['id']}/read');
                          _load();
                        } catch (_) {}
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: read ? A.glass(radius: 16, soft: true) : A.glass(radius: 16, tint: A.primaryLight),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: read ? A.bg : A.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(n['icon'] ?? '🔔', style: A.t(16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(n['title'] ?? '', style: A.t(13.5, w: FontWeight.w900))),
                              if (!read) const DotChip(label: '', color: A.accent),
                            ]),
                            const SizedBox(height: 3),
                            Text(n['body'] ?? '', style: A.t(11.5, c: A.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(timeAgo(n['created_at'] ?? ''), style: A.t(10, c: A.muted)),
                          ])),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
