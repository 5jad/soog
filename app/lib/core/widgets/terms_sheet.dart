import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

/// شروط الاستخدام — تفتح من شاشة الدخول/التسجيل (تحت زر المتابعة)
/// الزبون يوافق على شروط يقراها فعلاً، مو سطر مجرد.
void showTermsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.78,
      child: const _TermsSheet(),
    ),
  );
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('شروط الاستخدام',
                    style: AppType.style(16,
                        color: AppColors.ink, weight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'إغلاق',
                ),
              ]),
            ),
            const Divider(color: AppColors.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      '1. قبولك للشروط',
                      'بمجرد استخدامك تطبيق زبون (كزبون أو تاجر أو مندوب) فأنت '
                      'توافق على هذي الشروط. إذا ما توافق عليها — لا تستخدم التطبيق.',
                    ),
                    _section(
                      '2. حسابك ورقمك',
                      'رقم هاتفك يُستخدم للدخول والتوثيق وإشعارات الطلبات فقط، '
                      'وما يُشارك مع أي جهة خارجية. أنت مسؤول عن كلمة مرورك '
                      'وعن أي نشاط بإحداثيات حسابك.',
                    ),
                    _section(
                      '3. الطلب والدفع',
                      'الدفع عند الاستلام (كاش). المبلغ يشمل المنتجات + تكلفة '
                      'التوصيل حسب المسافة. تقدر تلغي طلبك مجاناً قبل ما يجُهّز '
                      'من المتجر، وبعدها حسب حالة الطلب.',
                    ),
                    _section(
                      '4. المتاجر',
                      'المتجر مسؤول عن جودة منتجاته ودقة أوصافها وأسعارها. '
                      'زبون يجمع العرض بينك وبين المتجر، وما يضمن المنتج '
                      'بنفسه — التقييمات تساعدك تتخذ قرارك.',
                    ),
                    _section(
                      '5. التوصيل',
                      'المندوب يوصل طلبك للعنوان اللي تحدده ضمن أوقات العمل، '
                      'والتواصل بخصوص التوصيل يتم من خلال بيانات التطبيق.',
                    ),
                    _section(
                      '6. الاستخدام المسؤول',
                      'الكذب أو الاحتيال أو الإلغاءات المتكررة أو إساءة استخدام '
                      'الخدمة (بأي دور) قد تؤدي لإيقاف حسابك بشكل دائم.',
                    ),
                    _section(
                      '7. الخصوصية',
                      'بياناتك أمانة: ما نبيعها وما نشاركها. الصور والتوثيق '
                      '(مثل البطاقة الوطنية) تُستخدم للتحقق من الهوية فقط.',
                    ),
                    _section(
                      '8. تعديل الشروط',
                      'تقدر الشروط تتحدث مع تحديثات التطبيق — وأي تعديل '
                      'يُنشر هنا بنفس الصفحة حتى تبقى على اطلاع.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: AppType.style(13.5,
                  color: AppColors.primary, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body,
              style: AppType.style(12.5,
                  color: AppColors.muted,
                  weight: FontWeight.w500,
                  height: 1.55)),
        ],
      ),
    );
  }
}