import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_state.dart';
import '../../data/models/enums.dart';
import '../../data/models/review.dart';
import '../events/events_providers.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({
    super.key,
    required this.eventId,
    required this.targetUserId,
    required this.targetRole,
  });

  final String eventId;
  final String targetUserId;
  final ReviewTargetRole targetRole;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  late final List<ReviewCriterion> _criteria = criteriaFor(widget.targetRole);
  /// backendKey → selected score
  final Map<String, int> _scores = {};
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  int get _filledCount => _scores.length;

  bool get _canSubmit => _filledCount >= 1;

  double? get _overall {
    if (!_canSubmit) return null;
    return computeReviewOverall(Map<String, int>.from(_scores), widget.targetRole);
  }

  String get _overallHint {
    final o = _overall;
    if (o == null) {
      return 'Заполните хотя бы один пункт - остальные желательны';
    }
    if (o >= 100) return 'Вау - лучший опыт в жизни (редкость)';
    if (o >= 95) return 'Почти идеально - редкая оценка';
    if (o >= 85) return 'Очень хорошо';
    if (o >= 70) return 'Хорошо';
    if (o >= 50) return 'Нормально';
    return 'Ниже ожиданий';
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    final isHost = widget.targetRole == ReviewTargetRole.host;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHost ? 'Оцените хозяина' : 'Оцените гостя'),
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(eventByIdProvider(widget.eventId)),
        ),
        data: (event) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              event.title,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                isHost
                    ? 'Рейтинг - портрет опыта хозяина, не только еда. 100 - «лучший опыт в жизни», ставьте редко.'
                    : 'Оцените гостя честно: так строится доверие. 100 - редкость, не привычка.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Заполнено $_filledCount из ${_criteria.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ..._criteria.map((c) {
              final selected = _scores[c.backendKey];
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selected == null ? 'необязательно' : '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: c.levels.map((level) {
                        final isOn = selected == level.score;
                        return ChoiceChip(
                          label: Text(level.label),
                          selected: isOn,
                          onSelected: (_) => setState(() {
                            if (isOn) {
                              _scores.remove(c.backendKey);
                            } else {
                              _scores[c.backendKey] = level.score;
                            }
                          }),
                          selectedColor: AppColors.primary.withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                            fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                            color: isOn ? AppColors.primary : AppColors.textPrimary,
                          ),
                          side: BorderSide(
                            color: isOn ? AppColors.primary : AppColors.border,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Итоговый рейтинг',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  _overall == null ? '-/100' : '${_overall!.round()}/100',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _overallHint,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              isHost
                  ? 'Вкус и гостеприимство весят больше. Итог считается только по заполненным пунктам.'
                  : 'Все пункты для гостя весят одинаково. 100 - редкость.',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Комментарий',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Что запомнилось больше всего?',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_submitting || !_canSubmit)
                  ? null
                  : () => _submit(event.id, event.title),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Отправить отзыв'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String eventId, String eventTitle) async {
    setState(() => _submitting = true);
    try {
      final me = ref.read(currentUserProvider);
      final targetUser =
          await ref.read(userRepositoryProvider).byId(widget.targetUserId);
      final russianScores = <String, int>{
        for (final c in _criteria)
          if (_scores[c.backendKey] != null) c.label: _scores[c.backendKey]!,
      };
      await ref.read(reviewRepositoryProvider).submit(
            Review(
              id: 'rv_${DateTime.now().microsecondsSinceEpoch}',
              eventId: eventId,
              eventTitle: eventTitle,
              reviewer: me,
              target: targetUser,
              targetRole: widget.targetRole,
              scores: russianScores,
              comment: _commentController.text.trim().isEmpty
                  ? null
                  : _commentController.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спасибо за отзыв!')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить отзыв: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
