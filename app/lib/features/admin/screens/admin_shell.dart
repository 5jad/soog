import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';

/// لوحة تحكم الأدمن (مصغرة للجوال): نظرة عامة · الإعلانات · الكاش · المتاجر
class AdminShell extends StatefulWidget {
  final VoidCallback onExit;
  const AdminShell({super.key, required this.onExit});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(Icons.admin_panel_settings_rounded, 'لوحة التحكم'),
        actions: [
          IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.muted),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          _AdminOverview(),
          _AdminAds(),
          _AdminCash(),
          _AdminStores(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        index: tab,
        items: const [
          (Icons.dashboard_rounded, 'نظرة عامة'),
          (Icons.campaign_rounded, 'الإعلانات'),
          (Icons.payments_rounded, 'الكاش'),
          (Icons.storefront_rounded, 'المتاجر'),
        ],
        onTap: (i) => setState(() => tab = i),
      ),
    );
  }
}

class _AdminOverview extends StatefulWidget {
  const _AdminOverview();
  @override
  State<_AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<_AdminOverview> {
  dynamic stats;
  List recent = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/admin/stats');
      stats = d['stats'];
      recent = (d['recent_orders'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    final s = (stats ?? {}) as Map<String, dynamic>;
    final queue = (s['queue'] ?? {}) as Map<String, dynamic>;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قرارات معلقة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (queue['total'] ?? 0) > 0
                      ? AppColors.warning.withOpacity(0.15)
                      : AppColors.success.withOpacity(0.12),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (queue['total'] ?? 0) > 0
                    ? AppColors.warning.withOpacity(0.4)
                    : AppColors.success.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قرارات معلقة',
                  style: AppType.style(
                    12.5,
                    color: AppColors.muted,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _pill(
                      '📣 إعلانات: ${queue['ads'] ?? 0}',
                      (queue['ads'] ?? 0) > 0,
                    ),
                    _pill(
                      '📋 مستندات: ${queue['docs'] ?? 0}',
                      (queue['docs'] ?? 0) > 0,
                    ),
                    _pill(
                      '💵 كاش: ${queue['cash'] ?? 0}',
                      (queue['cash'] ?? 0) > 0,
                    ),
                    _pill(
                      '💸 سحب: ${queue['withdrawals'] ?? 0}',
                      (queue['withdrawals'] ?? 0) > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MoneyBox(
                  label: 'مبيعات اليوم',
                  value: formatMoney(s['sales_today'] ?? 0),
                  icon: Icons.payments_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MoneyBox(
                  label: 'طلبات اليوم',
                  value: '${s['orders_today'] ?? 0}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MoneyBox(
                  label: 'المتاجر',
                  value: '${s['stores'] ?? 0}',
                  icon: Icons.storefront_rounded,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MoneyBox(
                  label: 'المستخدمين',
                  value: '${s['users'] ?? 0}',
                  icon: Icons.people_rounded,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'أحدث الطلبات',
            style: AppType.style(14, weight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const EmptyState(icon: '🧾', title: 'لا طلبات')
          else
            for (final o in recent) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${o['code']}',
                            style: AppType.style(13, weight: FontWeight.w900),
                          ),
                          Text(
                            '${o['store_name']}',
                            style: AppType.style(10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(o['status'] ?? ''),
                    const SizedBox(width: 10),
                    Text(
                      formatMoney(o['total'] ?? 0),
                      style: AppType.style(
                        12.5,
                        color: AppColors.accent,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _pill(String label, bool hot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: hot ? AppColors.warning.withOpacity(0.14) : AppColors.bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: hot ? AppColors.warning.withOpacity(0.4) : AppColors.line,
        ),
      ),
      child: Text(
        label,
        style: AppType.style(
          11.5,
          color: hot ? AppColors.warning : AppColors.muted,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminAds extends StatefulWidget {
  const _AdminAds();
  @override
  State<_AdminAds> createState() => _AdminAdsState();
}

class _AdminAdsState extends State<_AdminAds> {
  List ads = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/admin/ads');
      ads = (d['ads'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(int id, String action) async {
    try {
      await Api.post('/api/admin/ads/$id/decision', {'action': action});
      toast(context, action == 'approve' ? 'انقبل الإعلان ✓' : 'انرفض الإعلان');
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ads.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 200),
                EmptyState(icon: '📣', title: 'لا إعلانات'),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final ad = Map<String, dynamic>.from(ads[i] as Map);
                final pending = ad['status'] == 'pending';
                return GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ad['title'] ?? '',
                              style: AppType.style(
                                13.5,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StatusChip(ad['status'] ?? ''),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ad['store_name'] ?? ''} · ${ad['days'] ?? 0} يوم · ${formatMoney(ad['amount'] ?? 0)}',
                        style: AppType.style(11, color: AppColors.muted),
                      ),
                      if (pending) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SolidBtn(
                                label: 'قبول ✓',
                                onTap: () => decide(ad['id'], 'approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SolidBtn(
                                label: 'رفض ✕',
                                color: AppColors.danger,
                                onTap: () => decide(ad['id'], 'reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _AdminCash extends StatefulWidget {
  const _AdminCash();
  @override
  State<_AdminCash> createState() => _AdminCashState();
}

class _AdminCashState extends State<_AdminCash> {
  List reports = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/admin/cash');
      reports = (d['reports'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(int id, String action) async {
    try {
      await Api.post('/api/admin/cash/$id/decision', {'action': action});
      toast(context, action == 'approve' ? 'انقبل التقرير ✓' : 'انرفض التقرير');
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: reports.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 200),
                EmptyState(icon: '💵', title: 'لا تقارير كاش'),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = Map<String, dynamic>.from(reports[i] as Map);
                final pending = r['status'] == 'pending';
                return GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تقرير ${r['courier_name'] ?? ''}',
                              style: AppType.style(
                                13.5,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StatusChip(r['status'] ?? ''),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'المبلغ: ${formatMoney(r['amount'] ?? 0)} · ${r['order_count'] ?? 0} طلب · ${timeAgo(r['created_at'] ?? '')}',
                        style: AppType.style(11.5, color: AppColors.muted),
                      ),
                      if (pending) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SolidBtn(
                                label: 'قبول ✓',
                                onTap: () => decide(r['id'], 'approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SolidBtn(
                                label: 'رفض ✕',
                                color: AppColors.danger,
                                onTap: () => decide(r['id'], 'reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _AdminStores extends StatefulWidget {
  const _AdminStores();
  @override
  State<_AdminStores> createState() => _AdminStoresState();
}

class _AdminStoresState extends State<_AdminStores> {
  List stores = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/admin/stores');
      stores = (d['stores'] ?? []) as List;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> act(int id, String action) async {
    try {
      await Api.patch('/api/admin/stores/$id', {
        'status': action == 'approve' ? 'active' : 'suspended',
      });
      toast(context, 'تم التحديث');
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = Map<String, dynamic>.from(stores[i] as Map);
          final pending = s['status'] == 'pending';
          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    storeLogo(s['logo'] ?? '', size: 42, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['name'] ?? '',
                            style: AppType.style(13.5, weight: FontWeight.w900),
                          ),
                          Text(
                            '${s['category_name'] ?? ''} · ${s['district_name'] ?? ''}',
                            style: AppType.style(10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(s['status'] ?? ''),
                  ],
                ),
                if (pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SolidBtn(
                          label: 'تفعيل ✓',
                          onTap: () => act(s['id'], 'approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SolidBtn(
                          label: 'تعليق ✕',
                          color: AppColors.danger,
                          onTap: () => act(s['id'], 'suspend'),
                        ),
                      ),
                    ],
                  ),
                ] else if (s['status'] == 'active') ...[
                  const SizedBox(height: 10),
                  SolidBtn(
                    label: 'تعليق المتجر',
                    color: AppColors.danger,
                    onTap: () => act(s['id'], 'suspend'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
