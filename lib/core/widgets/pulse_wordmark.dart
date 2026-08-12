import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Brand wordmark «ПУЛЬС» — Russo One display caps.
class PulseWordmark extends StatelessWidget {
  const PulseWordmark({
    super.key,
    this.fontSize = 34,
    this.color = AppColors.highlight,
    this.textAlign = TextAlign.center,
  });

  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      'ПУЛЬС',
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: AppTheme.brandFontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.0,
        letterSpacing: fontSize * 0.04,
      ),
    );
  }
}
