import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/application.dart';
import '../../data/models/enums.dart';
import '../events/events_providers.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Я иду')),
      body: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myApplicationsProvider),
        ),
        data: (applications) {
          if (applications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(myApplicationsProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: PhosphorIconsRegular.ticket,
                    title: 'Пока пусто',
                    subtitle: 'Запишитесь на событие в афише - оно появится здесь',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myApplicationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: applications.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (c, i) => _ApplicationCard(application: applications[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.application});

  final EventApplication application;

  Color get _statusColor => switch (application.status) {
        ApplicationStatus.pending => AppColors.textSecondary,
        ApplicationStatus.accepted => AppColors.success,
        ApplicationStatus.rejected => AppColors.danger,
      };

  IconData get _statusIcon => switch (application.status) {
        ApplicationStatus.pending => PhosphorIconsRegular.hourglass,
        ApplicationStatus.accepted => PhosphorIconsRegular.checkCircle,
        ApplicationStatus.rejected => PhosphorIconsRegular.xCircle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = application.event;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.calendarBlank,
                      size: 20,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatEventWindow(event.startAt, event.endAt),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        if (event.address.isNotEmpty)
                          Text(
                            event.address,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_statusIcon, size: 16, color: _statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      application.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  if (application.status == ApplicationStatus.accepted) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppColors.primaryLight,
                      ),
                      onPressed: () => _openChat(context, ref),
                      icon: const Icon(PhosphorIconsRegular.chatCircle, size: 16),
                      label: const Text('Чат', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppColors.primaryLight,
                      ),
                      onPressed: () => _share(context),
                      icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 16),
                      label: const Text('Шер', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppColors.primaryLight,
                      ),
                      onPressed: () {
                        final event = application.event;
                        final cover = event.coverPhoto ??
                            (event.photos.isNotEmpty ? event.photos.first : null);
                        context.push(
                          Uri(
                            path: '/create',
                            queryParameters: {
                              'mode': 'story',
                              if (event.place != null) 'placeId': event.place!.id,
                              if (event.place != null)
                                'placeName': event.place!.name,
                              if (event.place?.address != null &&
                                  event.place!.address!.isNotEmpty)
                                'placeAddress': event.place!.address!,
                              if (event.title.trim().isNotEmpty)
                                'text': event.title.trim(),
                              if (cover != null && cover.isNotEmpty)
                                'imageUrl': cover,
                            },
                          ).toString(),
                        );
                      },
                      icon: const Icon(PhosphorIconsRegular.sparkle, size: 16),
                      label: const Text('История', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final event = application.event;
    final link = 'https://pulse.by/events/${event.id}';
    await SharePlus.instance.share(
      ShareParams(text: '${event.title}\n$link'),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final event = application.event;
      if (event.chatId != null && event.chatId!.isNotEmpty) {
        if (!context.mounted) return;
        context.push('/chat/${event.chatId}');
        return;
      }
      final chat = await ref.read(chatRepositoryProvider).byEventId(event.id);
      if (!context.mounted) return;
      if (chat != null) {
        context.push('/chat/${chat.id}');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чат откроется, когда хозяин примет вашу заявку'),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }
}
