import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../data/models/application.dart';
import '../../data/models/enums.dart';
import '../chat/chats_providers.dart';
import 'events_providers.dart';

/// Host inbox: all pending applications across hosted events.
class IncomingApplicationsScreen extends ConsumerWidget {
  const IncomingApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(hostedPendingApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Входящие заявки')),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState.fromError(
          e,
          onRetry: () => ref.invalidate(hostedPendingApplicationsProvider),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(hostedPendingApplicationsProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Нет новых заявок',
                    subtitle: 'Когда гости подадут заявку на ваши события, они появятся здесь',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(hostedPendingApplicationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: apps.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) => _IncomingTile(application: apps[i]),
            ),
          );
        },
      ),
    );
  }
}

class _IncomingTile extends ConsumerStatefulWidget {
  const _IncomingTile({required this.application});

  final EventApplication application;

  @override
  ConsumerState<_IncomingTile> createState() => _IncomingTileState();
}

class _IncomingTileState extends ConsumerState<_IncomingTile> {
  bool _busy = false;

  Future<void> _respond(ApplicationStatus status) async {
    setState(() => _busy = true);
    try {
      final chatId = await ref
          .read(eventRepositoryProvider)
          .respondToApplication(widget.application.id, status);
      ref.invalidate(hostedPendingApplicationsProvider);
      ref.invalidate(eventApplicationsProvider(widget.application.event.id));
      ref.invalidate(eventByIdProvider(widget.application.event.id));
      ref.invalidate(chatsProvider);
      if (!mounted) return;
      if (status == ApplicationStatus.accepted) {
        final id = chatId ??
            (await ref.read(chatRepositoryProvider).byEventId(widget.application.event.id))
                ?.id;
        if (!mounted) return;
        if (id != null) {
          context.push('/chat/$id');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка принята')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отклонена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось обновить заявку'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.application;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: UserAvatar(url: a.applicant.avatarUrl, size: 48, name: a.applicant.name),
      title: Text(
        formatUserName(a.applicant.name, a.applicant.age),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.applicant.activity.hasNoShowSignal) ...[
            const SizedBox(height: 2),
            Text(
              a.applicant.activity.noShowLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            a.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (a.message != null && a.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              a.message!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(ApplicationStatus.rejected),
                  child: const Text('Отклонить'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _respond(ApplicationStatus.accepted),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Принять'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => context.push('/events/${a.event.id}'),
            child: const Text('К событию'),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
