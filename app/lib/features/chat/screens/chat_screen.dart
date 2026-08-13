import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

/// المحادثات — قائمة + فتح محادثة (الزبون مع المندوب فقط، أثناء التوصيل)
class ChatListScreen extends StatefulWidget {
  final String role; // customer / delivery
  const ChatListScreen({super.key, required this.role});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List conversations = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/${widget.role}/conversations');
      conversations = d['conversations'] ?? [];
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameOf = (c) => c['courier_name'] ?? c['user_name'] ?? 'زبون';
    final logoOf = (c) => null;

    return Scaffold(
      appBar: AppBar(title: const ScreenTitle(Icons.chat_bubble_rounded, 'المحادثات')),
      body: loading
          ? const Loader()
          : conversations.isEmpty
          ? const EmptyState(
              icon: '💬',
              title: 'لا محادثات بعد',
              sub: 'المحادثة تبدأ من صفحة الطلب أثناء التوصيل',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: conversations.length,
              itemBuilder: (_, i) {
                final c = conversations[i];
                final unread = c['has_unread'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(role: widget.role, conversation: c),
                      ),
                    ).then((_) => _load()),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          logoOf(c) == null
                              ? CircleAvatar(
                                  child: Text(
                                    (nameOf(c) ?? '؟')
                                        .toString()
                                        .characters
                                        .first,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  backgroundColor: AppColors.primaryLight
                                      .withOpacity(0.25),
                                )
                              : storeLogo('${logoOf(c)}', size: 42, radius: 13),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${nameOf(c)}',
                                  style: AppType.style(
                                    14,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${c['last_message'] ?? 'بداية المحادثة'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.style(
                                    11.5,
                                    color: unread
                                        ? AppColors.primary
                                        : AppColors.muted,
                                    weight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// نافذة المحادثة الفعلية (زبون أو مندوب)
class ChatScreen extends StatefulWidget {
  final String role; // 'customer' / 'delivery'
  final Map<String, dynamic> conversation;
  const ChatScreen({super.key, required this.role, required this.conversation});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctrl = TextEditingController();
  List messages = [];
  bool loading = true;

  String get _base =>
      '/api/${widget.role}/conversations/${widget.conversation['id']}/messages';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get(_base);
      messages = d['messages'] ?? [];
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    ctrl.clear();
    try {
      final d = await Api.post(_base, {'body': t});
      setState(() => messages.add(d['message']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final myRole = widget.role == 'delivery' ? 'courier' : 'customer';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.conversation['courier_name'] ?? widget.conversation['user_name'] ?? 'محادثة'}',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Loader()
                : messages.isEmpty
                ? const EmptyState(
                    icon: '👋',
                    title: 'ابدأ المحادثة',
                    sub: 'اسأل عن منتج أو مدة التوصيل',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final mine = m['sender_role'] == myRole;
                      return Align(
                        alignment: mine
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 3),
                              bottomRight: Radius.circular(mine ? 3 : 16),
                            ),
                          ),
                          child: Text(
                            '${m['body']}',
                            style: AppType.style(
                              13.5,
                              color: mine ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        filled: true,
                        fillColor: AppColors.bg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
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
