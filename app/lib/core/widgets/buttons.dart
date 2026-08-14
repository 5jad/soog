import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

/// زر كتفي صلب — ارتفاع 52 + قبعة (Capsule) + CTA البرتقالي للشراء عبر color
/// الرِبل مرئي الآن: Material بلون الزر + InkWell فوقه (سابقاً كان تحت الخلفية المطلية)
class SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;
  final Color? color;

  /// اهتزاز خفيف عند الضغط — للأزرار الحرجة فقط (إتمام/أضف للسلة) حتى لا يخزّز
  final bool haptic;

  /// true: الزر يملأ عرض الوالد كاملاً (افتراضي).
  /// false: زر مضغوط بعرض النص — ضروري داخل Row (وإلا width: double.infinity
  /// داخل صف بلا Expanded يرمي BoxConstraints forces an infinite width
  /// ويسقط الشاشة كلها).
  final bool expanded;
  const SolidBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
    this.color,
    this.haptic = false,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = disabled
        ? const Color(0xFFB9C0CC)
        : (color ?? AppColors.primary);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: disabled ? 0 : 5,
      shadowColor: bg.withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        splashColor: Colors.white.withValues(alpha: 0.28),
        highlightColor: Colors.white.withValues(alpha: 0.14),
        onTap: (loading || disabled)
            ? null
            : () {
                if (haptic) HapticFeedback.lightImpact();
                onTap();
              },
        child: SizedBox(
          height: 52,
          width: expanded ? double.infinity : null,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: AppType.style(
                      15.5,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
class QuickAddButton extends StatelessWidget {
  final Map<String, dynamic> product;
  final void Function(
    BuildContext,
    Map<String, dynamic>, {
    int qty,
    Offset? origin,
  })
  onQuickAdd;
  const QuickAddButton({
    super.key,
    required this.product,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnCtx) => GestureDetector(
        onTap: () {
          final box = btnCtx.findRenderObject() as RenderBox?;
          onQuickAdd(
            context,
            product,
            origin: box != null
                ? box.localToGlobal(Offset.zero) + const Offset(13, 13)
                : null,
          );
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Theme.of(btnCtx).primaryColor,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.add_rounded,
            size: AppIcons.sm,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
