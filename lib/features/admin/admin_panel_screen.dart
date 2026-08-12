import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/event_list_tile.dart';
import '../../core/widgets/rating_badge.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../../data/models/user.dart';
import '../monetization/monetization_actions.dart';

final _adminStatsProvider = FutureProvider<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).stats();
});

final _adminUsersProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).listUsers();
});

final _adminEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(adminRepositoryProvider).listEvents();
});

final _adminPendingEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(adminRepositoryProvider).listEvents(
        status: EventStatus.pendingReview,
      );
});

final _adminComplaintsProvider = FutureProvider<List<Complaint>>((ref) {
  return ref.watch(adminRepositoryProvider).listComplaints();
});

final _adminLogsProvider = FutureProvider<List<AdminActionLog>>((ref) {
  return ref.watch(adminRepositoryProvider).listLogs();
});

final _adminAuthorMonthProvider = FutureProvider<AuthorOfMonthShowcase>((ref) {
  return ref.watch(adminRepositoryProvider).authorOfMonth();
});

final _adminAuthorPoolProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).authorPool();
});

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(_adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Админ панель')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                UserAvatar(url: me.avatarUrl, size: 52, name: me.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Администратор',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          statsAsync.maybeWhen(
            data: (stats) => GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _StatCard(value: '${stats.users}', label: 'Пользователи'),
                _StatCard(value: '${stats.activeEvents}', label: 'Активные события'),
                _StatCard(value: '${stats.complaintsOpen}', label: 'Открытые жалобы'),
              ],
            ),
            orElse: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTile(
            icon: Icons.fact_check_outlined,
            label: 'На модерации',
            onTap: () => _openModeration(context),
          ),
          _SectionTile(
            icon: Icons.emoji_events_outlined,
            label: 'Авторы',
            onTap: () => _openAuthors(context),
          ),
          _SectionTile(
            icon: Icons.people_outline,
            label: 'Пользователи',
            onTap: () => _openUsers(context, onlyBlocked: false),
          ),
          _SectionTile(
            icon: Icons.event_outlined,
            label: 'События',
            onTap: () => _openEvents(context),
          ),
          _SectionTile(
            icon: Icons.flag_outlined,
            label: 'Жалобы и запросы',
            onTap: () => _openComplaints(context),
          ),
          _SectionTile(
            icon: Icons.block,
            label: 'Заблокированные',
            onTap: () => _openUsers(context, onlyBlocked: true),
          ),
          _SectionTile(
            icon: Icons.description_outlined,
            label: 'Логи',
            onTap: () => _openLogs(context),
          ),
          _SectionTile(
            icon: Icons.bar_chart,
            label: 'Статистика',
            onTap: () => _openStats(context),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Выйти', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
            onTap: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, {required String title, required Widget child}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: child,
      ),
    ));
  }

  void _openAuthors(BuildContext context) {
    _push(context, title: 'Авторы', child: const _AuthorsAdmin());
  }

  void _openUsers(BuildContext context, {required bool onlyBlocked}) {
    _push(context, title: onlyBlocked ? 'Заблокированные' : 'Пользователи', child: _UsersList(onlyBlocked: onlyBlocked));
  }

  void _openEvents(BuildContext context) {
    _push(context, title: 'События', child: const _EventsList());
  }

  void _openModeration(BuildContext context) {
    _push(context, title: 'На модерации', child: const _ModerationQueue());
  }

  void _openComplaints(BuildContext context) {
    _push(context, title: 'Жалобы и запросы', child: const _ComplaintsList());
  }

  void _openLogs(BuildContext context) {
    _push(context, title: 'Логи', child: const _LogsList());
  }

  void _openStats(BuildContext context) {
    _push(context, title: 'Статистика', child: const _StatsList());
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList({required this.onlyBlocked});

  final bool onlyBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminUsersProvider);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminUsersProvider),
      ),
      data: (users) {
        final filtered = onlyBlocked ? users.where((u) => u.isBlocked).toList() : users;
        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: onlyBlocked ? 'Заблокированных нет' : 'Пользователей нет',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (c, i) {
            final user = filtered[i];
            return ListTile(
              leading: UserAvatar(url: user.avatarUrl, size: 40, name: user.name),
              title: Text(user.name),
              subtitle: Text(
                user.hasActiveOrganizerPro && user.organizerProUntil != null
                    ? '${user.role.label} · ${user.city} · Pro до ${formatProUntil(user.organizerProUntil!)}'
                    : '${user.role.label} · ${user.city}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RatingBadge(score: user.rating, compact: true),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(adminRepositoryProvider)
                          .grantOrganizerPro(user.id);
                      ref.invalidate(_adminUsersProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pro выдан: ${user.name}')),
                        );
                      }
                    },
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        color: user.hasActiveOrganizerPro
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(adminRepositoryProvider).setBlocked(user.id, !user.isBlocked);
                      ref.invalidate(_adminUsersProvider);
                      ref.invalidate(_adminStatsProvider);
                    },
                    child: Text(
                      user.isBlocked ? 'Разблок.' : 'Блок.',
                      style: TextStyle(color: user.isBlocked ? AppColors.primary : AppColors.danger),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EventsList extends ConsumerWidget {
  const _EventsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_adminEventsProvider);
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminEventsProvider),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const EmptyState(icon: Icons.event_outlined, title: 'Событий нет');
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
                if (event.status != EventStatus.cancelled) ...[
                  IconButton(
                    icon: Icon(
                      Icons.rocket_launch_outlined,
                      color: event.isActivelyBoosted ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'В топ на 7 дней',
                    onPressed: () async {
                      await ref.read(adminRepositoryProvider).boostEvent(event.id);
                      ref.invalidate(_adminEventsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('В топе: ${event.title}')),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.block, color: AppColors.danger, size: 20),
                    tooltip: 'Отменить событие',
                    onPressed: () async {
                      await ref.read(adminRepositoryProvider).cancelEvent(event.id);
                      ref.invalidate(_adminEventsProvider);
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ModerationQueue extends ConsumerWidget {
  const _ModerationQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_adminPendingEventsProvider);
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminPendingEventsProvider),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'Очередь пуста',
            subtitle: 'Сомнительные публикации появятся здесь',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            final event = events[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.push('/events/${event.id}'),
                    child: Text(
                      event.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.host.name} · ${formatEventDateTime(event.startAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (event.moderationNote != null && event.moderationNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Сработало: ${event.moderationNote}',
                      style: const TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ],
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await ref.read(adminRepositoryProvider).rejectEvent(event.id);
                          ref.invalidate(_adminPendingEventsProvider);
                          ref.invalidate(_adminEventsProvider);
                          ref.invalidate(_adminStatsProvider);
                        },
                        child: const Text('Отклонить', style: TextStyle(color: AppColors.danger)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          await ref.read(adminRepositoryProvider).approveEvent(event.id);
                          ref.invalidate(_adminPendingEventsProvider);
                          ref.invalidate(_adminEventsProvider);
                          ref.invalidate(_adminStatsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Одобрено: ${event.title}')),
                            );
                          }
                        },
                        child: const Text('Одобрить'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintsList extends ConsumerWidget {
  const _ComplaintsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(_adminComplaintsProvider);
    return complaintsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminComplaintsProvider),
      ),
      data: (complaints) {
        if (complaints.isEmpty) {
          return const EmptyState(icon: Icons.flag_outlined, title: 'Жалоб пока нет');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: complaints.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            final complaint = complaints[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${complaint.targetType.label}: ${complaint.reason}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('От: ${complaint.reporter.name} · ${formatEventDateTime(complaint.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(complaint.status.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      if (complaint.status == ComplaintStatus.open)
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _update(ref, complaint.id, ComplaintStatus.dismissed),
                              child: const Text('Отклонить'),
                            ),
                            TextButton(
                              onPressed: () => _update(ref, complaint.id, ComplaintStatus.resolved),
                              child: const Text('Решить'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _update(WidgetRef ref, String id, ComplaintStatus status) async {
    await ref.read(adminRepositoryProvider).updateComplaint(id, status);
    ref.invalidate(_adminComplaintsProvider);
    ref.invalidate(_adminStatsProvider);
  }
}

class _LogsList extends ConsumerWidget {
  const _LogsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_adminLogsProvider);
    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminLogsProvider),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyState(icon: Icons.description_outlined, title: 'Пока пусто');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (c, i) {
            final log = logs[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(log.action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('${log.admin.name} · ${log.targetType} · ${formatEventDateTime(log.createdAt)}'),
            );
          },
        );
      },
    );
  }
}

class _StatsList extends ConsumerWidget {
  const _StatsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(_adminStatsProvider),
      ),
      data: (stats) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Всего пользователей'), trailing: Text('${stats.users}')),
          ListTile(title: const Text('Заблокированных'), trailing: Text('${stats.blockedUsers}')),
          ListTile(title: const Text('Всего событий'), trailing: Text('${stats.events}')),
          ListTile(title: const Text('Активных событий'), trailing: Text('${stats.activeEvents}')),
          ListTile(title: const Text('Заявок на события'), trailing: Text('${stats.applications}')),
          ListTile(title: const Text('Запросов от гостей'), trailing: Text('${stats.requests}')),
          ListTile(title: const Text('Открытых жалоб'), trailing: Text('${stats.complaintsOpen}')),
          ListTile(title: const Text('Отзывов оставлено'), trailing: Text('${stats.reviews}')),
        ],
      ),
    );
  }
}

class _AuthorsAdmin extends ConsumerWidget {
  const _AuthorsAdmin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(_adminAuthorMonthProvider);
    final poolAsync = ref.watch(_adminAuthorPoolProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_adminAuthorMonthProvider);
        ref.invalidate(_adminAuthorPoolProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Автор месяца',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          currentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
            data: (showcase) {
              final author = showcase.author;
              if (author == null) {
                return Text(
                  'Пока не выбран · ${showcase.periodLabel.isEmpty ? showcase.period : showcase.periodLabel}',
                  style: const TextStyle(color: AppColors.textSecondary),
                );
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(url: author.avatarUrl, size: 44, name: author.name),
                title: Text(author.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  showcase.periodLabel.isEmpty ? showcase.period : showcase.periodLabel,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Пул талантов (L5+)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Назначьте автора месяца или отметьте спецпроект',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          poolAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => ErrorState(message: '$e', onRetry: () => ref.invalidate(_adminAuthorPoolProvider)),
            data: (pool) {
              if (pool.isEmpty) {
                return const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'Пока нет талантов L5+',
                  subtitle: 'Можно назначить любого пользователя из списка ниже через поиск в «Пользователи» - или дождаться уровня 5.',
                );
              }
              return Column(
                children: [
                  for (final user in pool)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(url: user.avatarUrl, size: 40, name: user.name),
                      title: Text(user.name),
                      subtitle: Text(
                        'L${user.authorLevel} · ${user.city}'
                        '${user.specialProject ? ' · спецпроект' : ''}'
                        '${user.isAuthorOfMonth ? ' · автор месяца' : ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          final repo = ref.read(adminRepositoryProvider);
                          if (value == 'month') {
                            await repo.setAuthorOfMonth(user.id);
                            ref.invalidate(_adminAuthorMonthProvider);
                            ref.invalidate(_adminAuthorPoolProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${user.name} - автор месяца')),
                              );
                            }
                          } else if (value == 'special') {
                            await repo.setSpecialProject(user.id, !user.specialProject);
                            ref.invalidate(_adminAuthorPoolProvider);
                            ref.invalidate(_adminUsersProvider);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'month', child: Text('Сделать автором месяца')),
                          PopupMenuItem(
                            value: 'special',
                            child: Text(user.specialProject ? 'Снять спецпроект' : 'Спецпроект'),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Все пользователи',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _AuthorsFromAllUsers(),
        ],
      ),
    );
  }
}

class _AuthorsFromAllUsers extends ConsumerWidget {
  const _AuthorsFromAllUsers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminUsersProvider);
    return usersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (users) {
        final hosts = users.where((u) => u.authorLevel > 0 || u.eventsCount > 0).take(30).toList();
        if (hosts.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final user in hosts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(url: user.avatarUrl, size: 36, name: user.name),
                title: Text(user.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text('L${user.authorLevel}'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(adminRepositoryProvider).setAuthorOfMonth(user.id);
                    ref.invalidate(_adminAuthorMonthProvider);
                    ref.invalidate(_adminAuthorPoolProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${user.name} - автор месяца')),
                      );
                    }
                  },
                  child: const Text('Месяц'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}
