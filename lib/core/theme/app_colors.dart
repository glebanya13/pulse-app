import 'package:flutter/material.dart';

/// Пульс - dark UI with purple only as brand accent (not chrome text).
abstract final class AppColors {
  static const Color primary = Color(0xFF7B35D6);
  static const Color primaryBright = Color(0xFF9B4DEB);
  static const Color primaryLight = Color(0xFFB56BEF);
  static const Color lilac = Color(0xFFC4B5FD);
  static const Color highlight = Color(0xFFF7F7F8);
  static const Color cool = Color(0xFF9A9AA3);
  static const Color primaryDark = Color(0xFF3B176F);

  static const Color black = Color(0xFF0A0A0B);
  /// Light ink on dark surfaces / primary buttons.
  static const Color white = Color(0xFFF7F7F8);

  static const Color textPrimary = Color(0xFFF2F2F3);
  static const Color textSecondary = Color(0xFF9A9AA3);
  static const Color textTertiary = Color(0xFF6E6E76);

  static const Color surface = Color(0xFF141416);
  static const Color surfaceAlt = Color(0xFF1C1C1F);
  static const Color border = Color(0xFF2C2C31);

  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFFF453A);
  static const Color warning = Color(0xFFFF9F0A);

  static const Color ratingGold = Color(0xFFE8C547);

  static const List<Color> statusColors = [success, danger];
}
