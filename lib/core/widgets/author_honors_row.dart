import 'package:flutter/material.dart';

import '../../data/models/user.dart';
import '../theme/app_colors.dart';

/// Compact honor chips for author-of-month / special project.
class AuthorHonorsRow extends StatelessWidget {
  const AuthorHonorsRow({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (user.isAuthorOfMonth) {
      chips.add(const _HonorChip(label: 'Автор месяца', emphasized: true));
    }
    if (user.specialProject) {
      chips.add(const _HonorChip(label: 'Спецпроект'));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 6, children: chips);
  }
}

class _HonorChip extends StatelessWidget {
  const _HonorChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasized ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: emphasized ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
