import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/main_shell.dart';
import '../../core/widgets/report_dialog.dart';
import '../../data/models/enums.dart';
import '../../data/models/notification.dart';
import '../chat/chats_providers.dart';
import '../events/events_providers.dart';
import 'notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    await ref.read(notificationRepositoryProvider).markRead(n.id);
    ref.invalidate(notificationsProvider);
    if (!context.mounted) return;

    final eventId = n.payload['eventId'] as String?;
    final chatId = n.payload['chatId'] as String?;
    final targetId = n.payload['targetId'] as String?;
    final role = n.payload['role'] as String?;
    final hostId = n.payload['hostId'] as String?;

    if (n.type == NotificationType.attendanceNoShow) {
      final reportHost = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Неявка',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  n.body,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (hostId != null)
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Пожаловаться на ошибку'),
                  ),
                if (eventId != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('К событию'),
                  ),
              ],
            ),
          ),
        ),
      );
      if (!context.mounted) return;
      if (reportHost == true && hostId != null) {
        await showReportDialog(
          context,
          ref,
          targetType: ComplaintTargetType.user,
          targetId: hostId,
        );
      } else if (reportHost == false && eventId != null) {
        context.push('/events/$eventId');
      }
      return;
    }

    if (n.type == NotificationType.authorLevelUp ||
        n.type == NotificationType.authorOfMonth ||
        n.type == NotificationType.specialProject) {
      context.go('/home/profile');
    } else if (chatId != null) {
      context.push('/chat/$chatId');
    } else if (n.type == NotificationType.applicationReceived && eventId != null) {
      context.push('/incoming-applications');
    } else if (n.type == NotificationType.rateReminder &&
        eventId != null &&
        targetId != null &&
        role != null) {
      context.push('/rate/$eventId?targetId=$targetId&role=$role');
    } else if (eventId != null) {
      context.push('/events/$eventId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadChats = ref.watch(unreadChatsCountProvider);
    final pendingHost = ref.watch(hostedPendingApplicationsProvider).maybeWhen(
          data: (apps) => apps.length,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text(
              'Прочитать все',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState.fromError(
          e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          final unreadCount = notifications.where((n) => !n.isRead).length;
          final groups = <String, List<AppNotification>>{};
          for (final n in notifications) {
            groups.putIfAbsent(formatDayLabel(n.createdAt), () => []).add(n);
          }

          return RefreshIndicator(
            color: AppColors.primaryLight,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              unreadCount == 1
                                  ? '1 новое'
                                  : '$unreadCount новых',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: _ShortcutChip(
                                icon: PhosphorIconsRegular.chatCircle,
                                label: 'Чаты',
                                badge: unreadChats,
                                onTap: () => context.go('/home/chats'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ShortcutChip(
                                icon: PhosphorIconsRegular.tray,
                                label: 'Заявки',
                                badge: pendingHost,
                                onTap: () => context.push('/incoming-applications'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.notifications_none,
                      title: 'Пока тихо',
                      subtitle: 'Здесь появятся заявки, сообщения и напоминания о событиях',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28 + kFloatingNavClearance),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entries = groups.entries.toList();
                          var i = 0;
                          for (final entry in entries) {
                            if (index == i) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 4 : 18,
                                  bottom: 10,
                                  left: 4,
                                ),
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              );
                            }
                            i++;
                            for (var n = 0; n < entry.value.length; n++) {
                              if (index == i) {
                                final notification = entry.value[n];
                                final isLast = n == entry.value.length - 1;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                                  child: _NotificationCard(
                                    notification: notification,
                                    onTap: () => _openNotification(context, ref, notification),
                                  ),
                                );
                              }
                              i++;
                            }
                          }
                          return const SizedBox.shrink();
                        },
                        childCount: groups.entries.fold<int>(
                          0,
                          (sum, e) => sum + 1 + e.value.length,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Badge(
                isLabelVisible: badge > 0,
                backgroundColor: AppColors.primary,
                label: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                child: Icon(icon, color: AppColors.highlight, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const Icon(
                PhosphorIconsRegular.caretRight,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  (IconData, Color) get _style => switch (notification.type) {
        NotificationType.applicationReceived => (PhosphorIconsRegular.tray, AppColors.primaryLight),
        NotificationType.applicationAccepted => (PhosphorIconsRegular.checkCircle, AppColors.success),
        NotificationType.applicationRejected => (PhosphorIconsRegular.xCircle, AppColors.danger),
        NotificationType.newMessage => (PhosphorIconsRegular.chatCircle, AppColors.primaryLight),
        NotificationType.orderOffered => (PhosphorIconsRegular.ticket, AppColors.primaryLight),
        NotificationType.offerAccepted => (PhosphorIconsRegular.checkCircle, AppColors.success),
        NotificationType.offerDeclined => (PhosphorIconsRegular.xCircle, AppColors.danger),
        NotificationType.rateReminder => (PhosphorIconsRegular.star, AppColors.warning),
        NotificationType.requestMatch => (PhosphorIconsRegular.chatsCircle, AppColors.primaryLight),
        NotificationType.newReview => (PhosphorIconsRegular.star, AppColors.ratingGold),
        NotificationType.complaintResolved => (PhosphorIconsRegular.flag, AppColors.textSecondary),
        NotificationType.eventThresholdReached => (PhosphorIconsRegular.usersThree, AppColors.success),
        NotificationType.eventCancelled => (PhosphorIconsRegular.calendarX, AppColors.danger),
        NotificationType.hostNewEvent => (PhosphorIconsRegular.calendarPlus, AppColors.primaryLight),
        NotificationType.attendanceNoShow => (PhosphorIconsRegular.userMinus, AppColors.danger),
        NotificationType.authorLevelUp => (PhosphorIconsRegular.trophy, AppColors.success),
        NotificationType.authorOfMonth => (PhosphorIconsRegular.crown, AppColors.ratingGold),
        NotificationType.specialProject => (PhosphorIconsRegular.sparkle, AppColors.primaryLight),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    final unread = !notification.isRead;

    return Material(
      color: unread ? AppColors.surfaceAlt : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.highlight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTime(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
