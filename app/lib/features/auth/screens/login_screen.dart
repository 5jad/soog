import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/core/routing/shell.dart';

enum AuthMode { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthMode mode = AuthMode.login;
  bool loading = false;
  bool linkingTg = false;

  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final code = TextEditingController();
  final referral = TextEditingController();

  Future<void> submit() async {
    if (phone.text.trim().length < 10)
      return toast(context, 'أدخل رقم هاتف صحيح', error: true);

    setState(() => loading = true);
    try {
      if (mode == AuthMode.login) {
        if (password.text.isEmpty) throw ApiException('أدخل كلمة المرور', 400);
        final d = await Api.post('/api/auth/login', {
          'phone': phone.text.trim(),
          'password': password.text,
        });
        await _onSuccess(d);
      } else if (mode == AuthMode.register) {
        if (name.text.isEmpty || password.text.isEmpty)
          throw ApiException('الاسم وكلمة المرور مطلوبين', 400);
        if (code.text.trim().isEmpty)
          throw ApiException('أرسل رمز التحقق أولاً وتأكد منه', 400);
        final d = await Api.post('/api/auth/register', {
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'password': password.text,
          'code': code.text.trim(),
          if (referral.text.trim().isNotEmpty) 'referral': referral.text.trim(),
        });
        await _onSuccess(d);
      }
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    } catch (_) {
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ربط آمن بالتليجرام: التطبيق يولّد رمز ربط سري ويفتح البوت — الرقم لا يُرسل أبداً
  Future<void> _linkTelegram() async {
    final p = phone.text.trim();
    if (p.length < 10)
      return toast(context, 'اكتب رقم الهاتف أولاً', error: true);
    setState(() => linkingTg = true);
    try {
      final d = await Api.post('/api/telegram/bind-token', {'phone': p});
      final botName = d['bot_username'] ?? 'soog_otp_bot';
      final ok = await launchUrl(
        Uri.parse('https://t.me/$botName?start=${d['token']}'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) {
        toast(context, 'اضغط Start داخل البوت ثم ارجع للتطبيق');
      } else {
        toast(context, 'افتح تليجرام واكتب $botName واضغط Start', error: true);
      }
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    } catch (_) {
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => linkingTg = false);
    }
  }

  // إرسال رمز التحقق لإنشاء حساب جديد — الرقم يجب أن يكون غير مسجل
  Future<void> _sendCode() async {
    if (phone.text.trim().length < 10) {
      toast(context, 'اكتب رقم الهاتف أولاً', error: true);
      return;
    }
    setState(() => loading = true);
    try {
      final d = await Api.post('/api/auth/request-otp', {
        'phone': phone.text.trim(),
      });
      if (d['dev_code'] != null) {
        code.text = '${d['dev_code']}';
        toast(context, 'رمز التطوير: ${d['dev_code']} (التطبيق بالوضع التجريبي)');
      } else {
        toast(context, 'انرسل الرمز لهاتفك');
      }
    } on ApiException catch (e) {
      toast(context, e.message, error: true);
    } catch (_) {
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _onSuccess(Map d) async {
    await Api.saveToken(d['token']);
    Api.me = d['user'];
    if (!mounted) return;
    // نمسح كل الـ stack — حتى نسخة "الضيف" السابقة ما تبقى تحته فيطلع زر رجوع
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  Future<void> _changeServer() async {
    final ctrl = TextEditingController(text: Api.base);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('عنوان الخادم (Server URL)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://اسم-النفق.trycloudflare.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    try {
      await Api.setBase(url);
      toast(context, 'تم الحفظ ✓ — جرب الدخول');
    } on Exception {
      toast(context, 'خطأ بالحفظ', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradNavy),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🛍️', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'زبون',
                    style: AppType.style(
                      30,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ).copyWith(fontFamily: 'ElMessiri'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'كل ما تتمناه — لرجالك ونسائك وأطفالك — بمكان واحد 👌',
                    style: AppType.style(
                      12,
                      color: Colors.white70,
                      weight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    mode == AuthMode.login ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                    style: AppType.style(
                      20,
                      color: Colors.white,
                      weight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Column(
                      children: [
                        if (mode == AuthMode.register) ...[
                          _Field(
                            controller: name,
                            hint: 'الاسم الكامل',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: referral,
                            hint: 'كود الدعوة (اختياري) 🎁',
                            icon: Icons.card_giftcard,
                          ),
                          const SizedBox(height: 12),
                        ],

                        _Field(
                          controller: phone,
                          hint: 'رقم الهاتف',
                          icon: Icons.phone_android,
                          isPhone: true,
                        ),
                        const SizedBox(height: 12),

                        if (mode == AuthMode.register) ...[
                          _Field(
                            controller: code,
                            hint: 'رمز التحقق (●●●●)',
                            icon: Icons.message,
                            isNumber: true,
                          ),
                          const SizedBox(height: 12),
                        ],

                        _Field(
                          controller: password,
                          hint: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 16),

                        if (mode == AuthMode.login) ...[
                          OutlinedButton.icon(
                            onPressed: mode == AuthMode.login
                                ? (linkingTg ? null : _linkTelegram)
                                : (loading ? null : _sendCode),
                            icon: (mode == AuthMode.login ? linkingTg : loading)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.telegram,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              mode == AuthMode.login
                                  ? 'اربط بالتليجرام لاستلام الرموز 📲'
                                  : 'أرسل رمز التحقق 📲',
                              style: AppType.style(
                                13,
                                color: Colors.white,
                                weight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.35),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        SolidBtn(
                          label: mode == AuthMode.login ? 'دخول' : 'سجل الآن',
                          loading: loading,
                          onTap: submit,
                        ),

                        const SizedBox(height: 12),

                        if (mode == AuthMode.login) ...[
                          TextButton(
                            onPressed: () =>
                                setState(() => mode = AuthMode.register),
                            child: const Text(
                              'حساب جديد؟',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ] else ...[
                          TextButton(
                            onPressed: () =>
                                setState(() => mode = AuthMode.login),
                            child: const Text(
                              'رجوع لتسجيل الدخول',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: _changeServer,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.dns_rounded,
                                      size: 15,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'تغيير عنوان الخادم (الرابط الحالي: ${Api.base.contains('trycloudflare') ? 'عام ☁️' : 'محلي'})',
                                      style: AppType.style(
                                        10.5,
                                        color: Colors.white70,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'حسابات تجريبية',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'زبون: 000000000200 · 123456',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'مندوب: 000000000300 · 123456',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'تاجر: 000000000100 · 123456',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'أدمن: 07900000000 · admin123',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPhone;
  final bool isPassword;
  final bool isNumber;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPhone = false,
    this.isPassword = false,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isPhone || isNumber
          ? TextInputType.number
          : TextInputType.text,
      textDirection: isPhone ? TextDirection.ltr : null,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
