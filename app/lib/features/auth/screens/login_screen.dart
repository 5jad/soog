import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/crop.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';
import 'package:zaboon/core/widgets/terms_sheet.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/routing/shell.dart';
import 'package:zaboon/features/shop/screens/map_screen.dart';

enum AuthMode { login, register }

/// صفحة الدخول/التسجيل — كارد صلب فوق كحلي الهوية (بلا زجاج: قرار حرج).
/// فاصل تبويبي واضح، حقول بسماكة 48، عداد إعادة إرسال، ورابط «شروط الاستخدام»
/// تحت الزر — الزبون يشوف الشروط قبل ما يوافق.
/// [initialMode] يحدد التبويب الافتتاحي — يمرره الـ Cart لما الضيف يريد الطلب.
class LoginScreen extends StatefulWidget {
  final AuthMode initialMode;
  const LoginScreen({super.key, this.initialMode = AuthMode.login});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthMode mode = widget.initialMode;
  bool loading = false;

  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final code = TextEditingController();
  final referral = TextEditingController();
  // ── بيانات المتجر للتاجر فقط (المرحلة 3) ──
  final storeName = TextEditingController();
  final storeDesc = TextEditingController();
  final storePhone = TextEditingController();
  final storeAddress = TextEditingController();
  String? storeIdCard; // رابط صورة البطاقة الوطنية (إلزامي)
  String? storeLogo; // شعار المتجر (اختياري)
  String? storeCover; // صورة الغلاف (اختياري)
  int? selCat;
  int? selDist;
  double? slat;
  double? slng;
  List allCats = [];
  final allDistricts = <Map<String, dynamic>>[];

  bool obscurePass = true;

  // ── مراحل التسجيل: 0=رقم → 1=رمز (بعد موافقة البوت) → 2=بيانات → 3=متجر التاجر ──
  int regStage = 0;
  String regRole = 'customer'; // نوع الحساب: زبون / تاجر / مندوب
  String? regToken;
  Map<String, dynamic>? _regAcc; // نتيجة register-confirm — يحفظها للتاجر لإنشاء المتجر
  String? regBot;
  bool regCodeReady = false; // البوت طابق الرقم ودز الرمز
  Timer? _regPoll;

  @override
  void initState() {
    super.initState();
    _loadRegLists();
  }

  @override
  void dispose() {
    _regPoll?.cancel();
    phone.dispose();
    password.dispose();
    name.dispose();
    code.dispose();
    referral.dispose();
    storeName.dispose();
    storeDesc.dispose();
    storePhone.dispose();
    storeAddress.dispose();
    super.dispose();
  }

  String get _modeLabel => mode == AuthMode.login
      ? 'تسجيل الدخول'
      : (regStage == 0
          ? 'التأكيد عبر تلغرام'
          : (regStage == 1
              ? 'تأكيد الرمز'
              : (regStage == 2 ? 'إنشاء الحساب' : 'إنشاء المتجر')));

  Future<void> submit() async {
    if (mode == AuthMode.login) {
      _login();
      return;
    }
    if (regToken == null) {
      final p = phone.text.trim();
      if (p.length < 10) return toast(context, 'أدخل رقم هاتف صحيح', error: true);
      if (name.text.trim().length < 3) return toast(context, 'أدخل اسمك الكامل', error: true);
      if (password.text.length < 6) return toast(context, 'كلمة المرور 6 أحرف كحد أدنى', error: true);
      if (regRole == 'vendor') {
         if (storeName.text.trim().length < 3) return toast(context, 'أدخل اسم متجرك', error: true);
         if (selCat == null) return toast(context, 'اختر قسم المتجر', error: true);
         if (storeIdCard == null || storeIdCard!.isEmpty) return toast(context, 'ارفع صورة بطاقتك الوطنية — إلزامية للتوثيق', error: true);
      }
      return _regStart();
    } else {
      return _regSubmitAll();
    }
  }

  // ── الدخول: رقم + كلمة مرور — بلا OTP أبداً ──
  Future<void> _login() async {
    final p = phone.text.trim();
    if (p.length < 10) return toast(context, 'أدخل رقم هاتف صحيح', error: true);
    setState(() => loading = true);
    try {
      if (password.text.isEmpty) throw ApiException('أدخل كلمة المرور', 400);
      final d = await Api.post('/api/auth/login', {
        'phone': p,
        'password': password.text,
      });
      await _onSuccess(d);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ── المرحلة 0: رقم → جلسة تحقق + فتح البوت ──
  Future<void> _regStart() async {
    final p = phone.text.trim();
    if (p.length < 10) return toast(context, 'أدخل رقم هاتف صحيح', error: true);
    setState(() => loading = true);
    try {
      final d = await Api.registerStart(p, role: regRole);
      regToken = d['token'];
      regBot = d['bot_username'] ?? 'soog_otp_bot';
      regCodeReady = false;
      
      _openRegTelegram();
      _startRegPoll();
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
      // الرقم عليه حساب → سجل دخول مباشرة (بلا OTP)
      if (e.message.contains('سجّل دخول')) setState(() => mode = AuthMode.login);
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _startRegPoll() {
    _regPoll?.cancel();
    _regPoll = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      final t = regToken;
      if (t == null || !mounted) {
        _regPoll?.cancel();
        return;
      }
      try {
        final s = await Api.registerStatus(t);
        if (!mounted) return;
        if (s == 'verified' && !regCodeReady) {
          setState(() => regCodeReady = true); // البوت دز الرمز — يكتبه بالحقل
        } else if (s == 'mismatch') {
          _resetReg();
          toast(context, 'الرقم اللي شاركته بالتلي غير الرقم اللي كتبته — جرب مرة ثانية', error: true);
        } else if (s == 'expired') {
          _resetReg();
          toast(context, 'انتهت مهلة التحقق — جرب من جديد', error: true);
        }
      } catch (_) {}
    });
  }

  void _resetReg() {
    _regPoll?.cancel();
    regToken = null;
    regCodeReady = false;
    code.clear();
    storeName.clear();
    storeDesc.clear();
    storePhone.clear();
    storeAddress.clear();
    storeIdCard = null;
    storeLogo = null;
    storeCover = null;
    selCat = null;
    selDist = null;
    slat = null;
    slng = null;
    _regAcc = null;
    
  }

  Future<void> _openRegTelegram() async {
    final bot = regBot ?? 'soog_otp_bot';
    final t = regToken;
    if (t == null) return;
    final ok = await launchUrl(
      Uri.parse('https://t.me/$bot?start=$t'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تلغرام غير مثبت 📱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
              'ما گدرنا نفتح تلغرام تلقائياً.\n\nافتح تطبيق تلغرام وابحث عن البوت:\n@$bot\n\nوبعدها ارسل له هذي الرسالة:\n/start $t',
              style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '/start $t'));
                toast(context, 'تم نسخ الرسالة ✓');
              },
              child: const Text('نسخ الرسالة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _regSubmitAll() async {
    final t = regToken;
    final c = code.text.trim();
    if (t == null) return _resetReg();
    if (c.length < 4) return toast(context, 'اكتب الرمز اللي وصلك بالمحادثة', error: true);
    setState(() => loading = true);
    try {
      await Api.registerCode(t, c);
      final d = await Api.registerConfirm(
        token: t,
        name: name.text.trim(),
        password: password.text,
        referral: referral.text.trim(),
      );
      if (regRole == 'vendor') {
        final tk = (d?['token'] ?? '') as String;
        if (tk.isNotEmpty) await Api.saveToken(tk);
        await Api.post('/api/vendor/store', {
          'name': storeName.text.trim(),
          'description': storeDesc.text.trim(),
          'phone': storePhone.text.trim().isNotEmpty ? storePhone.text.trim() : phone.text.trim(),
          'address': storeAddress.text.trim(),
          if (selCat != null) 'category_id': selCat,
          if (selDist != null) 'district_id': selDist,
          if (slat != null) 'lat': slat,
          if (slng != null) 'lng': slng,
          if (storeLogo != null && storeLogo!.isNotEmpty) 'logo': storeLogo,
          if (storeCover != null && storeCover!.isNotEmpty) 'cover': storeCover,
        });
        await Api.post('/api/vendor/store/documents', {
          'type': 'national_id',
          'title': 'البطاقة الوطنية',
          'file_url': storeIdCard,
        });
        toast(context, 'انطلق متجرك — بانتظار توثيق الأدمن ⏳');
      }
      if (mounted) {
         _regPoll?.cancel();
         await _onSuccess(d);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
      if (e.message.contains('انتهت')) _resetReg();
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadRegLists() async {
    try {
      final c = await Api.get('/api/categories');
      final g = await Api.get('/api/governorates');
      if (!mounted) return;
      final dists = <Map<String, dynamic>>[];
      for (final gov in (g['governorates'] ?? [])) {
        final govId = (gov['id'] as num).toInt();
        for (final d in (gov['districts'] ?? [])) {
          dists.add({...(d as Map<String, dynamic>), 'governorate_id': govId});
        }
      }
      setState(() {
        allCats = c['categories'] ?? [];
        allDistricts
          ..clear()
          ..addAll(dists);
      });
    } catch (_) {}
  }

  // رفع صورة (كاميرا/معرض) مع قصّ اختياري — للبطاقة والشعار والغلاف
  Future<void> _pickAndUpload(
    ImageSource src,
    String title,
    double aspect,
    ValueChanged<String> onUrl, {
    bool crop = false,
  }) async {
    try {
      final f = await ImagePicker().pickImage(
        source: src,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (f == null) return;
      Uint8List bytes = await f.readAsBytes();
      if (crop) {
        final cropped = await cropImage(
          context,
          bytes,
          aspect: aspect,
          title: title,
        );
        if (cropped == null) return;
        bytes = cropped;
      }
      final urls = await Api.uploadBytes([bytes]);
      if (urls.isNotEmpty && mounted) {
        onUrl(urls.first);
        toast(context, 'انضافت الصورة ✓');
      }
    } catch (_) {
      if (mounted) toast(context, 'تعذر رفع الصورة', error: true);
    }
  }

  Future<void> _regSubmitStore() async {
    final acc = _regAcc;
    if (acc == null) return _resetReg();
    if (storeName.text.trim().length < 3) return toast(context, 'أدخل اسم متجرك', error: true);
    if (selCat == null) return toast(context, 'اختر قسم المتجر', error: true);
    if (storeIdCard == null || storeIdCard!.isEmpty)
      return toast(context, 'ارفع صورة بطاقتك الوطنية — إلزامية للتوثيق', error: true);
    setState(() => loading = true);
    try {
      final t = acc['token'] as String?;
      if (t == null) return _resetReg();
      await Api.saveToken(t); // المتجر يحتاج توك التاجر
      await Api.post('/api/vendor/store', {
        'name': storeName.text.trim(),
        'description': storeDesc.text.trim(),
        'phone': storePhone.text.trim(),
        'address': storeAddress.text.trim(),
        if (selCat != null) 'category_id': selCat,
        if (selDist != null) 'district_id': selDist,
        if (slat != null) 'lat': slat,
        if (slng != null) 'lng': slng,
        if (storeLogo != null && storeLogo!.isNotEmpty) 'logo': storeLogo,
        if (storeCover != null && storeCover!.isNotEmpty) 'cover': storeCover,
      });
      // البطاقة الوطنية — تُرفع كوثيقة توثيق للمراجعة
      await Api.post('/api/vendor/store/documents', {
        'type': 'national_id',
        'title': 'البطاقة الوطنية',
        'file_url': storeIdCard,
      });
      if (!mounted) return;
      toast(context, 'انطلق متجرك — بانتظار توثيق الأدمن ⏳');
      await _onSuccess(acc);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _onSuccess(dynamic d) async {
    await Api.saveToken(d['token']);
    Api.me = d['user'];
    // دمج سلة الضيف المحلية مع سلة الحساب — الأغراض اللي ضافها كضيف
    // تظهر له بعد التسجيل. لو فشل الدمج تبقى سلة الضيف محفوظة للمحاولة الجاية.
    if (AppState.i.guestCart.isNotEmpty) {
      try {
        final r = await Api.post('/api/customer/cart/merge', {
          'items': AppState.i.guestCart.map((e) => {
                'product_id': e['product_id'],
                'variant': e['variant'],
                'qty': e['qty'],
              }).toList(),
        });
        AppState.i.guestCart.clear();
        final items = r['items'] ?? [];
        AppState.i.setCart(
          (items as List).fold<int>(0, (a, b) => a + ((b['qty'] as num?)?.toInt() ?? 0)),
        );
      } catch (_) {
        // الشبكة/الخادم ما جاوب — السلة المحلية تظل مكتوبة عند المحاولة التالية
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  // ── أدوات التطوير — محذوفة نهائياً: لا عناوين سيرفر ولا حسابات تجربة في الإنتاج ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradNavy),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildCard(),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            color: AppColors.primaryDeep,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: LottieBox(
            assetKey: 'loading_splash',
            width: 70,
            height: 70,
            loop: true,
            fallback: const Text('🛍️', style: TextStyle(fontSize: 36)),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'زبون',
        style: AppType.style(36,
            color: Colors.white,
            weight: FontWeight.w800,
            fontFamily: 'ElMessiri'),
      ),
      const SizedBox(height: 4),
      Text(
        'سوق الكوت بين إيديك',
        style: AppType.style(13.5,
            color: Colors.white.withValues(alpha: 0.8), weight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSwitch(),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Column(
              key: ValueKey(mode),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: mode == AuthMode.login ? _loginFields() : _registerFields(),
            ),
          ),
          const SizedBox(height: 24),
          SolidBtn(
            label: _modeLabel,
            color: AppColors.accent,
            loading: loading,
            haptic: true,
            onTap: submit,
          ),
        ],
      ),
    );
  }

  // ── الفاصل التبويبي — قرار واضح بلا نصات متناثرة أسفل الصفحة ──
  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        _modeBtn(AuthMode.login, 'تسجيل الدخول'),
        _modeBtn(AuthMode.register, 'حساب جديد'),
      ]),
    );
  }

  Widget _modeBtn(AuthMode m, String label) {
    final active = mode == m;
    return Expanded(
      child: Material(
        color: active ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: active ? 2 : 0,
        shadowColor: AppColors.primaryDeep.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => mode = m);
            _resetReg(); // تبديل التبويب ينهي أي جلسة تسجيل معلقة
          },
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: AppType.style(13.5,
                    color: active ? AppColors.primary : AppColors.muted,
                    weight: active ? FontWeight.w800 : FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginFields() => [
        _Field(
          key: const ValueKey('phone'),
          controller: phone,
          hint: 'رقم الهاتف (مثال: 07800000000)',
          icon: Icons.phone_android_rounded,
          isPhone: true,
        ),
        const SizedBox(height: 14),
        _Field(
          key: const ValueKey('password'),
          controller: password,
          hint: 'كلمة المرور',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: obscurePass,
          onToggleObscure: () => setState(() => obscurePass = !obscurePass),
        ),
      ];

  
  List<Widget> _registerFields() {
    return [
      // ═══ اختيار نوع الحساب: زبون / تاجر ═══
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          _regRoleBtn('customer', 'زبون 🛍️'),
          _regRoleBtn('vendor', 'تاجر 🏪'),
        ]),
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('name'),
        controller: name,
        hint: 'الاسم الكامل',
        icon: Icons.person_outline,
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('phone'),
        controller: phone,
        hint: 'رقم الهاتف (مثال: 07800000000)',
        icon: Icons.phone_android_rounded,
        isPhone: true,
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('password'),
        controller: password,
        hint: 'كلمة المرور (6 أحرف أو أكثر)',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        obscure: obscurePass,
        onToggleObscure: () => setState(() => obscurePass = !obscurePass),
      ),
      if (regRole == 'vendor') ...[
        const SizedBox(height: 12),
        const Divider(color: AppColors.line),
        const SizedBox(height: 12),
        Text('بيانات المتجر', style: AppType.style(14, weight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 12),
        _Field(
          key: const ValueKey('storeName'),
          controller: storeName,
          hint: 'اسم المتجر',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: selCat,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'القسم',
            hintText: 'اختر قسم المتجر',
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppColors.line),
            ),
          ),
          items: allCats.isEmpty
              ? [const DropdownMenuItem<int?>(value: null, child: Text('...جاري التحميل'))]
              : [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('اختر القسم'),
                  ),
                  ...allCats.map(
                    (c) => DropdownMenuItem<int?>(
                      value: (c['id'] as num).toInt(),
                      child: Text('${c['icon'] ?? ''} ${c['name']}'),
                    ),
                  ),
                ],
          onChanged: (v) => setState(() => selCat = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'صورة البطاقة الوطنية 🪪',
                style: AppType.style(13, color: AppColors.ink, weight: FontWeight.w800),
              ),
            ),
            if (storeIdCard != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('تم الرفع ✓',
                    style: AppType.style(11, color: AppColors.success, weight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => setState(() => storeIdCard = null),
                icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
                tooltip: 'إزالة',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                productImageBox(storeIdCard, base: Api.base),
                if (storeIdCard == null)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 30, color: AppColors.muted),
                        const SizedBox(height: 6),
                        Text('لم تُرفع بعد',
                            style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndUpload(
                  ImageSource.camera,
                  'التقاط البطاقة 📷',
                  1.586,
                  (u) => setState(() => storeIdCard = u),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 17),
                label: const Text('كاميرا'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndUpload(
                  ImageSource.gallery,
                  'اختيار من المعرض 🖼',
                  1.586,
                  (u) => setState(() => storeIdCard = u),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: const Text('من المعرض'),
              ),
            ),
          ],
        ),
      ],

      const SizedBox(height: 12),
      // ═══ كود التوثيق (يظهر بعد ضغط ارسال الرمز) ═══
      if (regToken != null) ...[
        const Divider(color: AppColors.line),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: regCodeReady ? AppColors.surface : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: regCodeReady ? AppColors.success : AppColors.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (regCodeReady)
                const Icon(Icons.check_circle, size: 18, color: AppColors.success)
              else
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  regCodeReady
                      ? 'الرمز وصلك داخل المحادثة بالبوت — اكتبه بالأسفل'
                      : 'افتح تلغرام واضغط «مشاركة رقم هاتفي» — البوت يطابق رقمك ويرسل الرمز',
                  style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openRegTelegram,
          icon: const Icon(Icons.telegram, size: 16, color: AppColors.info),
          label: Text('فتح تلغرام يدوياً 🔗',
              style: AppType.style(12, color: AppColors.primary, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        _Field(
          key: const ValueKey('code'),
          controller: code,
          hint: 'رمز التحقق (أرقام)',
          icon: Icons.message_outlined,
          isNumber: true,
          maxLen: 6,
          textInputAction: TextInputAction.done,
        ),
      ],
    ];
  }

  Widget _regRoleBtn(String v, String label) {
    final active = regRole == v;
    return Expanded(
      child: Material(
        color: active ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: active ? 1.5 : 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => regRole = v),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                label,
                style: AppType.style(12.5,
                    color: active ? AppColors.primary : AppColors.muted,
                    weight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Text.rich(
        TextSpan(
          style: AppType.style(11, color: Colors.white.withValues(alpha: 0.55)),
          children: [
            const TextSpan(text: 'بالضغط على المتابعة فأنت توافق على '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => showTermsSheet(context),
                child: Text(
                  'شروط الاستخدام',
                  style: AppType.style(11,
                      color: Colors.white,
                      weight: FontWeight.w800,
                      decoration: TextDecoration.underline),
                ),
              ),
            ),
            const TextSpan(text: ' — اضغط لقراءتها'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security_outlined,
              size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            'رقمك يبقى سراً ولا يُشارك مع أي جهة',
            style: AppType.style(11, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    ]);
  }
}

/// يفتح شاشة الدخول/التسجيل من أي نقطة في التطبيق — الضيف يواجهه التسجيل
/// عند الطلب أو المفضلة أو متابعة متجر. الافتراضي على تبويب «حساب جديد».
void openLoginScreen(BuildContext context,
    {AuthMode initial = AuthMode.register}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LoginScreen(initialMode: initial)),
  );
}

/// حقل موحد باحتراف: أيقونة، إدخال LTR للهاتف، إظهار كلمة المرور، ومكوّن جانبي اختياري
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPhone;
  final bool isPassword;
  final bool isNumber;
  final bool obscure;
  final bool autofocus;
  final int? maxLen;
  final int? maxLines;
  final VoidCallback? onToggleObscure;
  final TextInputAction? textInputAction;

  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPhone = false,
    this.isPassword = false,
    this.isNumber = false,
    this.obscure = true,
    this.autofocus = false,
    this.maxLen,
    this.maxLines,
    this.onToggleObscure,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: textInputAction,
      textDirection: isPhone ? TextDirection.ltr : null,
      textAlign: isPhone ? TextAlign.left : TextAlign.start,
      keyboardType: isPhone || isNumber ? TextInputType.number : TextInputType.text,
      obscureText: isPassword && obscure,
      maxLines: maxLines,
      inputFormatters: isPhone || isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      maxLength: isPhone ? 15 : maxLen,
      style: const TextStyle(color: AppColors.ink),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.8)),
        counterText: '',
        prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}