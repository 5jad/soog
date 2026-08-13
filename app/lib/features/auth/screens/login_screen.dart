import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/routing/shell.dart';

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

  bool obscurePass = true;

  // ── مراحل التسجيل: 0=رقم → 1=رمز (بعد موافقة البوت) → 2=بيانات ──
  int regStage = 0;
  String? regToken;
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
    super.dispose();
  }

  String get _modeLabel => mode == AuthMode.login
      ? 'تسجيل الدخول'
      : (regStage == 0
          ? 'التأكيد عبر تلغرام'
          : (regStage == 1 ? 'تأكيد الرمز' : 'إنشاء الحساب'));

  Future<void> submit() async {
    if (mode == AuthMode.login) {
      _login();
      return;
    }
    if (regStage == 0) return _regStart();
    if (regStage == 1) return _regSubmitCode();
    if (regStage == 2) return _regSubmitDetails();
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
      final d = await Api.registerStart(p);
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
      toast(context, 'افتح تلغرام واكتب $bot واضغط Start', error: true);
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
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.cyan],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text('🛍️', style: TextStyle(fontSize: 40)),
      ),
      const SizedBox(height: 14),
      Text(
        'زبون',
        style: AppType.style(32,
            color: Colors.white,
            weight: FontWeight.w700,
            fontFamily: AppType.fontBrand),
      ),
      const SizedBox(height: 6),
      Text(
        'كل ما تتمناه — لرجالك ونسائك وأطفالك — بمكان واحد',
        style: AppType.style(12,
            color: Colors.white.withValues(alpha: 0.75), weight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSwitch(),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey(mode),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: mode == AuthMode.login ? _loginFields() : _registerFields(),
            ),
          ),
          const SizedBox(height: 20),
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
        borderRadius: BorderRadius.circular(10),
        elevation: active ? 2 : 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => mode = m);
            _resetReg(); // تبديل التبويب ينهي أي جلسة تسجيل معلقة
          },
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                label,
                style: AppType.style(13,
                    color: active ? AppColors.primary : AppColors.muted,
                    weight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginFields() => [
        _Field(
          controller: phone,
          hint: 'رقم الهاتف',
          icon: Icons.phone_android,
          isPhone: true,
        ),
        const SizedBox(height: 12),
        _Field(
          controller: password,
          hint: 'كلمة المرور',
          icon: Icons.lock_outline,
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
            controller: name,
            hint: 'الاسم الكامل',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: password,
            hint: 'كلمة المرور (6 أحرف أو أكثر)',
            icon: Icons.lock_outline,
            isPassword: true,
            obscure: obscurePass,
            onToggleObscure: () => setState(() => obscurePass = !obscurePass),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: referral,
            hint: 'كود الدعوة (اختياري) 🎁',
            icon: Icons.card_giftcard,
          ),
        ];
      default: // المرحلة 0 — الرقم فقط
        return [
          _Field(
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
                    'راح نتأكد رقمك عبر تلغرام: البوت يطابق الرقم ويرسل لك رمز — وإذا الرقم مسجل يرجّعك للدخول مباشرة',
                    style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
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
  final int? maxLen;
  final VoidCallback? onToggleObscure;
  final TextInputAction? textInputAction;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPhone = false,
    this.isPassword = false,
    this.isNumber = false,
    this.obscure = true,
    this.maxLen,
    this.onToggleObscure,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      textDirection: isPhone ? TextDirection.ltr : null,
      textAlign: isPhone ? TextAlign.left : TextAlign.start,
      keyboardType: isPhone || isNumber ? TextInputType.number : TextInputType.text,
      obscureText: isPassword && obscure,
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