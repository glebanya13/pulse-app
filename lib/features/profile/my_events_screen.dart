import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/event_list_tile.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../events/events_providers.dart';
import '../monetization/monetization_actions.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(myHostedEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои события'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Будущие'), Tab(text: 'Прошедшие')],
        ),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(myHostedEventsProvider),
        ),
        data: (events) {
          final upcoming = events.where((e) => e.status != EventStatus.completed).toList();
          final past = events.where((e) => e.status == EventStatus.completed).toList();
          return TabBarView(
            controller: _tabController,
            children: [_buildList(upcoming, past: false), _buildList(past, past: true)],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Event> events, {required bool past}) {
    if (events.isEmpty) {
      return const EmptyState(icon: Icons.event_note_outlined, title: 'Пока пусто');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemBuilder: (c, i) {
        final event = events[i];
        return Row(
          children: [
            Expanded(
              child: EventListTile(event: event, onTap: () => context.push('/events/${event.id}')),
            ),
            if (past && event.status == EventStatus.completed)
              TextButton(
                onPressed: () => _pickGuestToRate(context, event),
                child: const Text('Оценить'),
              )
            else if (event.status == EventStatus.cancelled)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'Отменено',
                  style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              )
            else ...[
              if (event.status == EventStatus.active)
                TextButton(
                  onPressed: () => showPromoteEventSheet(
                    context: context,
                    ref: ref,
                    event: event,
                  ),
                  child: Text(
                    event.isActivelyBoosted ? 'В топе' : 'Продвинуть',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: event.isActivelyBoosted
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Изменить',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/events/${event.id}/edit'),
              ),
              IconButton(
                tooltip: 'Отменить',
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                onPressed: () => _confirmCancel(event),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmCancel(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить событие?'),
        content: Text(
          '«${event.title}» будет отменено. Принятые гости получат уведомление.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Назад')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Отменить событие'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(eventRepositoryProvider).cancel(event.id, host: event.host);
      ref.invalidate(myHostedEventsProvider);
      ref.invalidate(eventsProvider);
      ref.invalidate(eventByIdProvider(event.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Событие отменено, гости уведомлены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  void _pickGuestToRate(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final applicationsAsync = ref.watch(eventApplicationsProvider(event.id));
            return applicationsAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => SizedBox(
                height: 120,
                child: Center(child: Text('Ошибка: $e')),
              ),
              data: (applications) {
                final guests =
                    applications.where((a) => a.status == ApplicationStatus.accepted).toList();
                if (guests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('На это событие нет принятых гостей'),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Подтвердите гостей и оцените',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...guests.map((a) {
                      final confirmedByHost = a.hostConfirmedAt != null;
                      final mutual = a.mutualAttendanceConfirmed;
                      final noShow = a.isNoShow;
                      return ListTile(
                        leading: UserAvatar(
                          url: a.applicant.avatarUrl,
                          size: 40,
                          name: a.applicant.name,
                        ),
                        title: Text(a.applicant.name),
                        subtitle: Text(
                          noShow
                              ? 'Неявка'
                              : mutual
                                  ? 'Можно оценить'
                                  : confirmedByHost
                                      ? 'Ждём подтверждения гостя'
                                      : 'Подтвердите, что гость был',
                          style: TextStyle(
                            fontSize: 12,
                            color: noShow ? AppColors.danger : null,
                          ),
                        ),
                        trailing: noShow
                            ? TextButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(eventRepositoryProvider)
                                        .clearNoShow(a.id);
                                    ref.invalidate(eventApplicationsProvider(event.id));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Неявка снята')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(apiErrorMessage(e))),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Снять'),
                              )
                            : mutual
                                ? TextButton(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      context.push(
                                        '/rate/${event.id}?targetId=${a.applicant.id}&role=guest',
                                      );
                                    },
                                    child: const Text('Оценить'),
                                  )
                                : confirmedByHost
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              try {
                                                await ref
                                                    .read(eventRepositoryProvider)
                                                    .confirmAttendance(a.id);
                                                ref.invalidate(eventApplicationsProvider(event.id));
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Гость подтверждён'),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(apiErrorMessage(e))),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('Был'),
                                          ),
                                          if (!event.isTakeaway)
                                            TextButton(
                                              onPressed: () async {
                                                try {
                                                  await ref
                                                      .read(eventRepositoryProvider)
                                                      .markNoShow(a.id);
                                                  ref.invalidate(eventApplicationsProvider(event.id));
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Отмечена неявка'),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(apiErrorMessage(e))),
                                                    );
                                                  }
                                                }
                                              },
                                              child: const Text(
                                                'Не пришёл',
                                                style: TextStyle(color: AppColors.danger),
                                              ),
                                            ),
                                        ],
                                      ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
