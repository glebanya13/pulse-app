import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "★ 98/100" pill. When [reviewsCount] is 0, shows that there are no ratings yet
/// so newcomers don't look like a perfect 100/100.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.score,
    this.reviewsCount,
    this.compact = false,
  });

  final num score;
  final int? reviewsCount;
  final bool compact;

  bool get _empty => reviewsCount != null && reviewsCount! <= 0;

  @override
  Widget build(BuildContext context) {
    if (_empty) {
      if (compact) {
        return const Text(
          'Нет оценок',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Пока нет оценок',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      );
    }

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            '${score.toStringAsFixed(0)}/100',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(0)}/100',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
