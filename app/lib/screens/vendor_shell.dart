import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../map_screen.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders_screen.dart';

/// واجهة التاجر: الطلبات · المنتجات · المحفظة · متجري
class VendorShell extends StatefulWidget {
  final VoidCallback onExit;
  const VendorShell({super.key, required this.onExit});
  @override
  State<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<VendorShell> {
  int tab = 0;
  final pageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('واجهة التاجر 🏪'),
        actions: [
          IconButton(onPressed: widget.onExit, icon: const Icon(Icons.exit_to_app_rounded, color: A.muted), tooltip: 'رجوع لحسابي'),
        ],
      ),
      body: IndexedStack(
        key: pageKey,
        index: tab,
        children: [
          OrderListScreen(role: 'vendor', embedded: true),
          _ProductsTab(),
          _WalletTab(role: 'vendor'),
          _StoreTab(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        index: tab,
        items: const [
          (Icons.receipt_long_rounded, 'الطلبات'),
          (Icons.inventory_2_rounded, 'المنتجات'),
          (Icons.account_balance_wallet_rounded, 'المحفظة'),
          (Icons.storefront_rounded, 'متجري'),
        ],
        onTap: (i) => setState(() => tab = i),
      ),
    );
  }
}

/* ═══════════ منتجات المتجر ═══════════ */
class _ProductsTab extends StatefulWidget {
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  List products = [];
  dynamic store;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/vendor/store');
      store = d['store'];
      products = (d['store']['products'] ?? d['products'] ?? []) as List;
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addProduct([Map? edit]) async {
    final name = TextEditingController(text: edit?['name'] ?? '');
    final price = TextEditingController(text: edit != null ? '${edit['price'] ?? ''}' : '');
    final desc = TextEditingController(text: edit?['description'] ?? '');
    final stock = TextEditingController(text: edit != null ? '${edit['stock'] ?? ''}' : '10');
    final offer = TextEditingController(text: (edit != null && (edit['has_offer'] == true || edit['has_offer'] == 1)) ? '${edit['offer_price'] ?? ''}' : '');
    final imgs = List<String>.from(edit?['images'] ?? []);
    final attrCtrls = <String, TextEditingController>{};
    // الألوان والمقاسات — صف لكل تركيبة (لون + مقاس + كمية)
    final vrows = <Map<String, dynamic>>[
      for (final v in (edit?['variants'] as List? ?? []))
        {
          if (v['id'] != null) 'id': v['id'],
          'color': TextEditingController(text: '${v['color'] ?? ''}'),
          'name': TextEditingController(text: '${v['name'] ?? ''}'),
          'stock': TextEditingController(text: '${v['stock'] ?? '0'}'),
        },
    ];
    int? catId = edit?['category_id'] != null ? (edit?['category_id'] as num).toInt() : null;
    List allCats = [];
    List allAttrs = [];

    try {
      final c = await Api.get('/api/categories');
      allCats = c['categories'] ?? [];
      allAttrs = c['attrs'] ?? [];
    } catch (_) {}

    // تعبئة السمات إذا كان تعديلاً — بلا المقاس/اللون (صاروا متغيرات)
    if (edit != null && catId != null) {
      for (final a in allAttrs.where((a) => (a['category_id'] as num).toInt() == catId && !['size', 'color'].contains(a['key']))) {
        attrCtrls[a['key']] = TextEditingController(text: '${(edit['attributes'] ?? {})[a['key']] ?? ''}');
      }
    }

    await showSheet(context, StatefulBuilder(
      builder: (context, setS) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetTitle(edit != null ? 'تعديل المنتج ✏️' : 'إضافة منتج ➕'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(children: [
              // ═══ صور المنتج (من معرض الجهاز) ═══
              Row(children: [
                const Text('صور المنتج', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${imgs.length}/8', style: TextStyle(fontSize: 11, color: A.muted, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final u in imgs) ...[
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(width: 72, height: 72, child: productImageBox(u, base: Api.base)),
                      ),
                      Positioned(top: 2, left: 2, child: GestureDetector(
                        onTap: () => setS(() => imgs.remove(u)),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close, size: 13, color: Colors.white)),
                        ),
                      )),
                    ]),
                    const SizedBox(width: 8),
                  ],
                  if (imgs.length < 8)
                    GestureDetector(
                      onTap: () async {
                        try {
                          final files = await ImagePicker().pickMultiImage(limit: 8 - imgs.length, imageQuality: 82, maxWidth: 1600);
                          if (files.isEmpty) return;
                          setS(() => imgs.addAll(List.generate(files.length, (i) => '⏳${i + files.length}')));
                          final out = <Uint8List>[];
                          for (final f in files) {
                            final bytes = await f.readAsBytes();
                            // قصّ الصورة قبل الرفع
                            final cropped = await cropImage(context, bytes, aspect: 1, title: 'قصّ صورة المنتج ✂️');
                            if (cropped != null) out.add(cropped);
                          }
                          final urls = await Api.uploadBytes(out);
                          setS(() {
                            imgs.removeWhere((u) => u.startsWith('⏳'));
                            imgs.addAll(urls);
                          });
                        } catch (e) {
                          toast(context, 'فشل رفع الصور: $e', error: true);
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(color: A.primary, width: 1.4),
                          borderRadius: BorderRadius.circular(12),
                          color: A.primary.withOpacity(0.06),
                        ),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, color: A.primary, size: 20),
                          SizedBox(height: 2),
                          Text('أضف صور', style: TextStyle(fontSize: 9.5, color: A.primary, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                value: catId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('بدون قسم')),
                  ...allCats.map((c) => DropdownMenuItem<int?>(value: (c['id'] as num).toInt(), child: Text('${c['icon'] ?? ''} ${c['name']}'))),
                ],
                onChanged: (v) => setS(() {
                  catId = v;
                  attrCtrls.clear();
                  for (final a in allAttrs.where((a) => (a['category_id'] as num).toInt() == catId)) {
                    attrCtrls[a['key']] = TextEditingController();
                  }
                }),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (د.ع)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: offer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر العرض (اختياري)')),
              const SizedBox(height: 10),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'الوصف'), maxLines: 2),
              const SizedBox(height: 14),
              // ═══ الألوان والمقاسات — صف لكل تركيبة: لون + مقاس + كمية ═══
              Row(children: [
                Text('الألوان والمقاسات', style: A.t(12.5, w: FontWeight.w900)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setS(() => vrows.add({
                    'color': TextEditingController(),
                    'name': TextEditingController(),
                    'stock': TextEditingController(text: '10'),
                  })),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: A.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('+ أضف', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              for (final row in vrows) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: row['color'],
                        decoration: const InputDecoration(labelText: 'اللون (أحمر/أسود) — اتركه فاضي لو ماكو'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 82,
                      child: TextField(
                        controller: row['name'],
                        decoration: const InputDecoration(labelText: 'المقاس'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 66,
                      child: TextField(
                        controller: row['stock'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الكمية'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setS(() => vrows.remove(row)),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 0, 0),
                        child: Icon(Icons.close, size: 18, color: A.danger),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 6),
              // حقول السمات حسب القسم — ما عدا المقاس واللون (صاروا عن طريق المتغيرات)
              if (catId != null)
                ...allAttrs
                    .where((a) => (a['category_id'] as num).toInt() == catId && !['size', 'color'].contains(a['key']))
                    .map((a) {
                  final ctrl = attrCtrls[a['key']]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: a['type'] == 'select'
                        ? DropdownButtonFormField<String?>(
                            value: null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: '${a['label']}${a['required'] == true ? ' *' : ''}'),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: const Text('اختر...')),
                              ...(a['options'] as List).map((o) => DropdownMenuItem<String?>(value: '$o', child: Text('$o'))),
                            ],
                            onChanged: (v) => setS(() => ctrl.text = v ?? ''),
                          )
                        : TextField(controller: ctrl, decoration: InputDecoration(labelText: '${a['label']}${a['required'] == true ? ' *' : ''}')),
                  );
                }),
              const SizedBox(height: 16),
              SolidBtn(label: 'حفظ', onTap: () async {
                if (name.text.isEmpty) return;
                final attributes = <String, String>{};
                if (catId != null) {
                  // بلا المقاس/اللون (صاروا متغيرات منتج)
                  for (final a in allAttrs.where((a) => (a['category_id'] as num).toInt() == catId && !['size', 'color'].contains(a['key']))) {
                    final v = attrCtrls[a['key']]?.text.trim() ?? '';
                    if (a['required'] == true && v.isEmpty) {
                      toast(context, 'أكمل حقل ${a['label']}', error: true);
                      return;
                    }
                    if (v.isNotEmpty && !['size', 'color'].contains(a['key'])) attributes[a['key']] = v;
                  }
                }
                try {
                  final body = <String, dynamic>{
                    'name': name.text,
                    'price': double.tryParse(price.text) ?? 0,
                    'stock': int.tryParse(stock.text) ?? 1,
                    'description': desc.text,
                    'category_id': catId,
                    'attributes': attributes,
                    if (imgs.isNotEmpty) 'images': imgs,
                    'has_offer': offer.text.isNotEmpty,
                    if (offer.text.isNotEmpty) 'offer_price': double.tryParse(offer.text) ?? 0,
                    if (vrows.isNotEmpty)
                      'variants': [
                        for (final row in vrows)
                          {
                            if (row['id'] != null) 'id': row['id'],
                            'color': row['color']!.text.trim(),
                            'name': row['name']!.text.trim().isEmpty ? 'قياسي' : row['name']!.text.trim(),
                            'stock': int.tryParse(row['stock']!.text.trim()) ?? 0,
                          },
                      ],
                  };
                  if (edit == null) {
                    await Api.post('/api/vendor/products', body);
                    toast(context, 'انضاف المنتج ✓');
                  } else {
                    await Api.patch('/api/vendor/products/${edit['id']}', body);
                    toast(context, 'انعدّل المنتج ✓');
                  }
                  Navigator.pop(context);
                  _load();
                } on ApiException catch (e) {
                  toast(context, e.message, error: true);
                }
              }),
            ]),
          ),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: A.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            Row(children: [
              Text('منتجاتي (${products.length})', style: A.t(15, w: FontWeight.w900)),
              const Spacer(),
              SolidBtn(label: '+ منتج', color: A.primary, onTap: addProduct),
            ]),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const EmptyState(icon: '📦', title: 'ما عندك منتجات')
            else
              // شبكة بطاقات مثل تصميم صفحة الزبون
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
                childAspectRatio: 0.52,
                children: [
                  for (final p in products) _VendorProdCard(
                    p: Map<String, dynamic>.from(p as Map),
                    onEdit: () => addProduct(Map<String, dynamic>.from(p)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة المنتج في صفحة التاجر — مطابقة لتصميم شبكة الزبون
class _VendorProdCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onEdit;
  const _VendorProdCard({required this.p, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasOffer = p['has_offer'] == true || p['has_offer'] == 1;
    final outOfStock = (p['stock'] ?? 0) == 0;
    final price = double.tryParse('${p['price'] ?? 0}') ?? 0;
    final offerPrice = double.tryParse('${p['offer_price'] ?? 0}') ?? 0;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(color: A.surface),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(fit: StackFit.expand, children: [
              productImageBox(p['image'], base: Api.base),
              if (hasOffer)
                Positioned(
                  top: 8, right: 8,
                  child: _OfferBadge('خصم ${price > 0 && offerPrice > 0 ? (((price - offerPrice) / price) * 100).round() : 0}%'),
                ),
              if (outOfStock)
                Positioned(top: 8, left: 8, child: _OfferBadge('نفد', dark: true)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name'] ?? ''}', style: A.t(11, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (hasOffer && offerPrice > 0) ...[
                const SizedBox(height: 2),
                Text(money(price), style: A.t(9.5, c: A.muted, decoration: TextDecoration.lineThrough)),
              ],
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(
                    hasOffer && offerPrice > 0 ? money(offerPrice) : money(price),
                    style: A.t(13.5, c: A.accent, w: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: A.primary, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: hasOffer ? A.accent.withOpacity(0.12) : A.bg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: hasOffer ? A.accent : A.line, width: 1),
                ),
                child: GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    hasOffer ? 'إدارة العرض 🔥' : 'فعّل عرض 🌟',
                    textAlign: TextAlign.center,
                    style: A.t(9.5, c: hasOffer ? A.accent : A.muted, w: FontWeight.w800),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// شارة صغيرة فوق صورة المنتج (عرض/نفاد)
class _OfferBadge extends StatelessWidget {
  final String label;
  final bool dark;
  const _OfferBadge(this.label, {this.dark = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? Colors.black87 : A.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

/* ═══════════ المحفظة ═══════════ */
class _WalletTab extends StatefulWidget {
  final String role;
  const _WalletTab({required this.role});
  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  dynamic w;
  List tx = [];
  int weekNet = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ep = widget.role == 'vendor' ? '/api/vendor/wallet' : '/api/delivery/wallet';
      final d = await Api.get(ep);
      w = d['wallet'];
      tx = (d['transactions'] ?? []) as List;
      if (widget.role == 'vendor') {
        final ws = await Api.get('/api/vendor/week-earnings');
        weekNet = ((ws['net_due'] ?? 0) as num).toInt();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> withdraw() async {
    final amt = TextEditingController();
    await showSheet(context, StatefulBuilder(
      builder: (context, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetTitle('سحب رصيد 💸'),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (د.ع)')),
            const SizedBox(height: 14),
            SolidBtn(label: 'اطلب السحب', onTap: () async {
              try {
                await Api.post('/api/vendor/wallet/withdraw', {'amount': double.tryParse(amt.text) ?? 0});
                toast(context, 'انرسل طلب السحب للأدمن ✓');
                Navigator.pop(context);
              } on ApiException catch (e) {
                toast(context, e.message, error: true);
              }
            }),
          ]),
        ),
      ]),
    ));
  }

  Future<void> requestAd() async {
    List packages = [];
    try {
      final res = await Api.get('/api/vendor/ad-packages');
      packages = (res['packages'] ?? []) as List;
    } catch (_) {}
    if (packages.isEmpty) {
      if (!mounted) return;
      toast(context, 'لا توجد باقات متاحة حالياً', error: true);
      return;
    }

    final title = TextEditingController();
    int? selectedPkg = packages.first['id'];
    Uint8List? adImageBytes;

    if (!mounted) return;
    await showSheet(context, StatefulBuilder(
      builder: (context, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetTitle('إعلان لمتجري 📣'),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'نص الإعلان (مثال: خصم 50%)')),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setS(() => adImageBytes = bytes);
                }
              },
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: A.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: A.line, width: 1.2),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: adImageBytes == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_rounded, color: A.primary, size: 26),
                        SizedBox(height: 4),
                        Text('صورة الإعلان (اختياري)', style: TextStyle(fontSize: 11, color: A.muted, fontWeight: FontWeight.w700)),
                      ])
                    : Stack(fit: StackFit.expand, children: [
                        Image.memory(adImageBytes!, fit: BoxFit.cover),
                        Positioned(
                          top: 6, left: 6,
                          child: GestureDetector(
                            onTap: () => setS(() => adImageBytes = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('اختر باقة الإعلان', style: A.t(13, w: FontWeight.w800)),
            const SizedBox(height: 8),
            ...packages.map((p) => RadioListTile<int>(
              title: Text('${p['days']} أيام', style: A.t(14, w: FontWeight.w800)),
              subtitle: Text(money(p['price']), style: A.t(12, c: A.accent)),
              value: p['id'],
              groupValue: selectedPkg,
              activeColor: A.primary,
              onChanged: (v) => setS(() => selectedPkg = v),
            )),
            const SizedBox(height: 14),
            SolidBtn(label: 'ترويج الآن 🚀', onTap: () async {
              if (title.text.isEmpty) return;
              try {
                var imageUrl = '';
                if (adImageBytes != null) {
                  final urls = await Api.uploadBytes([adImageBytes!]);
                  imageUrl = urls.isNotEmpty ? urls.first : '';
                }
                await Api.post('/api/vendor/ads', {'title': title.text, 'package_id': selectedPkg, if (imageUrl.isNotEmpty) 'image': imageUrl});
                if (!mounted) return;
                toast(context, 'تم تفعيل الإعلان بنجاح ✓');
                Navigator.pop(context);
                _load();
              } on ApiException catch (e) {
                toast(context, e.message, error: true);
              }
            }),
          ]),
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    final balance = (w?['balance'] ?? 0) as num;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(gradient: A.gradNavy, borderRadius: BorderRadius.all(Radius.circular(22))),
            child: Column(children: [
              const Text('رصيد محفظتك', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(money(balance), style: A.t(30, c: Colors.white, w: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: SolidBtn(
                    label: widget.role == 'vendor' ? 'سحب 💸' : 'تقرير كاش 💵',
                    onTap: widget.role == 'vendor' ? withdraw : _cashReport,
                  ),
                ),
                if (widget.role == 'vendor') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SolidBtn(label: 'إعلان 📣', color: A.primaryLight, onTap: requestAd),
                  ),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (widget.role == 'vendor') ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: A.success.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_today_rounded, color: A.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مستحقاتك هذا الأسبوع', style: A.t(12, c: A.muted)),
                  const SizedBox(height: 2),
                  Text('بعد خصم عمولة المنصة', style: A.t(10, c: A.muted)),
                ])),
                Text(money(weekNet), style: A.t(16, c: A.success, w: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          Text('الحركات', style: A.t(14, w: FontWeight.w900)),
          const SizedBox(height: 8),
          if (tx.isEmpty)
            const EmptyState(icon: '🧾', title: 'لا حركات بعد')
          else
            for (final t in tx) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (t['type'] == 'credit') ? A.success.withOpacity(0.1) : A.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon((t['type'] == 'credit') ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: (t['type'] == 'credit') ? A.success : A.danger, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['note'] ?? '', style: A.t(12.5)),
                    Text(timeAgo(t['created_at'] ?? ''), style: A.t(10, c: A.muted)),
                  ])),
                  Text('${t['type'] == 'credit' ? '+' : '-'} ${money(t['amount'] ?? 0)}',
                      style: A.t(13, c: (t['type'] == 'credit') ? A.success : A.danger, w: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _cashReport() async {
    final amt = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تقرير الكاش اليومي 💵'),
        content: TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'المبلغ المجموع اليوم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('/api/delivery/cash-report', {'amount': double.tryParse(amt.text) ?? 0});
      toast(context, 'انرسل التقرير للأدمن ✓');
      _load();
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    }
  }
}

/* ═══════════ متجري ═══════════ */
class _StoreTab extends StatefulWidget {
  @override
  State<_StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<_StoreTab> {
  dynamic store;
  dynamic stats;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/vendor/store');
      store = d['store'];
      stats = d['stats'] ?? {};
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editStore() async {
    final s = store as Map<String, dynamic>? ?? {};
    final name = TextEditingController(text: s['name'] ?? '');
    final desc = TextEditingController(text: s['description'] ?? '');
    final logo = TextEditingController(text: s['logo'] ?? '');
    final cover = TextEditingController(text: s['cover'] ?? '');
    final address = TextEditingController(text: s['address'] ?? '');
    final phone = TextEditingController(text: s['phone'] ?? '');
    final fee = TextEditingController(text: '${s['delivery_fee'] ?? 2000}');
    double? slat = (s['lat'] as num?)?.toDouble();
    double? slng = (s['lng'] as num?)?.toDouble();

    await showSheet(context, StatefulBuilder(
      builder: (context, setS) {
        // اختيار صورة من المعرض + قصّها ورفعها
        Future<void> pickAndSet(TextEditingController ctrl, String title, double aspect) async {
          try {
            final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
            if (f == null) return;
            final bytes = await f.readAsBytes();
            final cropped = await cropImage(context, bytes, aspect: aspect, title: title);
            if (cropped == null) return;
            final urls = await Api.uploadBytes([cropped]);
            if (urls.isNotEmpty && context.mounted) {
              setS(() => ctrl.text = urls.first);
              toast(context, 'انضافت الصورة ✓');
            }
          } catch (_) {
            toast(context, 'تعذر رفع الصورة', error: true);
          }
        }
        return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetTitle('تعديل معلومات المتجر ✏️'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المتجر')),
              const SizedBox(height: 10),
              // ── شعار المتجر (من الجهاز مع قصّ) ──
              Row(children: [
                const Expanded(child: Text('شعار المتجر 📸', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                TextButton.icon(
                  onPressed: () => pickAndSet(logo, 'قصّ الشعار ✂️', 1),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 17),
                  label: const Text('من المعرض'),
                ),
              ]),
              SizedBox(height: 56, width: double.infinity, child: productImageBox(logo.text, base: Api.base)),
              const SizedBox(height: 10),
              // ── صورة الغلاف ──
              Row(children: [
                const Expanded(child: Text('صورة الغلاف 🖼', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                TextButton.icon(
                  onPressed: () => pickAndSet(cover, 'قصّ الغلاف ✂️', 16 / 9),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 17),
                  label: const Text('من المعرض'),
                ),
              ]),
              SizedBox(height: 80, width: double.infinity, child: productImageBox(cover.text.startsWith('/') ? Api.base + cover.text : cover.text, base: Api.base)),
              const SizedBox(height: 10),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'وصف المتجر'), maxLines: 3),
              const SizedBox(height: 10),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 10),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'هاتف المتجر'), keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              TextField(controller: fee, decoration: const InputDecoration(labelText: 'رسوم التوصيل (د.ع)'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: A.primary, side: const BorderSide(color: A.primary, width: 1.2)),
                onPressed: () async {
                  final picked = await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => PickMapScreen(lat: slat, lng: slng)));
                  if (picked != null && picked is LatLng) {
                    setS(() {
                      slat = picked.latitude;
                      slng = picked.longitude;
                    });
                  }
                },
                icon: const Icon(Icons.map_rounded),
                label: Text(
                  slat != null ? 'الموقع محدد ✓ (${slat!.toStringAsFixed(4)}, ${slng!.toStringAsFixed(4)})' : 'حدد موقع المتجر على الخريطة 🗺',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              SolidBtn(label: 'حفظ', onTap: () async {
                try {
                  await Api.patch('/api/vendor/store', {
                    'name': name.text,
                    'description': desc.text,
                    'logo': logo.text,
                    'cover': cover.text,
                    'address': address.text,
                    'phone': phone.text,
                    'delivery_fee': int.tryParse(fee.text) ?? 2000,
                    if (slat != null) 'lat': slat,
                    if (slng != null) 'lng': slng,
                  });
                  toast(context, 'انحفظت المعلومات ✓');
                  Navigator.pop(context);
                  _load();
                } on ApiException catch (e) {
                  toast(context, e.message, error: true);
                }
              }),
            ]),
          ),
        ]),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Loader();
    final s = store as Map<String, dynamic>? ?? {};
    final coverUrl = (s['cover'] ?? '').toString();
    final hasCover = isUrlCover(coverUrl);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          // ═══ غلاف المتجر المستطيلي (16:9) ═══
          if (hasCover)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    productImageBox(coverUrl),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.65)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 64, height: 64,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: storeLogo(s['logo'] ?? '', size: 58, radius: 13),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(s['name'] ?? '', style: A.t(17, c: Colors.white, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (s['verified'] == true || s['verified'] == 1) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.verified_rounded, size: 16, color: A.primaryLight)),
                            ]),
                            const SizedBox(height: 2),
                            Text('${s['category_name'] ?? ''} · ${s['district_name'] ?? ''}', style: A.t(11, c: Colors.white70)),
                            const SizedBox(height: 5),
                            StatusChip(s['status'] ?? 'pending'),
                          ])),
                          IconButton(
                            onPressed: _editStore,
                            icon: const Icon(Icons.edit_rounded, color: Colors.white),
                            tooltip: 'تعديل معلومات المتجر',
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                child: Row(children: [
                  storeLogo(s['logo'] ?? '', size: 60),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(s['name'] ?? '', style: A.t(16, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (s['verified'] == true || s['verified'] == 1) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.verified_rounded, size: 16, color: A.primaryLight)),
                    ]),
                    Text('${s['category_name'] ?? ''} · ${s['district_name'] ?? ''}', style: A.t(11.5, c: A.muted)),
                    const SizedBox(height: 5),
                    StatusChip(s['status'] ?? 'pending'),
                  ])),
                  IconButton(
                    onPressed: _editStore,
                    icon: const Icon(Icons.edit_rounded, color: A.primary),
                    tooltip: 'تعديل معلومات المتجر',
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: MoneyBox(label: 'طلبات اليوم', value: '${stats['orders_today'] ?? 0}', icon: Icons.receipt_long_rounded, color: A.primary)),
              const SizedBox(width: 10),
              Expanded(child: MoneyBox(label: 'مبيعات اليوم', value: money(stats['sales_today'] ?? 0), icon: Icons.payments_rounded, color: A.success)),
            ]),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: MoneyBox(label: 'التقييم', value: '${stats['rating'] ?? 0} ⭐', icon: Icons.star_rounded, color: A.warning)),
              const SizedBox(width: 10),
              Expanded(child: MoneyBox(label: 'المنتجات', value: '${stats['products_count'] ?? 0}', icon: Icons.inventory_2_rounded, color: A.cyan)),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('عن المتجر', style: A.t(13, w: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(s['description'] ?? '', style: A.t(12.5, c: A.muted, h: 1.6)),
                const Divider(height: 22),
                Text('💰 عمولة المنصة: 10% من كل طلب — تخصم أوتوماتيك وتوصلك بالكاش.', style: A.t(11.5, c: A.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // الإجازة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: A.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.beach_access_rounded, color: A.warning, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إجازة المتجر 🏖', style: A.t(13.5, w: FontWeight.w900)),
                  Text(s['on_vacation'] == true ? 'متوقف مؤقتاً — لا يستقبل طلبات' : 'فاتح — يستقبل الطلبات', style: A.t(11, c: A.muted)),
                ])),
                Switch(
                  value: s['on_vacation'] == true,
                  activeColor: A.warning,
                  onChanged: (v) async {
                    try {
                      await Api.post('/api/vendor/store/vacation', {'on_vacation': v});
                      setState(() => s['on_vacation'] = v);
                      toast(context, v ? 'المتجر ويا إجازة' : 'المتجر رجع يشتغل');
                    } on ApiException catch (e) {
                      toast(context, e.message, error: true);
                    }
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          // الكوبونات
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CouponsCard(store: s),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('الطلبات المرتجعة', style: A.t(14, w: FontWeight.w900)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RefundsList(store: store),
          ),
          const SizedBox(height: 16),
          // أسئلة الزبائن (Q&A)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _QuestionsCard(),
          ),
        ],
      ),
    );
  }
}

/// بطاقة إدارة الكوبونات للتاجر
class _CouponsCard extends StatefulWidget {
  final Map store;
  const _CouponsCard({required this.store});
  @override
  State<_CouponsCard> createState() => _CouponsCardState();
}

class _CouponsCardState extends State<_CouponsCard> {
  List coupons = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/vendor/coupons');
      coupons = d['coupons'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final code = TextEditingController();
    final ff = TextEditingController();
    final minT = TextEditingController(text: '0');
    final maxD = TextEditingController(text: '0');
    bool isPercent = true;
    await showSheet(context, StatefulBuilder(
      builder: (context, setS2) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetTitle('كوبون جديد 🎟'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'كود الكوبون (مثال: SAVE10)')),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('نسبة %')),
                  ButtonSegment(value: false, label: Text('مبلغ ثابت')),
                ],
                selected: {isPercent},
                onSelectionChanged: (s) => setS2(() => isPercent = s.first),
              ),
              const SizedBox(height: 10),
              TextField(controller: ff, decoration: InputDecoration(labelText: isPercent ? 'الخصم %' : 'الخصم (د.ع)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: minT, decoration: const InputDecoration(labelText: 'الحد الأدنى (د.ع)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: maxD, decoration: const InputDecoration(labelText: 'سقف الخصم (د.ع) — 0 بدون سقف'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              SolidBtn(label: 'أنشئ', onTap: () async {
                try {
                  await Api.post('/api/vendor/coupons', {
                    'code': code.text,
                    if (isPercent) 'percent': int.tryParse(ff.text) ?? 0,
                    if (!isPercent) 'flat': int.tryParse(ff.text) ?? 0,
                    'min_total': int.tryParse(minT.text) ?? 0,
                    'max_discount': int.tryParse(maxD.text) ?? 0,
                  });
                  toast(context, 'انصاد الكوبون ✓');
                  Navigator.pop(context);
                  _load();
                } on ApiException catch (e) {
                  toast(context, e.message, error: true);
                }
              }),
            ]),
          ),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: A.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.local_activity_rounded, color: A.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('كوبونات الخصم 🎟', style: A.t(13.5, w: FontWeight.w900))),
            IconButton(onPressed: _add, icon: const Icon(Icons.add_circle_rounded, color: A.accent), tooltip: 'كوبون جديد'),
          ]),
        ),
        if (loading)
          const Padding(padding: EdgeInsets.all(20), child: Loader())
        else if (coupons.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text('لا كوبونات — انشئ أول كوبون لعملائك', style: TextStyle(color: A.muted, fontSize: 11.5)))
        else
          for (final c in coupons)
            ListTile(
              dense: true,
              title: Text('${c['code']}', style: A.t(12.5, w: FontWeight.w900, c: A.accent)),
              subtitle: Text(c['percent'] != null ? '${c['percent']}% خصم' : '${c['flat']} د.ع', style: A.t(11, c: A.muted)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: A.danger, size: 19),
                onPressed: () async {
                  try {
                    await Api.del('/api/vendor/coupons/${c['id']}');
                    _load();
                  } catch (_) {}
                },
              ),
            ),
      ]),
    );
  }
}

/// أسئلة الزبائن — إجابة التاجر
class _QuestionsCard extends StatefulWidget {
  const _QuestionsCard();
  @override
  State<_QuestionsCard> createState() => _QuestionsCardState();
}

class _QuestionsCardState extends State<_QuestionsCard> {
  List questions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/api/vendor/questions');
      questions = d['questions'] ?? [];
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: A.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.help_outline_rounded, color: A.cyan, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('أسئلة الزبائن 📩 (${questions.length})', style: A.t(13.5, w: FontWeight.w900))),
          ]),
        ),
        if (loading)
          const Padding(padding: EdgeInsets.all(20), child: Loader())
        else if (questions.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text('لا أسئلة بانتظار الجواب', style: TextStyle(color: A.muted, fontSize: 11.5)))
        else
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${q['user_name']} · ${q['product_name']}', style: A.t(10.5, c: A.muted)),
                  const SizedBox(height: 3),
                  Text('${q['question']}', style: A.t(12, w: FontWeight.w700)),
                ])),
                TextButton(
                  onPressed: () async {
                    final ans = TextEditingController();
                    await showSheet(context, StatefulBuilder(
                      builder: (context, setS2) => Column(mainAxisSize: MainAxisSize.min, children: [
                        const SheetTitle('ي جواب 💬'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(children: [
                            Text('${q['question']}', style: A.t(13), textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            TextField(controller: ans, decoration: const InputDecoration(labelText: 'جوابك'), maxLines: 3),
                            const SizedBox(height: 14),
                            SolidBtn(label: 'إرسال', onTap: () async {
                              try {
                                await Api.post('/api/vendor/questions/${q['id']}/answer', {'answer': ans.text});
                                toast(context, 'انراد الجواب ✓');
                                Navigator.pop(context);
                                _load();
                              } on ApiException catch (e) {
                                toast(context, e.message, error: true);
                              }
                            }),
                          ]),
                        ),
                      ]),
                    ));
                  },
                  child: const Text('أجب', style: TextStyle(fontWeight: FontWeight.w900, color: A.primary)),
                ),
              ]),
            ),
      ]),
    );
  }
}

/// قائمة الإرجاعات/الاستبدالات عند التاجر
class _RefundsList extends StatefulWidget {
  final dynamic store;
  const _RefundsList({required this.store});

  @override
  State<_RefundsList> createState() => _RefundsListState();
}

class _RefundsListState extends State<_RefundsList> {
  @override
  Widget build(BuildContext context) {
    final refunds = (widget.store?['refunds'] ?? []) as List;
    if (refunds.isEmpty)
      return const GlassCard(child: EmptyState(icon: '↩️', title: 'لا مرتجعات', sub: 'حالات الإرجاع من الزبائن تظهر هنا'));
    return Column(children: [
      for (final rf in refunds.cast<Map>()) ...[
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(rf['type'] == 'exchange' ? Icons.swap_horiz_rounded : Icons.replay_rounded,
                  size: 19, color: rf['type'] == 'exchange' ? A.accent : A.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('${rf['user_name'] ?? ''} — طلب ${rf['code'] ?? ''}', style: A.t(12.5, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
              _refundStatusChip('${rf['status'] ?? ''}'),
            ]),
            const SizedBox(height: 6),
            if ((rf['desired'] ?? '').toString().isNotEmpty)
              Text('البديل المطلوب: ${rf['desired']}', style: A.t(11.5, c: A.accent, w: FontWeight.w800)),
            Text('${rf['reason'] ?? ''}', style: A.t(11, c: A.muted)),
            if (rf['status'] == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Expanded(
                    child: SolidBtn(
                      label: rf['type'] == 'exchange' ? 'قبول الاستبدال 🔁' : 'قبول الإرجاع ✓',
                      onTap: () async {
                        try {
                          await Api.patch('/api/vendor/refunds/${rf['id']}', {'status': 'accepted'});
                          toast(context, rf['type'] == 'exchange' ? 'انقبل — المخزون رجع تلقائياً ✓' : 'انقبل الإرجاع ✓');
                          setState(() => rf['status'] = 'accepted');
                        } on ApiException catch (e) {
                          toast(context, e.message, error: true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SolidBtn(
                      label: 'رفض',
                      color: A.danger,
                      onTap: () async {
                        try {
                          await Api.patch('/api/vendor/refunds/${rf['id']}', {'status': 'rejected'});
                          toast(context, 'انرفض الطلب');
                          setState(() => rf['status'] = 'rejected');
                        } on ApiException catch (e) {
                          toast(context, e.message, error: true);
                        }
                      },
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _refundStatusChip(dynamic s) {
    final st = '$s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (st == 'accepted' ? A.success : st == 'rejected' ? A.danger : A.warning).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(st == 'accepted' ? 'مقبول' : st == 'rejected' ? 'مرفوض' : 'قيد المراجعة',
          style: A.t(10, c: st == 'accepted' ? A.success : st == 'rejected' ? A.danger : A.warning, w: FontWeight.w900)),
    );
  }
}
