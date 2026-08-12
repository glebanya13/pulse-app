import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';

/// The "Бесплатно / Фиксированная / Донат" pill row used on event, dish and
/// request creation screens (informational event price - no in-app checkout).
class PriceTypeSelector extends StatelessWidget {
  const PriceTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PriceType value;
  final ValueChanged<PriceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PriceType.values.map((type) {
        final selected = value == type;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type != PriceType.values.last ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
