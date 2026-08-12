import 'package:flutter/material.dart';

import '../../data/models/user.dart';
import '../theme/app_colors.dart';

/// Host reputation ladder - own profile (full) or public (compact).
class AuthorPathCard extends StatelessWidget {
  const AuthorPathCard({
    super.key,
    required this.path,
    this.compact = false,
  });

  final AuthorPath path;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      if (path.level <= 0) return const SizedBox.shrink();
      return Text(
        'Путь автора · ${path.title}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
    }

    final next = path.next;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Путь автора',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Уровень ${path.level} · ${path.title}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${path.eventsHosted} соб. · ${path.guestsHosted} гостей · ${path.hostReviewsCount} отзывов',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Text(
              'Дальше: ${next.title}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: next.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              next.hint,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Вы в топе пути автора. Дальше: номинации и спецпроекты от команды.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
