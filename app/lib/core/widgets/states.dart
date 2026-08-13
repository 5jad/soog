import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/buttons.dart';
import 'package:zaboon/core/widgets/lottie_box.dart';

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;

  /// مفتاح في LottieAssets — إن سُجّل يلعب بدل الإيموجي.
  /// القيمة الافتراضية 'empty_state' — استخدم null لتعطيل Lottie وإظهار الإيموجي.
  final String? lottie;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    this.action,
    this.onAction,
    this.lottie = 'empty_state', // افتراضي: حالة فارغة موحدة (once)
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lottie != null)
              LottieBox(
                assetKey: lottie!,
                width: 120,
                height: 120,
                loop: false, // دائماً once للحالات الفارغة
                fallback: Text(icon, style: AppType.style(52)),
              )
            else
              Text(icon, style: AppType.style(52)),
            const SizedBox(height: 12),
            Text(title, style: AppType.style(17)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(
                sub!,
                style: AppType.style(12.5, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 22),
              SolidBtn(label: action!, onTap: onAction!, haptic: true),
            ],
          ],
        ),
      ),
    );
  }
}
class Loader extends StatelessWidget {
  const Loader({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        // طبقة زجاج خفيفة (blurLayer1) خلف الـ loader — يظهر فوق محتوى
        // (ليس على خلفية Splash الصلبة) — بلا أي حركة لمعان
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: AppGlass.blurLight,
              sigmaY: AppGlass.blurLight,
            ),
            child: Container(
              width: 120,
              height: 120,
              color: AppGlass.fillLight,
              alignment: Alignment.center,
              child: LottieBox(
                assetKey: 'main_loader', // delivery scooter — loop
                loop: true,
                width: 96,
                height: 96,
                fallback: const CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/* ═══════════ نظام تحديث النسخ — الشريط يفتح تحميل النسخة الأحدث من الموقع ═══════════ */
/// نسخة التطبيق الحالية (مطابقة app-version.json على السيرفر)
const String kAppVersion = '1.1.5';
const int kAppBuild = 36;

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? latest;
  String? url;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final d = await Api.get('/api/app/version');
      final v = (d['version'] ?? '').toString();
      final b = (d['build'] as num?)?.toInt() ?? 0;
      if ((v.isNotEmpty && v != kAppVersion) || b > kAppBuild) {
        setState(() {
          latest = v;
          url = Api.base + (d['download_url'] ?? '/download');
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final v = latest;
    if (v == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.gradNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('📦', style: AppType.style(24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نسخة جديدة متوفرة ($v)',
                  style: AppType.style(
                    13,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
                Text(
                  'حمّلها من موقعنا — أحدث إصدار دائماً',
                  style: AppType.style(
                    10.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final u = url;
              if (u != null)
                await launchUrl(
                  Uri.parse(u),
                  mode: LaunchMode.externalApplication,
                );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'حمّل',
                style: AppType.style(
                  12.5,
                  color: AppColors.accentDeep,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
