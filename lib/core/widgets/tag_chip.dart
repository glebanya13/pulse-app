import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.primary
        : (outlined ? AppColors.white : AppColors.surface);
    final fg = selected ? AppColors.white : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: outlined && !selected
              ? Border.all(color: AppColors.border)
              : (selected ? Border.all(color: AppColors.primary) : null),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
