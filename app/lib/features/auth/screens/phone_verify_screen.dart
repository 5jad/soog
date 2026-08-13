import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';
import 'package:zaboon/core/widgets/widgets.dart';

enum _VerState { starting, noTelegram, waiting, success, timedout, mismatch, error }

/// تحقق الهاتف عبر تلغرام (request_contact) — تلغرام حصراً، بلا أي مسار بديل.
/// خلفية صلبة (شاشة قرار حرج) — الزجاج للتنقل فقط، وكل حالة واضحة بلا فراغ.
/// للتأكيد عند الطلب (مقارنة الرقم) — التسجيل له مرحله داخل تبويب التسجيل.
class PhoneVerifyScreen extends StatefulWidget {
  final String phone;
  final void Function(dynamic result) onVerified;

  const PhoneVerifyScreen({
    super.key,
    required this.phone,
    required this.onVerified,
  });

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen>
    with WidgetsBindingObserver {
  _VerState state = _VerState.starting;
  String? token;
  String? botName;
  Timer? _timer;
  DateTime? _deadline;
  String _error = '';
  static const _pollEvery = Duration(milliseconds: 2500);
  static const _attemptLimit = Duration(seconds: 120);

  String get _masked {
    final p = widget.phone;
    return p.length >= 10
        ? '${p.substring(0, 4)} ••• ${p.substring(p.length - 3)}'
        : p;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probeTelegram(); // بوابة pre-flight قبل أي جلسة
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // العودة للتطبيق من تلغرام → فحص فوري بدل انتظار 2.5 ثانية
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed && state == _VerState.waiting) _check();
  }

  // الفحص بـ tg:// لا بـ https://t.me — الأخير يقع على المتصفح فيرجع true دائماً،
  // بينما tg:// يسجّله تطبيق تلغرام فقط فيحسم غيابه بدقة
  Future<void> _probeTelegram() async {
    final bot = botName ?? 'soog_otp_bot';
    final installed = await canLaunchUrl(Uri.parse('tg://resolve?domain=$bot'));
    if (!mounted) return;
    if (!installed) {
      setState(() => state = _VerState.noTelegram);
    } else {
      await _startSession();
    }
  }

  Future<void> _startSession() async {
    setState(() {
      state = _VerState.starting;
      _timer?.cancel();
    });
    try {
      final d = await Api.verifyStart();
      token = d['token'];
      botName = d['bot_username'] ?? 'soog_otp_bot';
      _deadline = DateTime.now().add(_attemptLimit);
      setState(() => state = _VerState.waiting);
      _timer = Timer.periodic(_pollEvery, (_) => _check());
      _openTelegram();
    } on ApiException catch (e) {
      setState(() {
        state = _VerState.error;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        state = _VerState.error;
        _error = 'تعذر الاتصال بالخادم';
      });
    }
  }

  // الفتح بتطبيق تلغرام الأصلي (native) — WebView داخلي ممنوع
  Future<void> _openTelegram() async {
    final ok = await launchUrl(
      Uri.parse('https://t.me/$botName?start=$token'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      toast(context, 'افتح تلغرام يدوياً واكتب $botName واضغط Start', error: true);
    }
  }

  Future<void> _check() async {
    if (token == null || !mounted) return;
    final t = token!;
    try {
      final s = await Api.verifyStatus(t);
      switch (s) {
        case 'verified':
          _timer?.cancel();
          setState(() => state = _VerState.success);
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) widget.onVerified(null);
          });
          return;
        case 'mismatch':
          _timer?.cancel();
          setState(() {
            state = _VerState.mismatch;
            _error = 'الرقم اللي شاركته بتلغرام غير رقم حسابك';
          });
          return;
        case 'expired':
        case 'invalid':
          _timer?.cancel();
          setState(() {
            state = _VerState.timedout;
            _error = 'انتهت مهلة التحقق، حاول مرة ثانية';
          });
          return;
      }
      if (_deadline != null && DateTime.now().isAfter(_deadline!)) {
        _timer?.cancel();
        setState(() {
          state = _VerState.timedout;
          _error = 'انتهت مهلة التحقق، حاول مرة ثانية';
        });
      }
    } catch (_) {
      // انقطاع شبكة مؤقت — يكمل الـ polling مباشرة
    }
  }

  void _retry() => _startSession(); // جلسة جديدة: القديمة تُعلَّق من السيرفر

  Future<void> _installTelegram() => launchUrl(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=org.telegram.messenger'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, // صلب — شاشة قرار حرج، ممنوع الزجاج
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_forward,
                      color: AppColors.primary),
                  tooltip: 'رجوع',
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.line),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.telegram,
                          size: 44, color: AppColors.info),
                    ),
                    const SizedBox(height: 16),
                    Text('تأكيد رقمك عبر تلغرام',
                        style: AppType.h2Style, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'الرقم المراد تأكيده: $_masked',
                      style: AppType.smallStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _body(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (state) {
      case _VerState.starting:
        return Column(children: [
          const LottieBox(
            assetKey: 'main_loader',
            loop: true,
            width: 120,
            height: 120,
            fallback: CircularProgressIndicator(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('جارٍ تجهيز التحقق...', style: AppType.smallStyle),
        ]);
      case _VerState.noTelegram:
        return Column(children: [
          const Icon(Icons.send_to_mobile_rounded,
              size: 72, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(
            'التأكيد يتطلب تطبيق تلغرام',
            style: AppType.h3Style,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ثبّت تلغرام، وسجّل الخروج/الدخول بحسابك، وارجع لتأكيد رقمك — التحقق يمر عبر تلغرام حصراً',
            style: AppType.smallStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SolidBtn(
            label: 'نزّل تلغرام من المتجر 📲',
            color: AppColors.accent,
            onTap: _installTelegram,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _probeTelegram,
            child: Text('راجعتُ التثبيت — حاول مرة أخرى',
                style: AppType.style(13, color: AppColors.primary)),
          ),
        ]);
      case _VerState.waiting:
        return Column(children: [
          const LottieBox(
            assetKey: 'main_loader',
            loop: true,
            width: 120,
            height: 120,
            fallback: CircularProgressIndicator(color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text('بانتظار تأكيدك من تلغرام...',
              style: AppType.smallStyle), // Secondary — انتظار مو خطأ
          const SizedBox(height: 8),
          Text(
            'افتح تلغرام واضغط «مشاركة رقم هاتفي» — لا تغلق التطبيق',
            style: AppType.microStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SolidBtn(
            label: 'فتح تلغرام مرة أخرى 🔗',
            color: AppColors.accent,
            onTap: () {
              _timer?.cancel();
              _deadline = DateTime.now().add(_attemptLimit);
              _timer = Timer.periodic(_pollEvery, (_) => _check());
              _openTelegram();
            },
          ),
        ]);
      case _VerState.success:
        return Column(children: [
          const LottieBox(
            assetKey: 'order_success',
            loop: false,
            width: 160,
            height: 160,
            fallback:
                Icon(Icons.check_circle, size: 96, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
            'تم تأكيد رقمك بنجاح ✓',
            style: AppType.h3Style.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: 8),
          Text(
            '$_masked — متحقق الآن',
            style: AppType.smallStyle,
          ),
        ]);
      case _VerState.timedout:
        return Column(children: [
          const Icon(Icons.timer_off_outlined,
              size: 72, color: AppColors.danger),
          const SizedBox(height: 16),
          Text('انتهت مهلة التحقق، حاول مرة ثانية',
              style: AppType.h3Style, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SolidBtn(
              label: 'حاول مرة ثانية 🔄',
              color: AppColors.accent,
              onTap: _retry),
        ]);
      case _VerState.mismatch:
        return Column(children: [
          const Icon(Icons.phone_forwarded_outlined,
              size: 72, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(_error, style: AppType.h3Style, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SolidBtn(
              label: 'حاول مرة ثانية 🔄',
              color: AppColors.accent,
              onTap: _retry),
        ]);
      case _VerState.error:
        return Column(children: [
          const Icon(Icons.error_outline, size: 72, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(_error, style: AppType.h3Style, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SolidBtn(
            label: 'حاول مرة ثانية 🔄',
            color: AppColors.accent,
            onTap: _retry,
          ),
        ]);
    }
  }
}