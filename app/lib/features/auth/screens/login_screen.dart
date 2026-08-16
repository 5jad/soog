import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/crop.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/routing/shell.dart';
import 'package:zaboon/features/shop/screens/map_screen.dart';

enum AuthMode { login, register }

/// صفحة الدخول/التسجيل — كارد صلب فوق كحلي الهوية (بلا زجاج: قرار حرج).
/// فاصل تبويبي واضح، حقول بسماكة 48، عداد إعادة إرسال، وأدوات التطوير
/// مخفية خلف صفارة حتى لا تلوّث الانطباع الأول.
/// [onGuest] يفعّل زر «تصفح بدون حساب» — يمرره الـ Shell فقط.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onGuest;
  const LoginScreen({super.key, this.onGuest});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthMode mode = AuthMode.login;
  bool loading = false;
  bool devOpen = false;

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
    if (regStage == 0) return _regStart();
    if (regStage == 1) return _regSubmitCode();
    if (regStage == 2) return _regSubmitDetails();
    if (regStage == 3) return _regSubmitStore();
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
      setState(() => regStage = 1);
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
    setState(() => regStage = 0);
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

  // ── المرحلة 1: رمز البوت ──
  Future<void> _regSubmitCode() async {
    final t = regToken;
    final c = code.text.trim();
    if (t == null) return _resetReg();
    if (c.length < 4) return toast(context, 'اكتب الرمز اللي وصلك بالمحادثة', error: true);
    setState(() => loading = true);
    try {
      await Api.registerCode(t, c);
      if (mounted) {
        _regPoll?.cancel();
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => regStage = 2);
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

// ── المرحلة 2: الاسم + كلمة المرور → إنشاء الحساب ──
  Future<void> _regSubmitDetails() async {
    final t = regToken;
    if (t == null) return _resetReg();
    if (name.text.trim().length < 3) return toast(context, 'أدخل اسمك الكامل', error: true);
    if (password.text.length < 6) return toast(context, 'كلمة المرور 6 أحرف كحد أدنى', error: true);
    setState(() => loading = true);
    try {
      final d = await Api.registerConfirm(
        token: t,
        name: name.text.trim(),
        password: password.text,
        referral: referral.text.trim(),
      );
      if (!mounted) return;
      if (regRole == 'vendor') {
        // التاجر يكمّل بيانات متجره في المرحلة 3 (بعد إنشاء الحساب)
        _regAcc = (d ?? {}) as Map<String, dynamic>;
        // احفظ التوكن فوراً — رفع الصور (البطاقة/الشعار/الغلاف) في المرحلة 3 يحتاجه
        final tk = (d?['token'] ?? '') as String;
        if (tk.isNotEmpty) await Api.saveToken(tk);
        storePhone.text = phone.text.trim();
        setState(() => regStage = 3);
        _loadRegLists();
      } else {
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

  // ── المرحلة 3 (للتاجر فقط): بيانات المتجر → إنشاء + بانتظار توثيق الأدمن ──
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
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  // ── أدوات التطوير — مخفية خلف الصفارة (Bottom Sheet زجاجي = مسموح للـ Chrome) ──
  void _toggleDev() {
    final appbarH = AppMetrics.appBarH;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DevSheet(height: appbarH),
    );
  }

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
                      // الضيف: تصفح كامل بلا حساب — الدخول يطلب عند الدفع/المفضلة
                      if (widget.onGuest != null)
                        TextButton.icon(
                          onPressed: widget.onGuest,
                          icon: const Icon(Icons.visibility_outlined,
                              color: Colors.white70, size: 18),
                          label: Text(
                            'تصفح بدون حساب',
                            style: AppType.style(12.5,
                                color: Colors.white70,
                                weight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
              // صفارة أدوات التطوير — لا تلوّث الواجهة الإنتاجية
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: _toggleDev,
                  tooltip: 'أدوات التطوير',
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white70, size: 20),
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
    switch (regStage) {
      case 1: // رمز البوت (بعد المطابقة)
        return [
          _Field(
            key: const ValueKey('code'),
            controller: code,
            hint: 'رمز التحقق ●●●●',
            icon: Icons.message_outlined,
            isNumber: true,
            maxLen: 6,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          // شريط الحالة: بانتظار البوت ← أو الرمز انوصل
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
                        ? 'الرمز وصلك داخل المحادثة بالبوت — اكتبه أعلاه'
                        : 'افتح تلغرام واضغط «مشاركة رقم هاتفي» — البوت يطابق رقمك ويرسل الرمز',
                    style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // إعادة فتح تلغرام إن رجع الزبون للتطبيق
          TextButton.icon(
            onPressed: _openRegTelegram,
            icon: const Icon(Icons.telegram, size: 16, color: AppColors.info),
            label: Text('فتح تلغرام 🔗',
                style: AppType.style(12, color: AppColors.primary, weight: FontWeight.w700)),
          ),
        ];
      case 2: // الاسم + كلمة المرور
        return [
          _Field(
            key: const ValueKey('name'),
            controller: name,
            hint: 'الاسم الكامل',
            icon: Icons.person_outline,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('password'),
            controller: password,
            hint: 'كلمة المرور (6 أحرف أو أكثر)',
            icon: Icons.lock_outline,
            isPassword: true,
            obscure: obscurePass,
            onToggleObscure: () => setState(() => obscurePass = !obscurePass),
          ),
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('referral'),
            controller: referral,
            hint: 'كود الدعوة (اختياري) 🎁',
            icon: Icons.card_giftcard,
          ),
        ];
      case 3: // بيانات المتجر — خطوة التاجر بعد إنشاء الحساب
        return [
          // ═══ البطاقة الوطنية — إلزامية للتوثيق ═══
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
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('storeName'),
            controller: storeName,
            hint: 'اسم المتجر',
            icon: Icons.storefront_outlined,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          // ═══ القسم — إلزامي ═══
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
          // ═══ المحافظة / الحي ═══
          DropdownButtonFormField<int?>(
            value: selDist,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المحافظة / الحي (اختياري)',
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
            items: allDistricts.isEmpty
                ? [const DropdownMenuItem<int?>(value: null, child: Text('...جاري التحميل'))]
                : [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('بدون حي'),
                    ),
                    ...allDistricts.map(
                      (d) => DropdownMenuItem<int?>(
                        value: (d['id'] as num).toInt(),
                        child: Text('${d['name']}'),
                      ),
                    ),
                  ],
            onChanged: (v) => setState(() => selDist = v),
          ),
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('storeAddress'),
            controller: storeAddress,
            hint: 'العنوان (اختياري) — اكتبه يدوياً',
            icon: Icons.location_on_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          // ═══ الموقع على الخريطة — يدوياً أو بالخريطة ═══
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () async {
              final picked = await Navigator.push<Object?>(
                context,
                MaterialPageRoute(
                  builder: (_) => PickMapScreen(lat: slat, lng: slng),
                ),
              );
              if (picked != null && picked is LatLng) {
                setState(() {
                  slat = picked.latitude;
                  slng = picked.longitude;
                });
              }
            },
            icon: const Icon(Icons.map_rounded),
            label: Text(
              slat != null
                  ? 'الموقع محدد ✓ (${slat!.toStringAsFixed(4)}, ${slng!.toStringAsFixed(4)})'
                  : 'حدد موقع المتجر على الخريطة 🗺 (اختياري)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('storeDesc'),
            controller: storeDesc,
            hint: 'وصف المتجر (اختياري)',
            icon: Icons.description_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _Field(
            key: const ValueKey('storePhone'),
            controller: storePhone,
            hint: 'هاتف المتجر (داخلي — لا يظهر للزبون)',
            icon: Icons.phone_android,
            isPhone: true,
            maxLen: 15,
          ),
          const SizedBox(height: 12),
          // ═══ الشعار والغلاف — اختيارية ═══
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickAndUpload(
                    ImageSource.gallery,
                    'قصّ الشعار ✂️',
                    1,
                    (u) => setState(() => storeLogo = u),
                    crop: true,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 17),
                  label: const Text('شعار المتجر (اختياري)'),
                ),
              ),
              if (storeLogo != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: productImageBox(storeLogo, base: Api.base),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickAndUpload(
                    ImageSource.gallery,
                    'قصّ الغلاف ✂️',
                    16 / 9,
                    (u) => setState(() => storeCover = u),
                    crop: true,
                  ),
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: const Text('صورة الغلاف (اختياري)'),
                ),
              ),
              if (storeCover != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: productImageBox(storeCover, base: Api.base),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بعد الحفظ ينوصل متجرك وبطاقتك للأدمن للتوثيق — ورقم هاتفك يبقى داخلياً ولا يظهر للزبون',
                    style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ];
      default: // المرحلة 0 — الرقم فقط + نوع الحساب
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
            key: const ValueKey('phone'),
            controller: phone,
            hint: 'رقم الهاتف',
            icon: Icons.phone_android,
            isPhone: true,
          ),
          const SizedBox(height: 12),
          // التحقق للحساب الجديد فقط — المسجل يوجّه للدخول تلقائياً
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.telegram, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    regRole == 'vendor'
                        ? 'راح تنشئ حساب تاجر: بعد التأكيد تسجل محلك بانتظار توثيق الأدمن 🏪'
                        : 'راح نتأكد رقمك عبر تلغرام: البوت يطابق الرقم ويرسل لك رمز — وإذا الرقم مسجل يرجّعك للدخول مباشرة',
                    style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
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
      Text(
        'بالضغط على المتابعة فأنت توافق على شروط الاستخدام',
        style: AppType.style(11, color: Colors.white.withValues(alpha: 0.55)),
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

/// أدوات التطوير — زجاجية (Sheet = Chrome): عنوان الخادم + حسابات التجربة
class _DevSheet extends StatelessWidget {
  final double height;
  const _DevSheet({required this.height});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: Api.base);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: AppGlass.blurHeavy,
          sigmaY: AppGlass.blurHeavy,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppGlass.fillNavDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('أدوات التطوير',
                      style: AppType.style(16,
                          color: Colors.white, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      hintText: 'https://اسم-النفق.trycloudflare.com',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon:
                          const Icon(Icons.dns_rounded, color: Colors.white70, size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SolidBtn(
                    label: 'حفظ العنوان',
                    onTap: () async {
                      final u = ctrl.text.trim();
                      if (u.isNotEmpty) await Api.setBase(u);
                      if (context.mounted) {
                        Navigator.pop(context);
                        toast(context, 'تم الحفظ ✓ — جرب الدخول');
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('حسابات تجريبية',
                      style: AppType.style(13,
                          color: Colors.white70, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _trialRow('زبون', '000000000200 · 123456'),
                  _trialRow('تاجر', '000000000100 · 123456'),
                  _trialRow('مندوب', '000000000300 · 123456'),
                  _trialRow('أدمن', '07900000000 · admin123'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trialRow(String role, String creds) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$role: ',
            style: AppType.style(12,
                color: const Color(0xFF9EC5EB), weight: FontWeight.w700)),
        Text(creds,
            style: AppType.style(12, color: Colors.white70)),
      ]),
    );
  }
}