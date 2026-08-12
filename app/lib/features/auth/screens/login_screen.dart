import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/routing/shell.dart';
import 'package:zaboon/features/auth/screens/phone_verify_screen.dart';

enum AuthMode { login, register }

/// صفحة الدخول/التسجيل — كارد صلب فوق كحلي الهوية (بلا زجاج: قرار حرج).
/// فاصل تبويبي واضح، حقول بسماكة 48، عداد إعادة إرسال، وأدوات التطوير
/// مخفية خلف صفارة حتى لا تلوّث الانطباع الأول.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
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
  final referral = TextEditingController();

  bool obscurePass = true;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    name.dispose();
    referral.dispose();
    super.dispose();
  }

  String get _modeLabel => mode == AuthMode.login ? 'تسجيل الدخول' : 'سجّل برقم تلغرامك 📲';

  Future<void> submit() async {
    if (mode == AuthMode.login) {
      final p = phone.text.trim();
      if (p.length < 10) return toast(context, 'أدخل رقم هاتف صحيح', error: true);
      setState(() => loading = true);
    } else {
      if (name.text.trim().length < 3) return toast(context, 'أدخل اسمك الكامل', error: true);
      if (password.text.length < 6) return toast(context, 'كلمة المرور 6 أحرف كحد أدنى', error: true);
    }

    try {
      if (mode == AuthMode.login) {
        if (password.text.isEmpty) throw ApiException('أدخل كلمة المرور', 400);
        final d = await Api.post('/api/auth/login', {
          'phone': phone.text.trim(),
          'password': password.text,
        });
        await _onSuccess(d);
      } else {
        // التسجيل الجديد: بلا رقم مكتوب — الحساب يتثبت بزر المشاركة داخل تلغرام
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PhoneVerifyScreen.register(
            register: RegisterInfo(
              name: name.text.trim(),
              password: password.text,
              referral: referral.text.trim(),
            ),
            onVerified: _onSuccess,
          ),
        ));
      }
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
          onTap: () => setState(() => mode = m),
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

  List<Widget> _registerFields() => [
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
        const SizedBox(height: 12),
        // رقم الحساب = رقم تلغرامك — لا يُكتب إطلاقاً
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
                  'رقم حسابك سيُؤخذ من تلغرامك بضغطة زر داخل البوت — بلا كتابة ولا مشاركة',
                  style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ];

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
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputAction? textInputAction;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPhone = false,
    this.isPassword = false,
    this.obscure = true,
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
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      obscureText: isPassword && obscure,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLength: isPhone ? 15 : null,
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