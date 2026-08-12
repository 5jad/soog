import 'package:flutter/material.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

/// أزرار الحالة (Chip)
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor(status).withOpacity(0.35)),
      ),
      child: Text(
        '${statusEmoji(status)} ${statusLabel(status)}',
        style: AppType.style(
          11,
          color: statusColor(status),
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}
class ChipG extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final String? icon;
  const ChipG({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppType.style(
                13,
                color: active ? Colors.white : AppColors.ink,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class DotChip extends StatelessWidget {
  final String label;
  final Color color;
  const DotChip({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
class VerifiedTag extends StatelessWidget {
  final bool verified;
  const VerifiedTag({super.key, this.verified = true});
  @override
  Widget build(BuildContext context) {
    if (!verified) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 3),
        const Text(
          'موثق',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}
class StarsTag extends StatelessWidget {
  final double rating;
  const StarsTag({super.key, this.rating = 0});
  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}
