import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// الإطلالة الكاملة — «نسّق لي هذه القطعة ✨»
/// شريط مناسبات + ميزانية، وكل قطعة قابلة للتبديل ببدائلها، ثم إضافة الكل للسلة
class OutfitScreen extends StatefulWidget {
  final int productId;
  final String seedName;
  final String? seedImage;
  const OutfitScreen({
    super.key,
    required this.productId,
    this.seedName = '',
    this.seedImage,
  });

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  dynamic data;
  bool loading = true;
  String occasion = 'casual';
  int budget = 0;

  static const occasions = [
    ('casual', 'كاجوال 😎'),
    ('work', 'دوام 💼'),
    ('formal', 'رسمية 🤵'),
    ('sport', 'رياضية ⚽'),
  ];
  static const budgets = [
    (0, 'بدون حد'),
    (100000, 'حتى 100 آلاف'),
    (200000, 'حتى 200 ألف'),
    (400000, 'حتى 400 ألف'),
  ];

  static const roleLabels = {
    'top': 'القطعة العلوية',
    'bottom': 'البنطلون',
    'shoes': 'الحذاء',
    'outerwear': 'جاكيت / بليزر',
    'watch': 'ساعة',
    'bag': 'حقيبة',
    'fragrance': 'عطر',
    'hat': 'إكسسوار رأس',
    'accessory': 'إكسسوار',
    'other': 'مكملات',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final d = await Api.get(
        '/api/outfit/${widget.productId}?occasion=$occasion&budget=$budget',
      );
      if (mounted) setState(() => data = d);
    } catch (_) {
      if (mounted)
        toast(context, 'ما صار نجلب الإطلالة — جرب مرة ثانية', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _replaceSlot(int slotIdx, Map alt) {
    setState(() {
      final slots = (data['outfit']['slots'] as List);
      slots[slotIdx] = alt;
      final total = slots.fold<int>(
        0,
        (s, x) => s + ((x['price'] ?? 0) as num).toInt(),
      );
      data['outfit']['total'] = total;
    });
  }

  Future<void> _addAllToCart() async {
    final slots = (data['outfit']['slots'] as List).cast<Map>();
    if (!Api.logged) {
      final keep = slots.where((s) => s['seed'] == true).toList();
      if (keep.isEmpty) {
        toast(context, 'سجل دخولك أول حتى نضيف الإطلالة', error: true);
        return;
      }
      toast(context, 'الإطلالة جاهزة — سجل دخولك لإضافة كل القطع', error: true);
      return;
    }
    var added = 0;
    for (final s in slots) {
      try {
        await Api.post('/api/customer/cart', {'product_id': s['id'], 'qty': 1});
        added++;
      } catch (_) {}
    }
    if (!mounted) return;
    if (added > 0) {
      HapticFeedback.lightImpact();
      addPop(
        context,
        'انضافت الإطلالة للسلة',
        img: widget.seedImage,
        sub: '$added قطع من متاجر مختلفة',
      );
      Navigator.pop(context, true);
    } else {
      toast(context, 'ما انضافت القطع — جرب مرة ثانية', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: A.bg,
      appBar: AppBar(
        title: const Text(
          'نسّق لي ✨',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (data != null && (data['outfit']['fit'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F9B58), Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'توافق ${data['outfit']['fit']}/100',
                    style: A.t(11.5, c: Colors.white, w: FontWeight.w900),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Loader()
          : data == null
          ? const EmptyState(icon: '😕', title: 'تعذر تحميل الإطلالة')
          : _body(),
      bottomNavigationBar: data == null || loading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: A.line)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'إجمالي الإطلالة',
                          style: A.t(10, c: A.muted, w: FontWeight.w700),
                        ),
                        Text(
                          money((data['outfit']['total'] ?? 0) as num),
                          style: A.t(18, c: A.ink, w: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Expanded(
                      child: SolidBtn(
                        label: 'أضف الإطلالة للسلة 🛒',
                        color: A.accent,
                        haptic: true,
                        onTap: _addAllToCart,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body() {
    final o = data['outfit'];
    final slots = (o['slots'] as List).cast<Map>();
    final alternates = (o['alternates'] ?? {}) as Map;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── الفلاتر: المناسبة + الميزانية ──
        _chipRow(
          occasions.map((e) => (e.$1, e.$2)).toList(),
          occasion,
          (v) => setState(() {
            occasion = v;
            _load();
          }),
        ),
        const SizedBox(height: 8),
        _chipRow(
          budgets.map((e) => ('${e.$1}', e.$2)).toList(),
          '$budget',
          (v) => setState(() {
            budget = int.tryParse(v) ?? 0;
            _load();
          }),
        ),
        const SizedBox(height: 14),
        // ── البذرة ──
        _slotCard(slots.first, 0, showReplace: false, alternates: const []),
        if (slots.length == 1) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: A.line),
            ),
            child: Text(
              'هذه القطعة من خارج الأزياء — التنسيق متاح للملابس والأحذية والإكسسوارات حالياً 🌱',
              style: A.t(13, c: A.muted, w: FontWeight.w700),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          for (var i = 1; i < slots.length; i++) ...[
            _slotCard(
              slots[i],
              i,
              showReplace: true,
              alternates: alternates[slots[i]['role']] as List? ?? [],
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (data['quality'] != null && slots.length > 1) ...[
          const SizedBox(height: 8),
          _qualityCard(),
        ],
        const SizedBox(height: 6),
        Center(
          child: Text(
            'الإطلالة من متاجر مختلفة — تنضاف كل قطعة لمتجرها وتوصل بمجموعة وحدة 🛵',
            style: A.t(10.5, c: A.muted, w: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _chipRow(
    List<(String, String)> items,
    String selected,
    void Function(String) onPick,
  ) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (val, label) in items)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => onPick(val),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == val ? A.primary : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected == val ? A.primary : A.line,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    label,
                    style: A.t(
                      11.5,
                      c: selected == val ? Colors.white : A.ink,
                      w: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slotCard(
    Map s,
    int idx, {
    required bool showReplace,
    List alternates = const [],
  }) {
    final isSeed = s['seed'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSeed ? A.primary.withValues(alpha: .5) : A.line,
          width: isSeed ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          productImage('${s['image'] ?? ''}', size: 64, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleLabels[s['role']] ?? 'قطعة',
                  style: A.t(10.5, c: A.primary, w: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s['name'] ?? ''}',
                  style: A.t(13.5, c: A.ink, w: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${s['store_name'] ?? ''}',
                  style: A.t(10.5, c: A.muted, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      money((s['price'] ?? 0) as num),
                      style: A.t(15, c: A.accent, w: FontWeight.w900),
                    ),
                    const Spacer(),
                    if ((s['color'] ?? '').toString().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: A.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${s['color']}',
                          style: A.t(9.5, c: A.primary, w: FontWeight.w800),
                        ),
                      ),
                    if (((s['rating'] ?? 0) as num) > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: A.star,
                          ),
                          Text(
                            ((s['rating'] as num)).toStringAsFixed(1),
                            style: A.t(10, c: A.ink, w: FontWeight.w800),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (showReplace && alternates.isNotEmpty)
            GestureDetector(
              onTap: () => _pickAlternate(idx, s['role'], alternates),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: A.bg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: A.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 15,
                      color: A.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'بدّل',
                      style: A.t(10.5, c: A.primary, w: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAlternate(int idx, String role, List alternates) async {
    final picked = await showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'بدائل ${roleLabels[role] ?? ''}',
                    style: A.t(16, w: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              for (final a in alternates)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx, a);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: A.line),
                    ),
                    child: Row(
                      children: [
                        productImage(
                          '${a['image'] ?? ''}',
                          size: 48,
                          radius: 12,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['name'] ?? ''}',
                                style: A.t(12.5, w: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${a['store_name'] ?? ''}',
                                style: A.t(10, c: A.muted, w: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money((a['price'] ?? 0) as num),
                          style: A.t(13.5, c: A.accent, w: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked is Map) _replaceSlot(idx, picked);
  }

  Widget _qualityCard() {
    final q = data['quality'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: A.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل جودة القطعة الأساسية 🔍',
            style: A.t(13, w: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _qItem('الجودة', q['quality']),
              _qItem('القيمة مقابل السعر', q['value']),
              _qItem('التوافق مع اختيارك', data['outfit']['fit']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qItem(String label, dynamic val) {
    final v = (val ?? 0) as num;
    return Expanded(
      child: Column(
        children: [
          Text(
            '${v.round()}/100',
            style: A.t(
              16,
              c: v >= 80
                  ? A.success
                  : v >= 60
                  ? A.primary
                  : A.danger,
              w: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: A.t(9.5, c: A.muted, w: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
