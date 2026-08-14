import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/points/screens/interactive_wheel.dart';

/// نقطة الولاء 🎯 + دعوة الأصدقاء + عجلة الحظ
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});
  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  dynamic data;
  dynamic referral;
  bool spinning = false;
  bool spinnedToday = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/customer/points');
      if (!mounted) return;
      setState(() => data = d);
    } catch (_) {}
    try {
      final r = await Api.get('/api/customer/referral');
      if (!mounted) return;
      setState(() => referral = r);
    } catch (_) {}
    try {
      final s = await Api.get('/api/customer/spin/status');
      if (!mounted) return;
      setState(() => spinnedToday = s['used_today'] == true);
    } catch (_) {}
  }

  Future<void> _spin() async {
    setState(() => spinning = true);
    try {
      final d = await Api.post('/api/customer/spin');
      if (!mounted) return;
      setState(() {
        spinning = false;
        spinnedToday = true;
      });
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => InteractiveWheelDialog(
          pointsWon: d['points'] ?? 0,
          onFinish: () => _load(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => spinning = false);
      toast(context, '$e', error: true);
    }
  }

  Future<void> _share(String code) async {
    try {
      await Share.share('انضمِّ إلى زبون عبر رمزي $code واكسب نقاط ولاء 🎁');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final points = (data?['balance'] ?? Api.me?['points'] ?? 0) as num;
    final txns = (data?['transactions'] ?? []) as List;
    final code = (referral?['code'] ?? Api.me?['referral_code'] ?? '')
        .toString();

    return Scaffold(
      appBar: AppBar(title: const ScreenTitle(Icons.stars_rounded, 'نقاطي وهداياي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          // البطاقة الرئيسية
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppColors.gradNavy,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(
                  '$points',
                  style: AppType.style(
                    40,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
                Text(
                  'نقطة ولاء',
                  style: AppType.style(
                    13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'كل 100 نقطة = 1000 د.ع خصم بالطلب',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // عجلة الحظ
          GlassCard(
            onTap: spinnedToday ? null : _spin,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spinnedToday ? 'جرب الدور بكرة' : 'عجلة الحظ 🎡',
                        style: AppType.style(14, weight: FontWeight.w900),
                      ),
                      Text(
                        spinnedToday
                            ? 'وصلت لأقصى دور اليوم — ارجع بكرة'
                            : 'دير العجلة واكسب حتى 200 نقطة!',
                        style: AppType.style(11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (spinning)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (!spinnedToday)
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
          // كود الدعوة
          if (code.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.group_add_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'دعوة أصدقاء 👭',
                          style: AppType.style(14, weight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'شارك كودك — كل صديق ينضم باخوك ينوب الجميع نقاط لولاء',
                      style: AppType.style(11.5, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(left: 12, bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            code,
                            textAlign: TextAlign.center,
                            style: AppType.style(
                              16,
                              color: AppColors.primary,
                              weight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          bottom: 14,
                        ),
                        child: SizedBox(
                          width: 120,
                          child: SolidBtn(
                            label: 'شارك',
                            onTap: () => _share(code),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'كيف تربح النقاط؟ 🎯',
            style: AppType.style(
              13,
              color: AppColors.muted,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                _howRow(
                  Icons.receipt_long_rounded,
                  'من طلباتك',
                  'كل 1000 د.ع قيمة طلب = 1 نقطة تتصلك أوتوماتيك بعد التسليم',
                  AppColors.primary,
                ),
                const Divider(height: 18),
                _howRow(
                  Icons.casino_rounded,
                  'عجلة الحظ',
                  'دور يومياً واكسب حتى 200 نقطة مجاناً',
                  AppColors.warning,
                ),
                const Divider(height: 18),
                _howRow(
                  Icons.group_add_rounded,
                  'دعوة الأصدقاء',
                  'كل صديق يسجل برمزك: ${(referral?['points_referrer'] ?? 100)} نقطة لك و${(referral?['points_new'] ?? 50)} له',
                  AppColors.success,
                ),
                const Divider(height: 18),
                _howRow(
                  Icons.wallet_giftcard_rounded,
                  'استبدال الخصم',
                  'كل ${data?['rate'] ?? 100} نقطة = 1000 د.ع خصم من طلبك الجاي',
                  AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'سجل النقاط 🧾',
            style: AppType.style(
              13,
              color: AppColors.muted,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (txns.isEmpty)
            const EmptyState(icon: '🪙', title: 'لا حركة نقاط بعد')
          else
            for (final t in txns)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color:
                            ((t['points'] ?? 0) > 0
                                    ? AppColors.primary
                                    : AppColors.danger)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        (t['points'] ?? 0) > 0
                            ? Icons.add_rounded
                            : Icons.remove_rounded,
                        color: (t['points'] ?? 0) > 0
                            ? AppColors.primary
                            : AppColors.danger,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['note'] ?? t['type'] ?? '',
                            style: AppType.style(12.5, weight: FontWeight.w700),
                          ),
                          Text(
                            _date(t['created_at']),
                            style: AppType.style(10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(t['points'] ?? 0) > 0 ? '+' : ''}${t['points']}',
                      style: AppType.style(
                        14,
                        weight: FontWeight.w900,
                        color: (t['points'] ?? 0) > 0
                            ? AppColors.primary
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _howRow(
    IconData icon,
    String title,
    String sub,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.style(12.5, weight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                sub,
                style: AppType.style(10.5, color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _date(dynamic s) {
    try {
      return DateTime.parse(s).toLocal().toString().split(' ').first;
    } catch (_) {
      return '';
    }
  }
}
