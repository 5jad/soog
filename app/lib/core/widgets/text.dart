import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionTitle(this.title, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(title, style: AppType.style(16, weight: FontWeight.w900)),
          const Spacer(),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Text(
                'عرض الكل ←',
                style: AppType.style(11.5, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
class SheetTitle extends StatelessWidget {
  final String title;
  const SheetTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Text(title, style: AppType.style(17, weight: FontWeight.w900)),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
/// الشعار الموحد: مربع كحلي بأيقونة سلة + نقطة برتقالية (نقطة «الزاي» — توقيع الهوية) + «زبون»
class TopBarPill extends StatelessWidget {
  const TopBarPill({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.gradNavy,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              // نقطة «الزاي» البرتقالية — توقيع الهوية (نقطة واحدة فوق حرف ز)
              Positioned(
                left: 5,
                top: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'زبون',
          style: AppType.style(
            20,
            color: AppColors.ink,
            weight: FontWeight.w700,
          ).copyWith(fontFamily: 'ElMessiri'),
        ),
      ],
    );
  }
}
class SearchGlass extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;
  const SearchGlass({super.key, required this.onTap, required this.hint});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: AppDecor.card(radius: AppRadius.lg),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: AppType.style(
                  14,
                  color: AppColors.muted,
                  weight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
